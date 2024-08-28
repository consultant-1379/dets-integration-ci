#!/bin/bash
ACTION=$1
NAMESPACE=kube-system
KUBE_CONFIG_PATH=$2

#VARIABLES
ECHO="/bin/echo"
KUBECTL="/usr/local/bin/kubectl"

#######################################################
# Scaling down the kube-downscaler                    #
#                                                     #
# Until the upgrade finishes                          #
#                                                     #
#######################################################
function pause_kube_downscaler()
{
    ${ECHO} "Pausing the kube-downscaler"
    ${KUBECTL} scale deploy kube-downscaler  \
        --kubeconfig "${KUBE_CONFIG_PATH}" \
        --namespace="${NAMESPACE}" \
        --replicas=0
    if [[ $? -ne 0 ]];then
        exit 1
# The above command will scale the kube-downscaler running under the kube-system namespaces from 1 to 0
    fi
    ${ECHO} "The kube-downscaler been scaled down"
}

#######################################################
# Scaling up the kube-downscaler                      #
#                                                     #
# Once the upgrade finishes                           #
#                                                     #
#######################################################

function resume_kube_downscaler()
{
    ${ECHO} "Resuming the kube-downscaler"
    ${KUBECTL} scale deploy kube-downscaler  \
        --kubeconfig "${KUBE_CONFIG_PATH}" \
        --namespace="${NAMESPACE}" \
        --replicas=1
    if [[ $? -ne 0 ]];then
        exit 1
# The above command will scale the kube-downscaler running under the kube-system namespaces from 0 to 1
    fi
    ${ECHO} "The kube-downscaler been scaled up"
}

if [ "$ACTION" == "pause" ]; then
    pause_kube_downscaler
elif [ "$ACTION" == "resume" ]; then
    resume_kube_downscaler
fi
