#!/bin/bash
SCRIPT_STATUS=0

# Check if region is supported
if [[ $DEPLOY_REGION != "us-east-2" ]] && [[ $DEPLOY_REGION != "us-west-2" ]] && \
   [[ $DEPLOY_REGION != "ap-south-1" ]]; then
   echo "Supported region = FAIL"
   SCRIPT_STATUS=1
else
   echo "Supported region = PASS"
fi

# Check if ER key is valid
skopeo inspect --creds "cp:$SLS_ENTITLEMENT_KEY" docker://$MAS_IMAGE_TEST_DOWNLOAD
if [ $? -eq 0 ]; then
   echo "ER Key verification = PASS"
else
   echo "ER Key verification = FAIL"
   SCRIPT_STATUS=1
fi

# Check if provided hosted zone is public
aws route53 list-hosted-zones --output text --query 'HostedZones[*].[Config.PrivateZone,Name,Id]' --output text | grep $BASE_DOMAIN | grep False
if [ $? -eq 0 ]; then
   echo "MAS public domain verification = PASS"
else
   echo "MAS public domain verification = FAIL"
   SCRIPT_STATUS=1
fi
exit $SCRIPT_STATUS