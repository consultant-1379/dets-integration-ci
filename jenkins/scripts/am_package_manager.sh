#!/bin/bash

# This script is only used in conjunction with the get-release-details-from-helmfile script.
# When the paramater "--fetch-charts true" is set within the get-release-details-from-helmfile script it generates a file, am_package_manager.properties, and downloads the charts.
# When this script executes it expects to have that file passed to it and the charts already downloaded.
# This script is only used to build the CSAR's

HELM="/usr/local/bin/helm"
HELMFILE="/usr/local/bin/helmfile"

CSAR_HELM_CHART_MAPPING=$1
CSAR_BUILDER_IMAGE=$2
INCLUDE_IMAGES=$3

for item in $( cat ${CSAR_HELM_CHART_MAPPING} ); do
    csar_name_version=$( echo ${item} | sed 's/=/ /' | awk '{print $1}' )
    csar_content=$( echo ${item} | sed 's/=/ /' | awk '{print $2}' | sed 's/,/ /g' )
    printf "\n---------- Building Mini CSAR $csar_name_version ----------\n"
    if [[ ${INCLUDE_IMAGES} == 'true' ]]; then
        printf "docker run --rm --volume $(pwd):$(pwd) -w $(pwd) ${CSAR_BUILDER_IMAGE} generate --name ${csar_name_version} --helm ${csar_content}\n"
        docker run --rm --volume $(pwd):$(pwd) -w $(pwd) ${CSAR_BUILDER_IMAGE} generate --name ${csar_name_version} --helm ${csar_content}
    else
        printf "docker run --rm --volume $(pwd):$(pwd) -w $(pwd) ${CSAR_BUILDER_IMAGE} generate --name ${csar_name_version} --helm ${csar_content} --no-images\n"
        docker run --rm --volume $(pwd):$(pwd) -w $(pwd) ${CSAR_BUILDER_IMAGE} generate --name ${csar_name_version} --helm ${csar_content} --no-images
    fi
    rm ${csar_content}
done
