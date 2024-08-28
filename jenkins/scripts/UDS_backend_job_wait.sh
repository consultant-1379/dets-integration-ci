#!/bin/bash

NAMESPACE=$1
KUBECONFIG=$2
retries="40";
while [ $retries -ge 0 ]
do
pod=$(kubectl get pods --namespace ${NAMESPACE} --kubeconfig ${KUBECONFIG} | grep -E eric-oss-uds-service-config-backend-job)
    if [[ "$retries" -eq "0" ]]
    then
        echo "UDS backend job failed. Please investigate."
        exit 1
    elif [[ "$pod" == *"Running"* ]];
    then
        let "retries-=1"
        echo "UDS backend job still running, Retries left = $retries :: Sleeping for 60 seconds"
        sleep 60
    else
        echo "UDS Backend Job has completed."
        break
    fi
done