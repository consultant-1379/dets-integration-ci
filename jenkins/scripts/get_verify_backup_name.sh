#!/bin/bash

HELM="/usr/local/bin/helm"
HELMFILE="/usr/local/bin/helmfile"

# Possible values for ACTION 'restore', 'rollback'
ACTION=$1
NAMESPACE=$2
KUBE_CONFIG=$3
CHART_VERSION=$4
STATE_VALUES_FILE=$5

# Variable
BACKUP_VAR_FILE=".bob/var.backup_name"
ARTIFACT_FILE="artifact.properties"
OSS_CHART="eric-oss"

#######################################################
# Get backup name and verify                          #
#                                                     #
# Arguments: None                                     #
# Returns: None                                       #
#######################################################
function check_verify_backupname()
{
    echo "Checking and verifing the backup name..."
    rm -f "${BACKUP_VAR_FILE}"

    BACKUP_NAME=$(kubectl get namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" -o jsonpath={.metadata.annotations.backupname})
    if [[ -z ${BACKUP_NAME} ]]; then
        echo "No backupname annotation found on the namespace ${NAMESPACE}"
    else
        ${HELM} list --namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" | grep eric-oss-common-base >/dev/null 2>&1
        if [[ $? -eq 0 ]];then
            INSTALLED_OSS=$(kubectl get namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" -o jsonpath={.metadata.annotations.idunaas/installed-helmfile})
        else
            INSTALLED_OSS=$(${HELM} list --filter "${OSS_CHART}-${NAMESPACE}" --namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" --output yaml | \
            grep -i chart | grep ${OSS_CHART} | sed 's/[^0-9.-]//g' | sed -r 's/-+//')
        fi
        echo "${BACKUP_NAME}" | grep "${INSTALLED_OSS}" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "${BACKUP_NAME}" > ${BACKUP_VAR_FILE}
            echo "Backup name is ${BACKUP_NAME}"
        else
            echo "Backup ${BACKUP_NAME} is not for the Installed IDUN version ${INSTALLED_OSS}"
        fi
    fi
}

function check_rollback_required()
{
    rollback_needed="false"
    echo "Checking if a rollback needs to be initiated..."
    ROLLBACK_BACKUP_NAME=$(kubectl get namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" -o jsonpath={.metadata.annotations.backupname})
    if [[ -z ${ROLLBACK_BACKUP_NAME} ]]; then
        echo "No backupname annotation found on the namespace ${NAMESPACE}"
        rollback_needed="false"
    else
        echo "${ROLLBACK_BACKUP_NAME}" | grep "${CHART_VERSION}" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            ${HELM} list --namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" | grep eric-oss-common-base >/dev/null 2>&1
            if [[ $? -eq 0 ]]; then
                check_rollback_required_helmfile
            else
                CHART_STATUS=$(${HELM} status "${OSS_CHART}-${NAMESPACE}" --namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" | \
                grep STATUS | awk '{print $2}')
                if [[ "${CHART_STATUS}" == failed ]]; then
                    rollback_needed="true"
                    echo "Helm release is in ${CHART_STATUS} state, rollback is needed"
                else
                    rollback_needed="false"
                    echo "Helm release is in ${CHART_STATUS} state, rollback not needed"
                fi
            fi
        else
            rollback_needed="false"
            echo "No backup exist for IDUN version ${CHART_VERSION}, skipping rollback"
        fi
    fi
    echo "ROLLBACK_REQUIRED=${rollback_needed}" >> ${ARTIFACT_FILE}
}

function check_rollback_required_helmfile()
{
    # Get the number of releases in the deployment for a given namespace
    printf "\nCurrent releases in namespace ${NAMESPACE}:\n"
    ${HELM} list --namespace ${NAMESPACE} --kubeconfig ${KUBE_CONFIG} --output yaml | grep 'chart\|status'
    DEPLOYED_VERSIONS=$(helm list --namespace ${NAMESPACE} --kubeconfig ${KUBE_CONFIG} --output yaml | grep -i chart)
    readarray -t DEPLOYED_VERSIONS_ARRAY <<<"$DEPLOYED_VERSIONS"
    NUMBER_OF_RELEASES="${#DEPLOYED_VERSIONS_ARRAY[@]}"

    # Get the number of successfully deployed releases
    SUCCESSFUL_RELEASES=$(helm list --namespace ${NAMESPACE} --kubeconfig ${KUBE_CONFIG} --output yaml | grep -i deployed | tr -d "[:blank:]")
    readarray -t SUCCESSFUL_RELEASES_ARRAY <<<"$SUCCESSFUL_RELEASES"
    NUMBER_OF_SUCCESSFUL_RELEASES="${#SUCCESSFUL_RELEASES_ARRAY[@]}"
    printf "\nNumber of successful releases in deployment: ${NUMBER_OF_SUCCESSFUL_RELEASES} of ${NUMBER_OF_RELEASES}\n\n"

    ### 2. Check if the number of total releases matches the number of successful releases
    if [ "${NUMBER_OF_RELEASES}" == "${NUMBER_OF_SUCCESSFUL_RELEASES}" ]; then
        rollback_needed="false"
        echo "*** Number of successful releases matches number of total releases, skipping rollback"
    else
        echo "*** Number of successful releases does not match number of total releases"
        readarray -t DEPLOYED_VERSIONS_ARRAY_SORTED < <(for a in "${DEPLOYED_VERSIONS_ARRAY[@]}"; do echo "$a" | grep -Poe "([^\.]*+\.)++\d" | sed -e 's/^[[:space:]]*//'; done | sort)

        DEPLOYED_APPLICATIONS=${DEPLOYED_VERSIONS_ARRAY_SORTED[*]}
        echo "Deployed applications:" $DEPLOYED_APPLICATIONS

        ### Check if any of the installed releases of IDUN is in failed state to do a rollback
        # Get chart names from helmfile list command, awk to pull out chart name and version
        cp ${STATE_VALUES_FILE} eric-eiae-helmfile/
        CHARTS=$(${HELMFILE} --state-values-file ${STATE_VALUES_FILE} --file eric-eiae-helmfile/helmfile.yaml list | awk '{print $1}')

        # Read output into array
        readarray -t CHARTS_ARRAY <<<"$CHARTS"
        # Remove first element which contains headings from helmfile list output
        CHARTS_ARRAY=("${CHARTS_ARRAY[@]:1}")
        printf "\n---------- Charts in helmfile ----------\n"
        printf '%s\n' "${CHARTS_ARRAY[@]}"

        printf "\n---------- Checking for failed chart ----------\n"
        for release in "${CHARTS_ARRAY[@]}"
        do
            if [[ "${DEPLOYED_VERSIONS_ARRAY_SORTED[*]}" != *"${release}"* ]]; then
                rollback_needed="false"
                echo "${release} is not deployed on system"
            else
                ${HELM} list --filter "${release}" --namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" --output yaml \
                | grep status |grep -i failed >/dev/null 2>&1
                if [[ $? -eq 0 ]]; then
                    rollback_needed="true"
                    echo "*** Chart ${release} is in failed state, rollback is needed"
                    break
                else
                    rollback_needed="false"
                fi
            fi
        done
    fi
}

if [[ ${ACTION} == rollback ]]; then
    check_rollback_required
fi

if [[ ${ACTION} == restore ]]; then
    check_verify_backupname
fi