#!/bin/bash

# Paths to helm and helmfile binaries in ADP-INCA container
HELMFILE="/usr/local/bin/helmfile"
HELM="/usr/local/bin/helm"

STATE_VALUES_FILE=$1
HELMFILE_FULL_PATH=eric-eiae-helmfile/helmfile.yaml
CRD_HELMFILE_FULL_PATH=eric-eiae-helmfile/crds-helmfile.yaml

echo "STATE_VALUES_FILE:" ${STATE_VALUES_FILE}

function pullIntegrationChart {
    # Function to pull the integration chart that are listed in an array
    ARRAY=("$@")
    ((last_idx=${#ARRAY[@]} - 1))
    TMPDIRECTORY=${ARRAY[last_idx]}
    unset ARRAY[last_idx]

    if [ -d ${TMPDIRECTORY} ]; then
        rm -rf ${TMPDIRECTORY}
    fi
    mkdir ${TMPDIRECTORY}
    # For each chart name, pull chart from repo into tmp_pulled_charts
    for chart in "${ARRAY[@]}"; do
       if [[ ${chart} != "" ]]; then
           IFS=' ' read -ra chart_name_version_array <<< "$chart"
           printf "\nPulling chart ${chart_name_version_array[0]}:${chart_name_version_array[1]}\n"
           ${HELM} pull ${chart_name_version_array[0]} --version ${chart_name_version_array[1]}
           CHARTNAME=$(cut -d '/' -f2 <<< "${chart_name_version_array[0]}")
           echo "Moving ${CHARTNAME}-${chart_name_version_array[1]}.tgz to ${TMPDIRECTORY}/"
           mv "${CHARTNAME}-${chart_name_version_array[1]}.tgz" "${TMPDIRECTORY}"
       fi
    done
}


# Get chart names from helmfile list command, awk to pull out chart name and version
if [ -f ${HELMFILE_FULL_PATH} ]; then
    CHARTS=$(${HELMFILE} --state-values-file ${STATE_VALUES_FILE} --file ${HELMFILE_FULL_PATH} list | grep -v "eric-crd-ns" | awk '{if ($3 == "true") {print $4,$5}}')
fi
# Read output into array
readarray -t CHARTS_ARRAY <<<"$CHARTS"

# Get CRD chart names from helmfile, awk to pull out chart name and version
if [ -f ${CRD_HELMFILE_FULL_PATH} ]; then
    CRD_CHARTS=$(${HELMFILE} --state-values-file ${STATE_VALUES_FILE} --file ${HELMFILE_FULL_PATH} list | grep "eric-crd-ns" | awk '{print $4,$5}')
    readarray -t CRD_CHARTS_ARRAY <<<"$CRD_CHARTS"
    # Remove the entries from the helmfile charts array if already existing in the crd array
    for chart in "${CRD_CHARTS_ARRAY[@]}"; do
        CHARTS_ARRAY=( "${CHARTS_ARRAY[@]/$chart}" )
    done
fi

printf "\n---------- Charts in helmfile ----------\n"
printf '%s\n' "${CHARTS_ARRAY[@]}"
if (( ${#CRD_CHARTS_ARRAY[@]} )); then
    printf "\n---------- CRD Charts in crds_helmfile ----------\n"
    printf '%s\n' "${CRD_CHARTS_ARRAY[@]}"
fi
printf "\n---------- Adding chart repos from repositories.yaml ----------\n"

# Load the repos so the charts can be pulled
${HELMFILE} --state-values-file ${STATE_VALUES_FILE} --file ${HELMFILE_FULL_PATH} repos

printf "\n---------- Pulling charts from chart repos ----------\n"
pullIntegrationChart "${CHARTS_ARRAY[@]}" "tmp_pulled_charts"

if (( ${#CRD_CHARTS_ARRAY[@]} )); then
    printf "\n---------- Pulling CRD charts from chart repos ----------\n"
    pullIntegrationChart "${CRD_CHARTS_ARRAY[@]}" "tmp_crds_pulled_charts"
fi
