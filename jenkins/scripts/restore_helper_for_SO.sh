#!/bin/bash

### CONSTANTS ###

PAUSE_ERIC_EO_WORKFLOW='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "eric-eo-workflow",
            "command": [
              "/bin/bash",
              "-c",
              "while true;do echo \"Backup and Restore is running. Service is temporarily down.\";sleep 5s;done"
            ]
          }
        ]
      }
    }
  }
}
'

RESUME_ERIC_EO_WORKFLOW='
{
  "spec": {
    "template": {
      "spec": {
        "containers": [
          {
            "name": "eric-eo-workflow",
            "command": []
          }
        ]
      }
    }
  }
}
'


### FUNCTIONS ###

function extract_parameters_and_define_global_variables {

    while [ $# -gt 0 ]; do
        case "$1" in
            "--exec-hook")
                shift
                EXEC_HOOK="$1"
            ;;
            "--namespace")
                shift
                NAMESPACE="$1"
            ;;
            "--kubeconfig")
                shift
                KUBECONFIG="$1"
            ;;
            *)
                log "ERROR: Bad command line argument: '$1'"
                log "Usage: $0 --exec-hook <pre|post> --namespace <namespace_name> [--kubeconfig <kubeconfig_file>]"
                exit -1
            ;;
        esac
        shift
    done


    test "$EXEC_HOOK" != "pre" -a "$EXEC_HOOK" != "post" \
        && log "Error: EXEC_HOOK='$EXEC_HOOK'" \
        && exit -2

    test -z "$NAMESPACE" \
        && log "Error: NAMESPACE='$NAMESPACE'" \
        && exit -3

    test -n "$KUBECONFIG" \
        && KUBECONFIG_OPTION="--kubeconfig $KUBECONFIG"

    KUBECTL="kubectl --namespace $NAMESPACE $KUBECONFIG_OPTION"
}

function log {
    echo "$(date) | $(basename $0) | $1"
}

function check_eric_eo_workflow_deployed {
    IS_WRKFL_DEPLOYED=$($KUBECTL \
            get deployment -o json \
                | jq -r -c '.items[] | select(.metadata.name=="eric-eo-workflow")' \
                | wc -l)

    IS_WRKFL_DB_DEPLOYED=$($KUBECTL \
            get StatefulSet -o json \
                | jq -r -c '.items[] | select(.metadata.name=="eric-eo-workflow-database-pg")' \
                | wc -l)
    test $IS_WRKFL_DEPLOYED -eq 0 -a $IS_WRKFL_DB_DEPLOYED -eq 0 \
        && log "Info: Deployment 'eric-eo-workflow' and statefulset 'eric-eo-workflow-database-pg' are not deployed on this cluster.
Nothing to do" \
        && exit 0

    test $(expr $IS_WRKFL_DEPLOYED + $IS_WRKFL_DB_DEPLOYED) -eq 1 \
        && log "Error: only 'eric-eo-workflow' or 'eric-eo-workflow-database-pg' are deployed" \
        && exit -4

}

function check_readiness {
    local POD_NAME=$1
    local POD_STAUS=$2
    $KUBECTL \
        get pods -o json \
        | jq -r -c "
            .items[].status.containerStatuses[]
                | select( .name==\"$POD_NAME\")
                | select( .ready == $POD_STAUS)" \
        | wc -l
}

function wait_for_state {
    local SERVICE_NAME="$1"
    local STATUS="$2"
    local EXPECTED_VALUE="$3"

    local C=0
    local TIMEOUT_SECONDS=300
    while [ $(check_readiness $SERVICE_NAME $STATUS) -ne $EXPECTED_VALUE -a $C -lt $TIMEOUT_SECONDS ]; do
        log "Waiting for $SERVICE_NAME to be in state ready=$STATUS"
        log "($C seconds elapsed before timeout at $TIMEOUT_SECONDS seconds)"
        sleep 5
        C=$(expr $C + 5)
    done

    test $C -ge $TIMEOUT_SECONDS \
        && log "Warning waiting loop timed out after $TIMEOUT_SECONDS seconds"
}

function wait_for_paused_state {
    local SERVICE_NAME="$1"
    local EXPECTED_VALUE="$2"
    wait_for_state $SERVICE_NAME false $EXPECTED_VALUE
}
function wait_for_ready_state {
    local SERVICE_NAME="$1"
    local EXPECTED_VALUE="$2"
    wait_for_state $SERVICE_NAME true $EXPECTED_VALUE
}


### MAIN SCRIPT ###

extract_parameters_and_define_global_variables $@

log "Global variables and parameters:"
echo "
  EXEC_HOOK=$EXEC_HOOK
  NAMESPACE=$NAMESPACE
  KUBECONFIG=$KUBECONFIG
  KUBECTL=$KUBECTL
"

log "Test if eric-eo-workflow and eric-eo-workflow-database-pg are deployed"
check_eric_eo_workflow_deployed

if [ "$EXEC_HOOK" == "pre" ]; then
    test $(check_readiness eric-eo-workflow true) -ne 1 \
        && log "Error - the status of the pod eric-eo-workflow is not in 'ready' state" \
        && exit -5

    test $(check_readiness eric-eo-workflow-bro-agent-filemount true) -ne 1 \
        && log "Error - the status of the pod eric-eo-workflow-bro-agent-filemount is not in 'ready' state" \
        && exit -6

    test $(check_readiness eric-eo-workflow-database-pg true) -ne 2 \
        && log "Error - the status of the pod eric-eo-workflow-database-pg is not in 'ready' state" \
        && exit -7

    log "Pause eric-eo-workflow"
    $KUBECTL patch deployment eric-eo-workflow \
        -p "$PAUSE_ERIC_EO_WORKFLOW"

    wait_for_paused_state eric-eo-workflow 1
    wait_for_ready_state  eric-eo-workflow-bro-agent-filemount 1
    wait_for_ready_state  eric-eo-workflow-database-pg 2

    log "Pre hook execution finished"

elif [ "$EXEC_HOOK" == "post" ]; then

    log "Restart eric-eo-workflow-database-pg-{0,1}"
    $KUBECTL delete pod eric-eo-workflow-database-pg-0
    $KUBECTL delete pod eric-eo-workflow-database-pg-1

    log "Sleeping 5 seconds to allow pods to be destroyed and recreated"
    sleep 5

    wait_for_ready_state eric-eo-workflow-database-pg 2

    log "Resume eric-eo-workflow from paused state"
    $KUBECTL patch deployment eric-eo-workflow \
        -p "$RESUME_ERIC_EO_WORKFLOW"

    wait_for_ready_state eric-eo-workflow 1
    wait_for_ready_state eric-eo-workflow-bro-agent-filemount 1

    log "Post hook execution finished"
else
    log "Error - unexpected value: EXEC_HOOK=$EXEC_HOOK"
    exit -8
fi

exit 0
