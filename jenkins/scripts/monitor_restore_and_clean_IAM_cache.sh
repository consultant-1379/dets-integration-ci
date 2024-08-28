#!/bin/bash

function log {
    echo "$(date) | $1"
}

function usage {
    log "Usage: $0 --env-name <environment name> --namespace <k8s namespace>"
    log "Example: $0 --env-name idunaasdev02 --namespace ossdev02"
}

# extract parameters:
while [ $# -gt 0 ]; do
    case "$1" in
        "--env-name")
            shift
            ENV_NAME="$1"
        ;;
        "--namespace")
            shift
            NAMESPACE="$1"
        ;;
        *)
            log "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            usage
            exit -1
        ;;
    esac
    shift
done

if [ -z "$ENV_NAME" -o -z "$NAMESPACE" ]; then
    log "[$(basename $0)] ERROR: empty parameter NAMESPACE=$NAMESPACE ENV_NAME=$ENV_NAME"
    usage
    exit -2
fi

test ! -d $PWD/deployments -o \
     ! -f $PWD/deployments/${ENV_NAME}/workdir/kube_config/config && -o \
     ! -d $PWD/deployments/${ENV_NAME}/aws     && \
    log "ERROR: missing folder 'deployments'"  && \
    log "PWD=$PWD ls=$(ls | xargs)"            && \
    exit -3


### Main Script

log "ENV_NAME=$ENV_NAME"

C=0
TIMEOUT_IN_SECONDS=600  # 10 minutes
TIME_TO_SLEEP=3         # seconds
YES=0
while [ $C -le $TIMEOUT_IN_SECONDS ]; do
    log "Monitoring logs: elapsed $C seconds (timeout after $TIMEOUT_IN_SECONDS seconds)"

    if [ -e logs/*_restore.log ]; then
        grep -q -F \
            ' __call_bur_rest_api: status_code=503, response=no healthy upstream' \
            logs/*_restore.log; FOUND=$?
        if [ $FOUND -eq $YES ]; then
            for i in 0 1; do
                kubectl --kubeconfig \
                    <(sed -e s@/workdir/aws/@$PWD/deployments/${ENV_NAME}/aws/@ $PWD/deployments/${ENV_NAME}/workdir/kube_config/config) \
                    -n $NAMESPACE \
                    delete pod eric-sec-access-mgmt-${i}
                    #get pod eric-sec-access-mgmt-${i}
            done
            break
        fi
    fi

    sleep $TIME_TO_SLEEP
    C=$(expr $C + $TIME_TO_SLEEP)
done


