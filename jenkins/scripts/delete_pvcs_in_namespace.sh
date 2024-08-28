#!/bin/bash

set -o nounset
set -o errexit

NAMESPACE=$1
KUBE_CONFIG_PATH=$2

get_pvc_names() {
  PVC_NAMES=$(kubectl get pvc -n "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG_PATH}" | tail -n +2 | cut -d' ' -f1)
  echo "${PVC_NAMES}"
}

#MAX_ATTEMPTS=120
#ATTEMPT_NUMBER=1
#echo "Waiting for all pods to be removed from namespace ${NAMESPACE}"
#while true
#  do
#    echo "Attempt ${ATTEMPT_NUMBER} of ${MAX_ATTEMPTS}."
#    LEFT_PODS=$(kubectl get pods -n ${NAMESPACE} --kubeconfig ${KUBE_CONFIG_PATH} 2>&1)
#    if [[ ${LEFT_PODS} == *'No resources found'* ]]
#    then
#        echo "No Pods left - continuing with pvc removal"
#        break
#    else
#        echo "Remaining pods:"
#        echo -e "\n${LEFT_PODS}\n";
#    fi
#
#    if [[ $ATTEMPT_NUMBER -eq $MAX_ATTEMPTS ]]
#    then
#      echo "ERROR: The PODs didn't get deleted after $MAX_ATTEMPTS attempts to check them"
#      exit 1
#    fi
#
#    echo "Some PODS above still remain, waiting 10 seconds before checking again"
#    sleep 10
#    ATTEMPT_NUMBER=$((ATTEMPT_NUMBER+1))
#done;

echo "Started removing all PVCs from namespace ${NAMESPACE}"
MAX_ATTEMPTS=120
ATTEMPT_NUMBER=1
while true
do
  echo "Attempt ${ATTEMPT_NUMBER} of ${MAX_ATTEMPTS}."
  echo "Started deleting all online PVCs in namespace ${NAMESPACE}"
  for PVC in $(get_pvc_names)
  do
    # TODO: Remove the if and echo and just leave the kubectl command when SM-60794 is resolved
    if ! kubectl delete pvc ${PVC} -n "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG_PATH}"
    then
      echo "kubectl delete pvc ${PVC} : failed"
    fi
    sleep 4
  done

  echo "Completed deleting all online PVCs in namespace ${NAMESPACE}"
  PVCS=$(kubectl get pvc  -n "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG_PATH}" 2>&1)
  if ! echo "$PVCS" | grep "No resources found"
  then
    echo "$PVCS"
    if [[ $ATTEMPT_NUMBER -eq $MAX_ATTEMPTS ]]
    then
      echo "ERROR: The pvcs didn't get deleted after $MAX_ATTEMPTS attempts to check them"
      exit 1
    fi
    echo "Some PVCs above still remain, waiting 10 seconds before checking again"
    sleep 10
    ATTEMPT_NUMBER=$((ATTEMPT_NUMBER+1))
  else
    break
  fi
done
echo "Completed waiting for all pvcs to be removed from namespace ${NAMESPACE}"

echo "Started waiting for all PVs for namespace ${NAMESPACE} to be removed."
MAX_ATTEMPTS=120
ATTEMPT_NUMBER=1
while true
do
  echo "Attempt ${ATTEMPT_NUMBER} of ${MAX_ATTEMPTS}."
  PVS=$(kubectl get pv --kubeconfig "${KUBE_CONFIG_PATH}")
  if echo "$PVS" | grep " ${NAMESPACE}/"
  then
    echo "$PVS" | grep " ${NAMESPACE}/"
    if [[ $ATTEMPT_NUMBER -eq $MAX_ATTEMPTS ]]
    then
      echo "ERROR: The pvs didn't get deleted after $MAX_ATTEMPTS attempts to check them"
      exit 1
    fi
    echo "Some PVs above still remain, waiting 10 seconds before checking again"
    sleep 10
    ATTEMPT_NUMBER=$((ATTEMPT_NUMBER+1))
  else
    break
  fi
done
echo "All PVs for namespace ${NAMESPACE} removed."