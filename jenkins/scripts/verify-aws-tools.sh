#!/bin/bash


# extract parameters:
while [ $# -gt 0 ]; do
    case "$1" in
        "--aws-region")
            shift
            AWS_REGION="$1"
        ;;
        "--deployment-dir")
            shift
            DEPLOYMENT_DIR="$1"
        ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            echo "$0 --aws-region <AWS_REGION> --deployment-dir <PATH_TO_DEPLOYMENT_DIR>"
            echo "Example: $0 --aws-region eu-west-1 --deployment-dir ci/deployments/bnew03"
            exit -1
        ;;
    esac
    shift
done

ENV_NAME=$(basename $DEPLOYMENT_DIR)

echo "AWS_REGION=$AWS_REGION DEPLOYMENT_DIR=$DEPLOYMENT_DIR ENV_NAME=$ENV_NAME"

test -z "$AWS_REGION" -o -z "$DEPLOYMENT_DIR" -o -z "$ENV_NAME" \
    && echo "Error: missing parameter" \
    && exit -5

test ! -d "$DEPLOYMENT_DIR" \
    && echo "Error: deployment dir does not exist" \
    && exit -6



echo "==> verify-aws-region"

test "${AWS_REGION}" == "none" \
   && echo "ERROR Invalid value AWS_REGION=none" \
   && exit -7 \
   || echo "AWS_REGION=${AWS_REGION}"



echo "==> verify-awscli"

cd ${DEPLOYMENT_DIR}
if [ ! -d ./aws ]; then
  echo "Failed to locate the required aws folder at $(pwd)/aws"
  exit 1
else
  if [ ! -f ./aws/config -o ! -f ./aws/credentials ]; then
    echo "Failed to locate required config and/or credentials file in $(pwd)/aws"
    exit 1
  else
    export AWS_CONFIG_FILE=$(pwd)/aws/config
    export AWS_SHARED_CREDENTIALS_FILE=$(pwd)/aws/credentials
    if ! /usr/local/bin/aws --region $AWS_REGION sts get-caller-identity; then
      echo "Failed to verify AWS connectivity for credentials and config in $(pwd)/aws"
      exit 1
    else
      echo "Successfully verified AWS connectivity for credentials and config in $(pwd)/aws"
    fi
  fi
fi



echo "==> verify-authenticator"

cd ${DEPLOYMENT_DIR}/workdir
if [ ! -x ./aws-iam-authenticator ]; then
  echo "Failed to locate aws-iam-authenticator binary in $(pwd) or binary is not executable"
  exit 1
else
  echo "Successfully located aws-iam-authenticator binary in $(pwd)"
fi

echo "==> verify-no-pre-existent-cluster"
cd ${DEPLOYMENT_DIR}
export AWS_CONFIG_FILE=$(pwd)/aws/config
export AWS_SHARED_CREDENTIALS_FILE=$(pwd)/aws/credentials
export AWS_DEFAULT_REGION=${AWS_REGION}
if /usr/local/bin/aws cloudformation describe-stacks | jq ".Stacks[] | .StackName" | grep -w "${ENV_NAME}" >/dev/null; then
  echo "A cluster ${ENV_NAME}-EKS-Cluster for the ${ENV_NAME} deployment already exists"
  exit 1
fi


exit 0
