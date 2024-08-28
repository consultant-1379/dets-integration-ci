#!/bin/bash

NAMESPACE=$1
KUBE_CONFIG=$2

function check_for_installed_version()
{
    echo -e "Checking for current installed version \n"
    VALUE=$(kubectl get namespace "${NAMESPACE}" --kubeconfig "${KUBE_CONFIG}" -o jsonpath={.metadata.annotations.idunaas/installed-helmfile})

    if [ -z "${VALUE}" ] || [ "${VALUE}" == "None" ]; then
        echo -e "No value found for the installed chart version."
        exit 1
    else
        echo -e "Installed chart version found : "${VALUE}""
        echo "${VALUE}" > .bob/var.oss-version
    fi
}

check_for_installed_version