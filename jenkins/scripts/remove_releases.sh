#!/bin/bash
HELM="/usr/local/bin/helm"
HELMFILE="/usr/local/bin/helmfile"

NAMESPACE=$1
KUBE_CONFIG=$2
STATE_VALUES_FILE=$3

echo "NAMESPACE:" ${NAMESPACE}
echo "KUBE_CONFIG:" ${KUBE_CONFIG}
echo "Checking for Release using command: ${HELM} ls --all --short --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE}"
${HELM} ls --all --short --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE}

echo "Checking for all Releases that are installed under the EIAP Helmfile using command: "
echo "${HELMFILE} --state-values-file ${PWD}/${STATE_VALUES_FILE} --file eric-eiae-helmfile/helmfile.yaml list | awk '{print $1}' | tail -n+2"

${HELMFILE} --state-values-file ${PWD}/${STATE_VALUES_FILE} --file eric-eiae-helmfile/helmfile.yaml list | awk '{print $1}' | tail -n+2

eiapHelmChartList=$(${HELMFILE} --state-values-file ${PWD}/${STATE_VALUES_FILE} --file eric-eiae-helmfile/helmfile.yaml list | awk '{print $1}' | tail -n+2)

readarray -t CHARTS_ARRAY <<<"${eiapHelmChartList}"

helmReleaseList=$( ${HELM} ls --all --short --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE} )

for release in ${helmReleaseList}
do
  if [[ "${CHARTS_ARRAY[*]}" =~ ${release} ]]; then
    echo "Deleting Release ${release}"
    echo "Executing :: helm delete ${release} --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE} --no-hooks"
    ${HELM} delete ${release} --kubeconfig ${KUBE_CONFIG} --namespace ${NAMESPACE} --no-hooks;
  else
    echo "${release} is not part of EIAP Helmfile, so skipping its delete"
  fi
done
