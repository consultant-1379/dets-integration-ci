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
# Name      : generate_config.sh
# Date      : 5th July 2021
# Revision  : N/A
# Purpose   : Populate an IDUNaaS config.yaml with supplied parameters
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
WORKDIR=${25}
ADC_HOSTNAME=${26}
APPMGR_HOSTNAME=${27}
OS_HOSTNAME=${28}
DISABLEPUBLICACCESS=${29}

cd ${WORKDIR}

cat > config.yaml <<EOF
EnvironmentName: "$ENV_NAME"
AWSRegion: "$AWS_REGION"
K8SVersion: "$K8S_VERSION"
VPCID: "$VPC_ID"
ControlPlaneSubnetIds: "$CONTROL_PLANE_SUBNET_IDS"
WorkerNodeSubnetIds: "$WORKER_NODE_SUBNET_ID"
SecondaryVpcCIDR: "$SECONDARY_VPC_CIDR"
NodeInstanceType: "$NODE_INSTANCE_TYPE"
DiskSize: $DISK_SIZE
MinNodes: $MIN_NODES
MaxNodes: $MAX_NODES
SshKeyPairName: "$SSH_KEYPAIR_NAME"
PrivateDomainName: "$PRIVATE_DN"
KubeDownscaler: $KUBEDOWNSCALER
BackupInstanceType: "$BACKUP_INSTANCE_TYPE"
BackupAmiId: "$BACKUP_AMI_ID"
BackupDisk: $BACKUP_DISK
BackupPass: "$BACKUP_PASS"
Hostnames:
  so: "$SO_HOSTNAME"
  pf: "$PF_HOSTNAME"
  uds: "$UDS_HOSTNAME"
  iam: "$IAM_HOSTNAME"
  gas: "$GAS_HOSTNAME"
  monitoring: "$MONITORING_HOSTNAME"
  adc: "$ADC_HOSTNAME"
  appmgr: "$APPMGR_HOSTNAME"
  os: "$OS_HOSTNAME"
DisablePublicAccess: $DISABLEPUBLICACCESS
EOF