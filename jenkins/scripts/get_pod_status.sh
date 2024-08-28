#!/bin/bash

# Standard Usage function to display example of our to run script
function usage {
    echo "Usage:
        $(basename $0) [-h] [--pod-name --namespace --kubeconfig]
          Examples:
                $(basename $0) -h                                                                                   | Prints this message.
                $(basename $0) --pod-name <pod_name> --namespace <namespace_name> --kubeconfig <kubeconfig_file>    | Retrieve status of pod for this environment in this namespace."
    exit -1
}

# Simple log function
function log {
    echo "$(date) | $(basename $0) | $1"
}

# Function to extract parameters, check validity and display usage if in-valid parameters found
function extract_parameters_and_define_global_variables {

    while [ $# -gt 0 ]; do
        case "$1" in
            "--kubeconfig")
                shift
                KUBECONFIG="$1"
            ;;
            "--namespace")
                shift
                NAMESPACE="$1"
            ;;
            "--podname")
                shift
                PODNAME="$1"
            ;;
            *)
                usage;
            ;;
        esac
        shift
    done

    test -z "$PODNAME" \
        && log "Error: PODNAME='$PODNAME'" \
        && exit -1

    test -z "$NAMESPACE" \
        && log "Error: NAMESPACE='$NAMESPACE'" \
        && exit -1

    test -n "$KUBECONFIG" \
        && KUBECONFIG_OPTION="--kubeconfig $KUBECONFIG"

    KUBECTL="kubectl --namespace $NAMESPACE $KUBECONFIG_OPTION"
}

# Function that checks if the pod is in a ready state
function check_readiness {
    local JSON_PATH_READY_STATE="{..status.conditions[?(@.type=='Ready')].status}"
    $KUBECTL get pods "$PODNAME" -o jsonpath="$JSON_PATH_READY_STATE"
}

## Main script entry
extract_parameters_and_define_global_variables $@

echo "
  PODNAME=$PODNAME
  NAMESPACE=$NAMESPACE
  KUBECONFIG=$KUBECONFIG
  KUBECTL=$KUBECTL
"
# Inifinite while loop to check readiness of pod.
while [[ $(check_readiness) != "True" ]]; do
    log "Waiting for $PODNAME to be in ready state"
    sleep 10
done

exit 0
