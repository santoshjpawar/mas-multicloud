#!/bin/bash
set -e

# This script will initiate the provisioning process of MAS. It will perform following steps,

## Variables
OCP_TERRAFORM_CONFIG_UPLOAD_S3_PATH="s3://masocp-bucket-${DEPLOY_REGION}-${RANDOM_STR}/ocp-cluster-provisioning-terraform-state/"
export AWS_DEFAULT_REGION=$DEPLOY_REGION
MASTER_INSTANCE_TYPE="m5.2xlarge"
WORKER_INSTANCE_TYPE="m5.4xlarge"
# Mongo variables
export MONGODB_STORAGE_CLASS=gp2
# Amqstreams variables
export KAFKA_STORAGE_CLASS=gp2
# IAM variables
IAM_POLICY_NAME="masocp-policy-${RANDOM_STR}"
IAM_USER_NAME="masocp-user-${RANDOM_STR}"
# SLS variables 
export SLS_STORAGE_CLASS=gp2
# BAS variables 
export BAS_META_STORAGE=gp2

# Retrieve SSH public key
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
SSH_PUB_KEY=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" –v http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key)

log "Below are Cloud specific deployment parameters,"
echo " OCP_TERRAFORM_CONFIG_UPLOAD_S3_PATH: $OCP_TERRAFORM_CONFIG_UPLOAD_S3_PATH"
echo " AWS_DEFAULT_REGION: $AWS_DEFAULT_REGION"
echo " MASTER_INSTANCE_TYPE: $MASTER_INSTANCE_TYPE"
echo " WORKER_INSTANCE_TYPE: $WORKER_INSTANCE_TYPE"
echo " MONGODB_STORAGE_CLASS: $MONGODB_STORAGE_CLASS"
echo " KAFKA_STORAGE_CLASS: $KAFKA_STORAGE_CLASS"
echo " IAM_POLICY_NAME: $IAM_POLICY_NAME"
echo " IAM_USER_NAME: $IAM_USER_NAME"
echo " SLS_STORAGE_CLASS: $SLS_STORAGE_CLASS"
echo " BAS_META_STORAGE: $BAS_META_STORAGE"
echo " SSH_PUB_KEY: $SSH_PUB_KEY"

## Download files from S3 bucket
# Download MAS license
log "==== Downloading MAS license ===="
cd $GIT_REPO_HOME
if [[ ${MAS_LICENSE_URL,,} =~ ^https? ]]; then
  wget "$MAS_LICENSE_URL" -O entitlement.lic
elif [[ ${MAS_LICENSE_URL,,} =~ ^s3 ]]; then
  aws s3 cp "$MAS_LICENSE_URL" entitlement.lic
fi
# Download SLS certificate
log "==== Downloading SLS certificate ===="
cd $GIT_REPO_HOME
if [[ ${SLS_PUB_CERT_URL,,} =~ ^https? ]]; then
  wget "$SLS_PUB_CERT_URL" -O sls.crt
elif [[ ${SLS_PUB_CERT_URL,,} =~ ^s3 ]]; then
  aws s3 cp "$SLS_PUB_CERT_URL" sls.crt
fi
# Download BAS certificate
log "==== Downloading BAS certificate ===="
cd $GIT_REPO_HOME
if [[ ${BAS_PUB_CERT_URL,,} =~ ^https? ]]; then
  wget "$BAS_PUB_CERT_URL" -O bas.crt
elif [[ ${BAS_PUB_CERT_URL,,} =~ ^s3 ]]; then
  aws s3 cp "$BAS_PUB_CERT_URL" bas.crt
fi
# Download DB certificate
log "==== Downloading DB certificate ===="
cd $GIT_REPO_HOME
if [[ ${MAS_JDBC_CERT_URL,,} =~ ^https? ]]; then
  wget "$MAS_JDBC_CERT_URL" -O db.crt
  export MAS_JDBC_CERT_LOCAL_FILE=$GIT_REPO_HOME/db.crt
  log " MAS_JDBC_CERT_LOCAL_FILE=$MAS_JDBC_CERT_LOCAL_FILE"
elif [[ ${MAS_JDBC_CERT_URL,,} =~ ^s3 ]]; then
  aws s3 cp "$MAS_JDBC_CERT_URL" db.crt
  export MAS_JDBC_CERT_LOCAL_FILE=$GIT_REPO_HOME/db.crt
  log " MAS_JDBC_CERT_LOCAL_FILE=$MAS_JDBC_CERT_LOCAL_FILE"
fi

## IAM
# Create IAM policy
cd $GIT_REPO_HOME/aws
policyarn=$(aws iam create-policy --policy-name ${IAM_POLICY_NAME} --policy-document file://${GIT_REPO_HOME}/aws/iam/policy.json | jq '.Policy.Arn' | tr -d "\"")
# Create IAM user
aws iam create-user --user-name ${IAM_USER_NAME}
aws iam attach-user-policy --user-name ${IAM_USER_NAME} --policy-arn $policyarn
accessdetails=$(aws iam create-access-key --user-name ${IAM_USER_NAME})
export AWS_ACCESS_KEY_ID=$(echo $accessdetails | jq '.AccessKey.AccessKeyId' | tr -d "\"")
export AWS_SECRET_ACCESS_KEY=$(echo $accessdetails | jq '.AccessKey.SecretAccessKey' | tr -d "\"")
echo " AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID"

## Provisiong OCP cluster
# Create tfvars file
cd $GIT_REPO_HOME/aws/ocp-terraform
rm -rf terraform.tfvars
cat <<EOT >> terraform.tfvars
cluster_name                    = "$CLUSTER_NAME"
region                          = "$DEPLOY_REGION"
az                              = "$AZ_MODE"
availability_zone1              = "${DEPLOY_REGION}a"
availability_zone2              = "${DEPLOY_REGION}b"
availability_zone3              = "${DEPLOY_REGION}c"
vpc_cidr                        = "$VPC_CIDR"
master_subnet_cidr1             = "$MASTER_SUBNET_CIDR_1"
master_subnet_cidr2             = "$MASTER_SUBNET_CIDR_2"
master_subnet_cidr3             = "$MASTER_SUBNET_CIDR_3"
worker_subnet_cidr1             = "$WORKER_SUBNET_CIDR_1"
worker_subnet_cidr2             = "$WORKER_SUBNET_CIDR_2"
worker_subnet_cidr3             = "$WORKER_SUBNET_CIDR_3"
access_key_id                   = "$AWS_ACCESS_KEY_ID"
secret_access_key               = "$AWS_SECRET_ACCESS_KEY"
base_domain                     = "$BASE_DOMAIN"
openshift_pull_secret_file_path = "$OPENSHIFT_PULL_SECRET_FILE_PATH"
public_ssh_key                  = "$SSH_PUB_KEY"
openshift_username              = "$OPENSHIFT_USER"
openshift_password              = "$OPENSHIFT_PASSWORD"
cpd_api_key                     = "$CPD_API_KEY"
master_instance_type            = "$MASTER_INSTANCE_TYPE"
worker_instance_type            = "$WORKER_INSTANCE_TYPE"
master_replica_count            = "$MASTER_NODE_COUNT"
worker_replica_count            = "$WORKER_NODE_COUNT"
accept_cpd_license              = "accept"
EOT
log "==== OCP cluster creation started ===="
# Deploy OCP cluster
sed -i "s/<REGION>/$DEPLOY_REGION/g" variables.tf
sed -i "s/<ASSUME-ROLE-NAME>/arn:aws:iam:::role\/$IAM_ROLE_NAME/g" main.tf
terraform init -input=false
terraform plan -input=false -out=tfplan
terraform apply -input=false -auto-approve
log "==== OCP cluster creation completed ===="
# Backup Terraform configuration
BACKUP_FILE_NAME=terraform-backup-${CLUSTER_NAME}.zip
cd $GIT_REPO_HOME
rm -rf /tmp/mas-multicloud
mkdir /tmp/mas-multicloud
cp -r * /tmp/mas-multicloud
cd /tmp
zip -r $BACKUP_FILE_NAME mas-multicloud/*
aws s3 cp $BACKUP_FILE_NAME $OCP_TERRAFORM_CONFIG_UPLOAD_S3_PATH
log "OCP cluster Terraform configuration backed up at $OCP_TERRAFORM_CONFIG_UPLOAD_S3_PATH in file $CLUSTER_NAME.zip"

## Create bastion host
# Use appropriate AMI based on region
case $DEPLOY_REGION in
    us-east-1)
      AMI_ID="ami-0ec6ccbb788208f23"
      ;;
    us-east-2)
      AMI_ID="ami-0528d2a7a3b7da1ec"
      ;;
    us-west-2)
      AMI_ID="ami-024613903fce03596"
      ;;
    ap-south-1)
      AMI_ID="ami-0cebcaf11fd74077e"
      ;;
esac
log " AMI_ID=$AMI_ID"
# Get the first public subnet in the VPC created for OCP cluster
NEW_VPC_ID=$(cat $GIT_REPO_HOME/aws/ocp-terraform/terraform.tfstate | jq '.resources[] | select((.type | contains("aws_subnet")) and (.name | contains("master1")))' | jq '.instances[0].attributes.vpc_id' | tr -d '"')
NEW_VPC_PUBLIC_SUBNET_ID=$(cat $GIT_REPO_HOME/aws/ocp-terraform/terraform.tfstate | jq '.resources[] | select((.type | contains("aws_subnet")) and (.name | contains("master1")))' | jq '.instances[0].attributes.id' | tr -d '"')
log " NEW_VPC_PUBLIC_SUBNET_ID=$NEW_VPC_PUBLIC_SUBNET_ID"
cd $GIT_REPO_HOME/aws/ocp-bastion-host
rm -rf terraform.tfvars
# Create tfvars file
cat <<EOT >> terraform.tfvars
region                          = "$DEPLOY_REGION"
ami                             = "$AMI_ID"
access_key_id                   = "$AWS_ACCESS_KEY_ID"
secret_access_key               = "$AWS_SECRET_ACCESS_KEY"
key_name                        = "$SSH_KEY_NAME"
vpc_id                          = "$NEW_VPC_ID"
subnet_id                       = "$NEW_VPC_PUBLIC_SUBNET_ID"
unique_str                      = "$RANDOM_STR"
user_data = <<EOF
#! /bin/bash
touch /tmp/file0
cd /root
rm -rf *
aws s3 cp $OCP_TERRAFORM_CONFIG_UPLOAD_S3_PATH/$BACKUP_FILE_NAME . 2>&1 | tee /tmp/s3download.log
touch /tmp/file1
EOF
EOT
sed -i "s/<REGION>/$DEPLOY_REGION/g" variables.tf
#log "==== Bastion host creation started ===="
#terraform init -input=false
#terraform plan -input=false -out=tfplan
#terraform apply -input=false -auto-approve
#log "==== Bastion host creation completed ===="

## Validate OCP cluster login using console and cli

## Configure OCP cluster
log "==== OCP cluster configuration started ===="
cd $GIT_REPO_HOME
cd ansible/playbooks
ansible-playbook configure-ocp.yml 
if [[ $? -ne 0 ]]; then
  # One reason for this failure is catalog sources not having required state information, so recreate the catalog-operator pod
  # https://bugzilla.redhat.com/show_bug.cgi?id=1807128
  echo "Deleting catalog-operator pod"
  podname=$(oc get pods -n openshift-operator-lifecycle-manager | grep catalog-operator | awk {'print $1'})
  oc logs $podname -n openshift-operator-lifecycle-manager
  oc delete pod $podname -n openshift-operator-lifecycle-manager
  sleep 10
  # Retry the step
  ansible-playbook configure-ocp.yml
fi
log "==== OCP cluster configuration completed ===="

## Deploy MongoDB
log "==== MongoDB deployment started ===="
ansible-playbook install-mongodb.yml 
log "==== MongoDB deployment completed ===="

## Copying the entitlement.lic to MAS_CONFIG_DIR
cp $GIT_REPO_HOME/entitlement.lic $MAS_CONFIG_DIR
export SLS_LICENSE_ID=10005a7cc274

## Deploy Amqstreams
# log "==== Amq streams deployment started ===="
# ansible-playbook install-amqstream.yml  
# log "==== Amq streams deployment completed ===="

## Deploy SLS
log "==== SLS deployment started ===="
ansible-playbook install-sls.yml 
log "==== SLS deployment completed ===="

## Deploy BAS
log "==== BAS deployment started ===="
ansible-playbook install-bas.yml
log "==== BAS deployment completed ===="

# Deploy CP4D
log "==== CP4D deployment started ===="
if [[ $DEPLOY_CP4D == "true" ]]; then
  ansible-playbook install-cp4d.yml
fi
log "==== CP4D deployment completed ===="

## Deploy MAS
log "==== MAS deployment started ===="
ansible-playbook install-suite.yml
log "==== MAS deployment completed ===="

## Deploy Manage
if [[ $DEPLOY_MANAGE == "true" ]]; then
  # Deploy Manage
  log "==== MAS Manage deployment started ===="
  ansible-playbook install-app.yml
  log "==== MAS Manage deployment completed ===="
  # Configure suite DB
  log "==== MAS Manage configure suite DB started ===="
  ansible-playbook configure-suite-db.yml -vv
  log "==== MAS Manage configure suite DB completed ===="
  # Configure appp to use the DB
  log "==== MAS Manage configure app started ===="
  ansible-playbook configure-app.yml -vv
  log "==== MAS Manage configure app completed ===="
fi
