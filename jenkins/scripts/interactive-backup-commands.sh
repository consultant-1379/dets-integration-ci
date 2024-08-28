#!/bin/bash

COMMAND=$1

BACKUP_NAME=$(cat /workdir/.bob/var.backup_name)

if [[ $COMMAND == "backup export" ]] || [[ $COMMAND == "backup import" ]]; then
    #docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir --volume $PWD/aws:/.aws --volume /etc/hosts:/etc/hosts --volume /usr/local/bin:/usr/local/bin --volume /usr/local/aws-cli:/usr/local/aws-cli --workdir /workdir -e AWS_CONFIG_FILE=/workdir/aws/config -e AWS_SHARED_CREDENTIALS_FILE=/workdir/aws/credentials armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:latest $COMMAND -h "https://${GAS_HOSTNAME}" --name $BACKUP_NAME  -d "${BACKUP_SERVER}:22/backup-data" -v $DEBUG_MODE -n $NAMESPACE;
    kubectl --namespace $NAMESPACE exec -it --kubeconfig ./admin.conf deploymentmanager -- /venv/.venv/bin/python -m deployment_manager $COMMAND -h "https://${GAS_HOSTNAME}" --name $BACKUP_NAME  -d "${BACKUP_SERVER}" -v $DEBUG_MODE -n $NAMESPACE;
fi;

if [[ $COMMAND == "backup create" ]] || [[ $COMMAND == "restore" ]] || [[ $COMMAND == "backup delete" ]]; then
    #docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir --volume $PWD/aws:/.aws --volume /etc/hosts:/etc/hosts --volume /usr/local/bin:/usr/local/bin --volume /usr/local/aws-cli:/usr/local/aws-cli --workdir /workdir -e AWS_CONFIG_FILE=/workdir/aws/config -e AWS_SHARED_CREDENTIALS_FILE=/workdir/aws/credentials armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:latest $COMMAND -h "https://${GAS_HOSTNAME}" --name $BACKUP_NAME -v $DEBUG_MODE -n $NAMESPACE;
    kubectl --namespace $NAMESPACE exec -it --kubeconfig ./admin.conf deploymentmanager -- /venv/.venv/bin/python -m deployment_manager $COMMAND -h "https://${GAS_HOSTNAME}" --name $BACKUP_NAME -v $DEBUG_MODE -n $NAMESPACE;
fi;

if [[ $COMMAND == "backup view" ]]; then
    kubectl --namespace $NAMESPACE exec -it --kubeconfig ./admin.conf deploymentmanager -- /venv/.venv/bin/python -m deployment_manager $COMMAND -h "https://${GAS_HOSTNAME}" -v $DEBUG_MODE -n $NAMESPACE;
    #docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir --volume $PWD/aws:/.aws --volume /etc/hosts:/etc/hosts --volume /usr/local/bin:/usr/local/bin --volume /usr/local/aws-cli:/usr/local/aws-cli --workdir /workdir -e AWS_CONFIG_FILE=/workdir/aws/config -e AWS_SHARED_CREDENTIALS_FILE=/workdir/aws/credentials armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:latest $COMMAND -h "https://${GAS_HOSTNAME}" -v $DEBUG_MODE -n $NAMESPACE;
fi;

if [[ $COMMAND == "backup housekeeping set-backup-limit" ]]; then
    if [[ $BACKUP_SCOPE == 'no_backup' ]]; then
        echo "docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL -v $DEBUG_MODE --max-stored-manual-backups $MAX_STORED_MANUAL_BACKUPS --auto-delete $AUTO_DELETE;"
        docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL -v $DEBUG_MODE --max-stored-manual-backups $MAX_STORED_MANUAL_BACKUPS --auto-delete $AUTO_DELETE;
    else
        echo "docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL --scope $BACKUP_SCOPE -v $DEBUG_MODE --max-stored-manual-backups $MAX_STORED_MANUAL_BACKUPS --auto-delete $AUTO_DELETE;"
        docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL --scope $BACKUP_SCOPE -v $DEBUG_MODE --max-stored-manual-backups $MAX_STORED_MANUAL_BACKUPS --auto-delete $AUTO_DELETE;
    fi;
fi;
if [[ $COMMAND == "backup housekeeping view-limit" ]]; then
    if [[ $BACKUP_SCOPE == 'no_backup' ]]; then
        echo "docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL -v $DEBUG_MODE 2>&1 | tee $TEMPORARY_FILE 1>&2;"
        docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL -v $DEBUG_MODE 2>&1 | tee $TEMPORARY_FILE 1>&2;
    else
        echo "docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL --scope $BACKUP_SCOPE -v $DEBUG_MODE 2>&1 | tee $TEMPORARY_FILE 1>&2;"
        docker run -it --rm -u $(id -u):$(id -g) -v $PWD:/workdir armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:$EO_CHART_VERSION $COMMAND -h $HOST_URL --scope $BACKUP_SCOPE -v $DEBUG_MODE 2>&1 | tee $TEMPORARY_FILE 1>&2;
    fi;
fi;
