#!/bin/bash
HELM="/usr/local/bin/helm"
HELMFILE="/usr/local/bin/helmfile"

NAMESPACE=$1
KUBE_CONFIG=$2

echo "NAMESPACE:" ${NAMESPACE}
echo "KUBE_CONFIG:" ${KUBE_CONFIG}
echo "Checking for Release using command: ${HELM} ls --all --short --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE}"
${HELM} ls --all --short --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE}

echo "Checking for for installed releases:"
helmReleaseList=$( ${HELM} ls --all --short --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE} )
echo "${helmReleaseList}"

for release in ${helmReleaseList}
do
    echo "Deleting Release ${release}"
    echo "Executing :: helm delete ${release} --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE} --no-hooks"
    ${HELM} delete ${release} --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE} --no-hooks;
done
