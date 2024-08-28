#!/bin/bash

NAMESPACE=$1
KUBE_CONFIG=$2
ENV_NAME=$3

function prepare_create_snapshot_script()
{
cat >create_snapshot.sh <<EOF
#!/bin/bash

echo "Taking afterDeploy snapshot"
nodetool -h localhost -p 7199 snapshot -t afterDeploy dox zusammen_dox sdcrepository sdcartifact sdcaudit sdctitan policy

echo "Preparing tar file with afterDeploy snapshot"
find /var/lib/cassandra/data |grep afterDeploy |tar -cf /tmp/afterdeploy.tar --files-from=-
EOF
}

function copy_execute_script()
{
    echo -e "***** Checking if afterDeploy snapshot exist \n"
    kubectl --kubeconfig="${KUBE_CONFIG}" exec eric-data-wide-column-database-cd-0 -c cassandra -n "${NAMESPACE}" -- nodetool listsnapshots |grep afterDeploy > /dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo -e "The snapshot afterDeploy already exist, skipping ... \n"
    else
        echo -e "Copying script to Cassandra pod \n"
        kubectl --kubeconfig ${KUBE_CONFIG} cp create_snapshot.sh "${NAMESPACE}"/eric-data-wide-column-database-cd-0:/tmp/create_snapshot.sh
        if [[ $? -eq 0 ]]; then
            echo -e "Setting execute permission on the script \n"
            kubectl --kubeconfig="${KUBE_CONFIG}" exec eric-data-wide-column-database-cd-0 -c cassandra -n "${NAMESPACE}" -- chmod 555 /tmp/create_snapshot.sh

            echo -e "#### Executing the script \n"
            kubectl --kubeconfig="${KUBE_CONFIG}" exec eric-data-wide-column-database-cd-0 -c cassandra -n "${NAMESPACE}" -- /tmp/create_snapshot.sh
            if [[ $? -eq 0 ]]; then
                echo -e "Copying tar file from cassandra pod \n"
                kubectl --kubeconfig="${KUBE_CONFIG}" cp "${NAMESPACE}"/eric-data-wide-column-database-cd-0:/tmp/afterdeploy.tar afterdeploy.tar
                backup_tar_bucket
            else
                echo -e "Failed to create the snapshot \n"
                exit 1
            fi
        else
            echo -e "Failed to copy script to cassanda pod \n"
            exit 1
        fi
    fi
}

function backup_tar_bucket()
{
    echo -e "Moving existing tar file \n"
    aws s3 rm s3://"${ENV_NAME}"-backup/pre-install_afterdeploy.tar
    aws s3 mv s3://"${ENV_NAME}"-backup/afterdeploy.tar s3://"${ENV_NAME}"-backup/pre-install_afterdeploy.tar

    echo -e "Copying the new tar file \n"
    aws s3 cp afterdeploy.tar s3://"${ENV_NAME}"-backup/afterdeploy.tar
    if [[ $? -eq 0 ]]; then
        echo -e "Successfully copied afterdeploy.tar to S3 \n"
    else
        echo -e "Failed to copy the afterdeploy.tar to S3 \n"
        exit 1
    fi
}

prepare_create_snapshot_script
if [[ -s create_snapshot.sh ]]; then
    copy_execute_script
else
    echo -e "File create_snapshot.sh does not exist or is empty \n"
fi
