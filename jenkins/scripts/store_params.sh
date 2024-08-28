#!/bin/bash

# ********************************************************************
# Ericsson Radio Systems AB                                     SCRIPT
# ********************************************************************
#
#
# (c) Ericsson Radio Systems AB 2020 - All rights reserved.
#
# The copyright to the computer program(s) herein is the property
# of Ericsson Radio Systems AB, Sweden. The programs may be used
# and/or copied only with the written permission from Ericsson Radio
# Systems AB or in accordance with the terms and conditions stipulated
# in the agreement/contract under which the program(s) have been
# supplied.
#
#
# ********************************************************************
# Name      : store_params.sh
# Date      : 5th July 2021
# Revision  : N/A
# Purpose   : Generate an artifact.properties file from a combination
#             of user-specified override parameters and parameters
#             from SCM in order to pass deployment data back to
#             Spinnaker for retrieval later in the
#             IDUNAAS_SETUP_AWS_CLUSTER pipeline
######################################################################

ENV_NAME=${1}
AWS_REGION=${2}
K8S_VERSION=${3}
VPC_ID=${4}
CONTROL_PLANE_SUBNET_IDS=${5}
WORKER_NODE_SUBNET_ID=${6}
SECONDARY_VPC_CIDR=${7}
NODE_INSTANCE_TYPE=${8}
DISK_SIZE=${9}
MIN_NODES=${10}
MAX_NODES=${11}
SSH_KEYPAIR_NAME=${12}
PRIVATE_DN=${13}
KUBEDOWNSCALER=${14}
BACKUP_INSTANCE_TYPE=${15}
BACKUP_AMI_ID=${16}
BACKUP_DISK=${17}
BACKUP_PASS=${18}
SO_HOSTNAME=${19}
PF_HOSTNAME=${20}
UDS_HOSTNAME=${21}
IAM_HOSTNAME=${22}
GAS_HOSTNAME=${23}
MONITORING_HOSTNAME=${24}
CFG_PATH=${25}
WORKDIR=${26}
ADC_HOSTNAME=${27}
APPMGR_HOSTNAME=${28}
OS_HOSTNAME=${29}
DISABLEPUBLICACCESS=${30}


YQ="/usr/local/bin/yq"

cd ${WORKDIR}; if [ -f artifact.properties ]; then rm -f artifact.properties; fi;

#############################################################################
# Return the value of a given key from the IDUNaaS config.yaml              #
# for a particular deployment, or the user-provided override value for      #
# that key, if such an override was provided (i.e not equal to 'none').     #
#                                                                           #
# Arguments:                                                                #
#   1. The key name as a string e.g. 'AWSRegion'                            #
#   2. The override value of the key as a string e.g. 'eu-west-1' or 'none' #
# Returns: The value for the to be injected into artifact.properties        #
#############################################################################
param_value() {
  local VAL=""
  if [ "${2}" == "none" ]; then         # No override value was supplied
    test -e $CFG_PATH && \
        VAL=$(${YQ} -r .${1} ${CFG_PATH}) # Return the value of the key from the config.yaml
  else
    VAL="${2}"                         # Return the override value provided
  fi;
  if [ "$VAL" == "" -o "$VAL" == "null" -o "$VAL" == "none" ]; then
    echo "Value $1 not provided" >&2
    kill $$   # kill current script
  fi
  echo $VAL
}

cat > artifact.properties <<EOF
ENV_NAME=$(param_value "EnvironmentName" "${ENV_NAME}")
AWS_REGION=$(param_value "AWSRegion" "$AWS_REGION")
K8S_VERSION=$(param_value "K8SVersion" "$K8S_VERSION")
VPC_ID=$(param_value "VPCID" "$VPC_ID")
CONTROL_PLANE_SUBNET_IDS=$(param_value "ControlPlaneSubnetIds" "$CONTROL_PLANE_SUBNET_IDS")
WORKER_NODE_SUBNET_ID=$(param_value "WorkerNodeSubnetIds" "$WORKER_NODE_SUBNET_ID")
SECONDARY_VPC_CIDR=$(param_value "SecondaryVpcCIDR" "$SECONDARY_VPC_CIDR")
NODE_INSTANCE_TYPE=$(param_value "NodeInstanceType" "$NODE_INSTANCE_TYPE")
DISK_SIZE=$(param_value "DiskSize" "$DISK_SIZE")
MIN_NODES=$(param_value "MinNodes" "$MIN_NODES")
MAX_NODES=$(param_value "MaxNodes" "$MAX_NODES")
SSH_KEYPAIR_NAME=$(param_value "SshKeyPairName" "$SSH_KEYPAIR_NAME")
PRIVATE_DN=$(param_value "PrivateDomainName" "$PRIVATE_DN")
KUBEDOWNSCALER=$(param_value "KubeDownscaler" "$KUBEDOWNSCALER")
BACKUP_INSTANCE_TYPE=$(param_value "BackupInstanceType" "$BACKUP_INSTANCE_TYPE")
BACKUP_AMI_ID=$(param_value "BackupAmiId" "$BACKUP_AMI_ID")
BACKUP_DISK=$(param_value "BackupDisk" "$BACKUP_DISK")
BACKUP_PASS=$(param_value "BackupPass" "$BACKUP_PASS")
SO_HOSTNAME=$(param_value "Hostnames.so" "$SO_HOSTNAME")
PF_HOSTNAME=$(param_value "Hostnames.pf" "$PF_HOSTNAME")
UDS_HOSTNAME=$(param_value "Hostnames.uds" "$UDS_HOSTNAME")
IAM_HOSTNAME=$(param_value "Hostnames.iam" "$IAM_HOSTNAME")
GAS_HOSTNAME=$(param_value "Hostnames.gas" "$GAS_HOSTNAME")
MONITORING_HOSTNAME=$(param_value "Hostnames.monitoring" "$MONITORING_HOSTNAME")
ADC_HOSTNAME=$(param_value "Hostnames.adc" "$ADC_HOSTNAME")
APPMGR_HOSTNAME=$(param_value "Hostnames.appmgr" "$APPMGR_HOSTNAME")
OS_HOSTNAME=$(param_value "Hostnames.os" "$OS_HOSTNAME")
DISABLEPUBLICACCESS=$(param_value "DisablePublicAccess" "$DISABLEPUBLICACCESS")
EOF
