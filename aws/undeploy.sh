#!/bin/bash
set -e

# This script will initiate the undeployment process of MAS. It will perform following steps,

# Variables
RANDOM_STR=$(cat /root/mas-multicloud/mas-provisioning.log | grep "RANDOM_STR:" | cut -d ':' -f 2 | tr -d ' ')
REGION=$(cat /root/mas-multicloud/mas-provisioning.log | grep "DEPLOY_REGION:" | cut -d ':' -f 2 | tr -d ' ')
ACCOUNT_ID=$(cat /root/mas-multicloud/mas-provisioning.log | grep "ACCOUNT_ID:" | cut -d ':' -f 2 | tr -d ' ')
ACCESS_KEY_ID=$(cat /root/mas-multicloud/mas-provisioning.log | grep "AWS_ACCESS_KEY_ID:" | cut -d ':' -f 2 | tr -d ' ')
IAM_POLICY_NAME="masocp-policy-${RANDOM_STR}"
IAM_USER_NAME="masocp-user-${RANDOM_STR}"

# Call cloud specific script
log "==== OCP cluster deletion started ===="
# Undeploy OCP cluster
cd $GIT_REPO_HOME/aws/ocp-terraform
terraform destroy -input=false -auto-approve
log "==== OCP cluster deletion completed ===="

# Delete S3 bucket used for backup
BUCKET_NAME="masocp-bucket-${REGION}-${RANDOM_STR}"
aws s3 rb s3://${BUCKET_NAME} --force
log "Deleted bucket $BUCKET_NAME"

# Delete IAM resources
#aws iam detach-user-policy --user-name ${IAM_USER_NAME} --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${IAM_POLICY_NAME}
#aws iam delete-access-key --user-name ${IAM_USER_NAME} --access-key-id ${ACCESS_KEY_ID}
#aws iam delete-user --user-name ${IAM_USER_NAME}
#aws iam delete-policy --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/${IAM_POLICY_NAME}
#log "Deleted policy ${IAM_POLICY_NAME}, user ${IAM_USER_NAME}"
log "Please delete the IAM user ${IAM_USER_NAME} and IAM policy ${IAM_POLICY_NAME} manually"