#!/bin/bash

KUBE_CONFIG="$1"
NAMESPACE="$2"
ENV_NAME="$3"

function copy_scripts()
{
    echo -e "Copying restore_cassandra.sh to the Cassandra pod \n"
    kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" cp jenkins/scripts/restore_cassandra.sh eric-data-wide-column-database-cd-0:/tmp/
    kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" exec eric-data-wide-column-database-cd-0 -- chmod 555 /tmp/restore_cassandra.sh
}

function verify_copy_snapshot()
{
    num_afterDeploy=$(kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" exec eric-data-wide-column-database-cd-0 -- bash \
    -c "cd /; nodetool listsnapshots | grep afterDeploy | wc -l")

    if [ "${num_afterDeploy}" -gt 0 ]; then
        echo 'DB snapshot exist'
    else
        echo -e "DB snapshot does not exist. Downloading snapshot tar file...\n"
        aws s3 cp s3://"${ENV_NAME}"-backup/afterdeploy.tar .
        echo 'Copy snapshot tar file to cassandra pod'
        kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" cp afterdeploy.tar "${NAMESPACE}"/eric-data-wide-column-database-cd-0:/tmp/afterdeploy.tar
        if [[ $? -eq 0 ]]; then
            echo 'Untar snapshot tar file'
            kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" exec eric-data-wide-column-database-cd-0 -- bash -c "cd /; \
            tar -xf /tmp/afterdeploy.tar"
            sleep 30
            echo 'Verifying snapshot'
            num_verify_afterDeploy=$(kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" exec eric-data-wide-column-database-cd-0 -- bash \
            -c "cd /; nodetool listsnapshots | grep afterDeploy | wc -l")
            echo "${num_verify_afterDeploy}"
            if [[ "${num_verify_afterDeploy}" -gt 0 ]]; then
                echo 'DB snapshot is ready'
            else
                echo 'Error: DB snapshot is not ready'
                exit 1
            fi
        else
            echo "Failed to copy snapshot"
            exit 1
        fi
    fi
}

function restore_snapshot()
{
    echo -e "Restoring Cassandra snapshot ...\n"
    kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" exec eric-data-wide-column-database-cd-0 -- /tmp/restore_cassandra.sh
    if [[ $? -eq 0 ]]; then
        echo "Successfully restored snapshot"
    else
        echo "Error: Failed to restore snapshot"
        exit 1
    fi
}

function restart_pods_jobs()
{
    echo -e "Retarting the uds service pod and jobs \n"
    UDSPOD=$(kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" get  pod -o=name| grep -Ei "uds-service" | grep -Eiv "uds-service-config")
    kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" delete "${UDSPOD}"
    kubectl --kubeconfig "${KUBE_CONFIG}" get job -n "${NAMESPACE}" eric-oss-uds-service-config-cassandra-job -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | kubectl --kubeconfig "${KUBE_CONFIG}" replace --force -f -
    kubectl --kubeconfig "${KUBE_CONFIG}" get job -n "${NAMESPACE}" eric-oss-uds-onboarding-service-job -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | kubectl --kubeconfig "${KUBE_CONFIG}" replace --force -f -
    kubectl --kubeconfig "${KUBE_CONFIG}" get job -n "${NAMESPACE}" eric-oss-uds-service-config-backend-job -o json | jq 'del(.spec.selector)' | jq 'del(.spec.template.metadata.labels)' | kubectl --kubeconfig "${KUBE_CONFIG}" replace --force -f -
    sleep 2m
}

function cleanup_snapshot()
{
    echo "Cleaning up the snapshot"
    kubectl --kubeconfig "${KUBE_CONFIG}" -n "${NAMESPACE}" exec eric-data-wide-column-database-cd-0 -- bash \
    -c "cd /; nodetool clearsnapshot"
}

copy_scripts
verify_copy_snapshot
if [[ $? -eq 0 ]]; then
    restore_snapshot
    if [[ $? -eq 0 ]]; then
        restart_pods_jobs
        cleanup_snapshot
    fi
fi
