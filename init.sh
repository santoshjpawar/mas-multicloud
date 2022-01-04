#!/bin/bash
#
# This is the init script that will call the individual Cloud specific script
#

mark_provisioning_failed() {
    log "Deployment failed"
    log "===== PROVISIONING FAILED ====="
    RESP_CODE=1
    export status=FAILED
    export CLUSTER_NAME=NA
    export BASE_DOMAIN=NA
    export OPENSHIFT_USER=NA
    export OPENSHIFT_PASSWORD=NA
    export MAS_USER=NA
    export MAS_PASSWORD=NA
}

## Inputs
export CLOUD_TYPE=$1
export DEPLOY_REGION=$2
export ACCOUNT_ID=$3
export CLUSTER_SIZE=$4
export RANDOM_STR=$5
export BASE_DOMAIN=$6
export VPC_CIDR=$7
export MASTER_SUBNET_CIDR_1=$8
export MASTER_SUBNET_CIDR_2=$9
export MASTER_SUBNET_CIDR_3=${10}
export WORKER_SUBNET_CIDR_1=${11}
export WORKER_SUBNET_CIDR_2=${12}
export WORKER_SUBNET_CIDR_3=${13}
export SSH_KEY_NAME=${14}
export IAM_ROLE_NAME=${15}
export DEPLOY_CP4D=${16}
export DEPLOY_MANAGE=${17}
export DEPLOY_MANAGED_APPS=${18}
export DEPLOY_WAIT_HANDLE=${19}
export SLS_ENTITLEMENT_KEY=${20}
export OCP_PULL_SECRET=${21}
export MAS_LICENSE_URL=${22}
export SLS_ENDPOINT_URL=${23}
export SLS_REGISTRATION_KEY=${24}
export SLS_PUB_CERT_URL=${25}
export BAS_ENDPOINT_URL=${26}
export BAS_API_KEY=${27}
export BAS_SEGMENT_KEY=${28}
export BAS_PUB_CERT_URL=${29}
export MAS_DB_USER=${30}
export MAS_DB_PASSWORD=${31}
export MAS_JDBC_URL=${32}
export MAS_JDBC_CERT_URL=${33}

# Load helper functions
. helper.sh
export -f log
export -f get_mas_creds
export -f retrieve_mas_ca_cert

# Check for input parameters
if [[ (-z $CLOUD_TYPE) || (-z $DEPLOY_REGION) || (-z $ACCOUNT_ID) || (-z $CLUSTER_SIZE) \
   || (-z $RANDOM_STR) || (-z $BASE_DOMAIN) || (-z $VPC_CIDR) || (-z $MASTER_SUBNET_CIDR_1) \
   || (-z $MASTER_SUBNET_CIDR_2) || (-z $MASTER_SUBNET_CIDR_3) || (-z $WORKER_SUBNET_CIDR_1) \
   || (-z $WORKER_SUBNET_CIDR_2) || (-z $WORKER_SUBNET_CIDR_3) || (-z $IAM_ROLE_NAME) || (-z $SSH_KEY_NAME) \
   || (-z $DEPLOY_CP4D) || (-z $DEPLOY_MANAGE) || (-z $DEPLOY_MANAGED_APPS) || (-z $DEPLOY_WAIT_HANDLE) ]]; then
  log "ERROR: Required parameter not specified, please provide all the required inputs to the script."
  PRE_VALIDATION=fail
fi
if [[ $DEPLOY_MANAGE == "true" ]]; then
  if [[ (-z $MAS_DB_USER) || (-z $MAS_DB_PASSWORD) || (-z $MAS_JDBC_URL) || (-z $MAS_JDBC_CERT_URL) ]]; then
    log "ERROR: Required parameter for MAS Manage app not specified, please provide all the required inputs to the script."
    PRE_VALIDATION=fail
  fi
fi

## Variables
# OCP variables
export GIT_REPO_HOME=$(pwd)
export CLUSTER_NAME="masocp-${RANDOM_STR}"
export OPENSHIFT_USER="masocpuser"
export OPENSHIFT_PASSWORD=masocp${RANDOM_STR}pass
export OPENSHIFT_PULL_SECRET_FILE_PATH="/tmp/pull-secret.json"
export MASTER_NODE_COUNT="3"
export WORKER_NODE_COUNT="3"
export AZ_MODE="multi_zone"
export KUBE_CONFIG="/root/mas-multicloud/aws/ocp-terraform/installer-files/auth/kubeconfig"
export MAS_IMAGE_TEST_DOWNLOAD="cp.icr.io/cp/mas/admin-dashboard:5.1.27"
# Mongo variables
export MAS_INSTANCE_ID="mas-${RANDOM_STR}"
export MAS_CONFIG_DIR=/var/tmp/masconfigdir
export MONGODB_NAMESPACE="mongoce-${RANDOM_STR}"
# Amqstreams variables
export KAFKA_NAMESPACE=amq-streams
export KAFKA_CLUSTER_NAME=test
export KAFKA_CLUSTER_SIZE=small
export KAFKA_USER_NAME=masuser
# SLS variables 
#export SLS_INSTANCE_NAME="sls-${RANDOM_STR}"
# BAS variables 
export BAS_PERSISTENT_STORAGE=ocs-storagecluster-cephfs
export BAS_PASSWORD=basuser
export BAS_CONTACT_MAIL="bas.support@ibm.com"
export BAS_CONTACT_FIRSTNAME=Bas
export BAS_CONTACT_LASTNAME=Support
export GRAPHANA_PASSWORD=password
# MAS variables
export MAS_ENTITLEMENT_KEY=$SLS_ENTITLEMENT_KEY
# CP4D variables
export CPD_ENTITLEMENT_KEY=$SLS_ENTITLEMENT_KEY
export CPD_STORAGE_CLASS=ocs-storagecluster-cephfs
# Manage variables
export MAS_APP_ID=manage
export MAS_WORKSPACE_ID="wsmasocp"

RESP_CODE=0

# Export env variables which are not set by default during userdata execution
export HOME=/root

# Decide clutser size
case $CLUSTER_SIZE in
  small)
    log "Using small size cluster"
    export MASTER_NODE_COUNT="3"
    export WORKER_NODE_COUNT="3"
    ;;
  medium)
    log "Using medium size cluster"
    export MASTER_NODE_COUNT="3"
    export WORKER_NODE_COUNT="5"
    ;;
  large)
    log "Using large size cluster"
    export MASTER_NODE_COUNT="5"
    export WORKER_NODE_COUNT="7"
    ;;
  *)
    log "Using default small size cluster"
    export MASTER_NODE_COUNT="3"
    export WORKER_NODE_COUNT="3"
    ;;
esac

# Log the variable values
log "Below are common deployment parameters,"
echo " HOME: $HOME"
echo " GIT_REPO_HOME: $GIT_REPO_HOME"
echo " CLOUD_TYPE: $CLOUD_TYPE"
echo " DEPLOY_REGION: $DEPLOY_REGION"
echo " ACCOUNT_ID: $ACCOUNT_ID"
echo " CLUSTER_SIZE: $CLUSTER_SIZE"
echo " RANDOM_STR: $RANDOM_STR"
echo " BASE_DOMAIN: $BASE_DOMAIN"
echo " VPC_CIDR: $VPC_CIDR"
echo " MASTER_SUBNET_CIDR_1: $MASTER_SUBNET_CIDR_1"
echo " MASTER_SUBNET_CIDR_2: $MASTER_SUBNET_CIDR_2"
echo " MASTER_SUBNET_CIDR_3: $MASTER_SUBNET_CIDR_3"
echo " WORKER_SUBNET_CIDR_1: $WORKER_SUBNET_CIDR_1"
echo " WORKER_SUBNET_CIDR_2: $WORKER_SUBNET_CIDR_2"
echo " WORKER_SUBNET_CIDR_3: $WORKER_SUBNET_CIDR_3"
echo " SSH_KEY_NAME: $SSH_KEY_NAME"
echo " IAM_ROLE_NAME: $IAM_ROLE_NAME"
echo " DEPLOY_CP4D: $DEPLOY_CP4D"
echo " DEPLOY_MANAGE: $DEPLOY_MANAGE"
echo " DEPLOY_MANAGED_APPS: $DEPLOY_MANAGED_APPS"
echo " SLS_ENTITLEMENT_KEY: $SLS_ENTITLEMENT_KEY"
echo " OCP_PULL_SECRET: $OCP_PULL_SECRET"
echo " MAS_LICENSE_URL: $MAS_LICENSE_URL"
echo " SLS_ENDPOINT_URL: $SLS_ENDPOINT_URL"
echo " SLS_REGISTRATION_KEY: $SLS_REGISTRATION_KEY"
echo " SLS_PUB_CERT_URL: $SLS_PUB_CERT_URL"
echo " BAS_ENDPOINT_URL: $BAS_ENDPOINT_URL"
echo " BAS_API_KEY: $BAS_API_KEY"
echo " BAS_SEGMENT_KEY: $BAS_SEGMENT_KEY"
echo " BAS_PUB_CERT_URL: $BAS_PUB_CERT_URL"
echo " MAS_DB_USER: $MAS_DB_USER"
echo " MAS_DB_PASSWORD: $MAS_DB_PASSWORD"
echo " MAS_JDBC_URL: $MAS_JDBC_URL"
echo " MAS_JDBC_CERT_URL: $MAS_JDBC_CERT_URL"
echo " CLUSTER_NAME: $CLUSTER_NAME"
echo " OPENSHIFT_USER: $OPENSHIFT_USER"
echo " OPENSHIFT_PASSWORD: $OPENSHIFT_PASSWORD"
echo " OPENSHIFT_PULL_SECRET_FILE_PATH: $OPENSHIFT_PULL_SECRET_FILE_PATH"
echo " MASTER_NODE_COUNT: $MASTER_NODE_COUNT"
echo " WORKER_NODE_COUNT: $WORKER_NODE_COUNT"
echo " AZ_MODE: $AZ_MODE"
echo " KUBE_CONFIG: $KUBE_CONFIG"
echo " MAS_INSTANCE_ID: $MAS_INSTANCE_ID"
echo " MAS_CONFIG_DIR: $MAS_CONFIG_DIR"
echo " KAFKA_NAMESPACE: $KAFKA_NAMESPACE"
echo " KAFKA_CLUSTER_NAME: $KAFKA_CLUSTER_NAME"
echo " KAFKA_CLUSTER_SIZE: $KAFKA_CLUSTER_SIZE"
echo " KAFKA_USER_NAME: $KAFKA_USER_NAME"
echo " BAS_PERSISTENT_STORAGE: $BAS_PERSISTENT_STORAGE"
echo " BAS_PASSWORD: $BAS_PASSWORD"
echo " BAS_CONTACT_MAIL: $BAS_CONTACT_MAIL"
echo " BAS_CONTACT_FIRSTNAME: $BAS_CONTACT_FIRSTNAME"
echo " BAS_CONTACT_LASTNAME: $BAS_CONTACT_LASTNAME"
echo " GRAPHANA_PASSWORD: $GRAPHANA_PASSWORD"
echo " MAS_ENTITLEMENT_KEY: $MAS_ENTITLEMENT_KEY"
echo " CPD_ENTITLEMENT_KEY: $CPD_ENTITLEMENT_KEY"
echo " CPD_STORAGE_CLASS: $CPD_STORAGE_CLASS"
echo " MAS_APP_ID: $MAS_APP_ID"
echo " MAS_WORKSPACE_ID: $MAS_WORKSPACE_ID"

# Get deployment options
export DEPLOY_CP4D=$(echo $DEPLOY_CP4D | cut -d '=' -f 2)
export DEPLOY_MANAGE=$(echo $DEPLOY_MANAGE | cut -d '=' -f 2)
export DEPLOY_MANAGED_APPS=$(echo $DEPLOY_MANAGED_APPS | cut -d '=' -f 2)

# Perform prevalidation checks
log "===== PRE-VALIDATION STARTED ====="
./pre-validate.sh
if [[ $? -ne 0 ]]; then
  log "Prevalidation checks failed"
  PRE_VALIDATION=fail
  mark_provisioning_failed
else
  log "Prevalidation checks successful"
  PRE_VALIDATION=pass
fi
log "===== PRE-VALIDATION COMPLETED ($PRE_VALIDATION) ====="

# Prrform the MAS deployment only if pre-validation checks are passed
if [[ $PRE_VALIDATION == "pass" ]]; then
  # Create Red Hat pull secret
  echo "$OCP_PULL_SECRET" > /tmp/pull-secret.json

  # Call cloud specific script
  chmod +x $CLOUD_TYPE/*.sh
  log "===== PROVISIONING STARTED ====="
  log "Calling cloud specific automation ..."
  cd $CLOUD_TYPE
  ./deploy.sh
  if [[ $? -eq 0 ]]; then
    log "Deployment successful"
    log "===== PROVISIONING COMPLETED ====="
    export status=SUCCESS
    RESP_CODE=0
  else
    mark_provisioning_failed
  fi
fi

## Complete the template deployment
if [[ $CLOUD_TYPE == "aws" ]]; then
  cd $GIT_REPO_HOME/$CLOUD_TYPE
  # Complete the CFT stack creation
  log "Sending completion signal to CloudFormation stack"
  curl -k -X PUT -H 'Content-Type:' --data-binary "{\"Status\":\"SUCCESS\",\"Reason\":\"MAS deployment complete\",\"UniqueId\":\"ID-$CLOUD_TYPE-$CLUSTER_SIZE-$CLUSTER_NAME\",\"Data\":\"MAS deployment completed.\"}" "$DEPLOY_WAIT_HANDLE"

  # Send email notification
  sleep 30
  log "Sending notification"
  ./notify.sh
fi
exit $RESP_CODE
