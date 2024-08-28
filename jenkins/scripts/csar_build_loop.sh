#!/bin/bash

CSAR_BUILDER_IMAGE=$1
HELM_CHART_DIR=$2
CRDS_CHART_DIR=$3

for chart in $HELM_CHART_DIR/*; do
    echo ${chart}
    chartname=$( basename ${chart} )
    csarname=$( basename ${chart} ".tgz" )
    echo ${chartname}
    if [[ ${chartname} == *"eric-tm-ingress-controller-cr-crd"* ]]; then
      echo "Skipping csar build for ${chartname}"
      continue
    fi
    if [[ ${chartname} == *"eric-cloud-native-base"* && -d ${CRDS_CHART_DIR} && "$( ls -A ${CRDS_CHART_DIR} )" ]]; then
        chart_full_path="${HELM_CHART_DIR}/${chartname}"
        for crdChart in ${CRDS_CHART_DIR}/*; do
            crd_chart_name=$( basename ${crdChart} )
            chart_full_path+=" ${CRDS_CHART_DIR}/${crd_chart_name}"
        done
    else
        chart_full_path="$HELM_CHART_DIR/${chartname}"
    fi
    echo ${chart_full_path}

    printf "\n---------- Building Mini CSAR $csarname for $chartname ----------\n"
    docker run --rm --volume $(pwd):$(pwd) -w $(pwd) ${CSAR_BUILDER_IMAGE} generate --helm ${chart_full_path} --name $csarname --no-images
done
