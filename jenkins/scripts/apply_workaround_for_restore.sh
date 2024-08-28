#!/bin/bash

## Original issue
# https://jira-oss.seli.wh.rnd.internal.ericsson.com/browse/IDUN-33310
## Permanent fix
# https://eteamproject.internal.ericsson.com/browse/ADPPRG-77657
## Documentation on this workaround
# https://adp.ericsson.se/marketplace/identity-and-access-management/documentation/12.3.0/dpi/service-user-guide#backup-and-restore
## Description of the workaround
# Need a way to asyncronously monitor the logging file and restart the pod of IAM


function usage {
    echo "Usage: $0 --namespace <k8s namespace> --path-to-kubeconfig-file <path to the kube config file>"
    echo "Example: $0 --namespace ossdev02 --path-to-kubeconfig-file deployments/idunaasdev02/workdir/kube_config/config"
}


# extract parameters:
while [ $# -gt 0 ]; do
    case "$1" in
        "--path-to-kubeconfig-file")
            shift
            PATH_TO_KUBECONFIG_FILE="$1"
        ;;
        "--namespace")
            shift
            NAMESPACE="$1"
        ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            usage
            exit -1
        ;;
    esac
    shift
done

if [ -z "$PATH_TO_KUBECONFIG_FILE" -o -z "$NAMESPACE" ]; then
    echo "[$(basename $0)] ERROR: empty parameter NAMESPACE=$NAMESPACE PATH_TO_KUBECONFIG_FILE=$PATH_TO_KUBECONFIG_FILE"
    usage
    exit -2
fi

SCRIPT_FULL_PATH=$(realpath $0)
SCRIPT_DIR=$(dirname $SCRIPT_FULL_PATH)
echo "Script directory: $SCRIPT_DIR"
echo "Logging file: $SCRIPT_DIR/monitor_restore_and_clean_IAM_cache.log"


test ! -f $SCRIPT_DIR/monitor_restore_and_clean_IAM_cache.sh \
    && echo "[$(basename $0)] ERROR: $SCRIPT_DIR/monitor_restore_and_clean_IAM_cache.sh not found" \
    && exit -3

ENV_NAME=$(echo $PATH_TO_KUBECONFIG_FILE | grep -o 'deployments/[^/]*' |  cut -d / -f 2)
echo "ENV_NAME=$ENV_NAME (derived from PATH_TO_KUBECONFIG_FILE=$PATH_TO_KUBECONFIG_FILE)"
nohup bash $SCRIPT_DIR/monitor_restore_and_clean_IAM_cache.sh \
    --namespace "$NAMESPACE" \
    --env-name  "$ENV_NAME"  \
    &> $SCRIPT_DIR/monitor_restore_and_clean_IAM_cache.log &

exit 0
