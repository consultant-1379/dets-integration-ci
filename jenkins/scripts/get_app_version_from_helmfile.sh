#!/bin/bash

# Paths to helm and helmfile binaries in ADP-INCA container
HELMFILE="/usr/local/bin/helmfile"

STATE_VALUES_FILE=$1
PATH_TO_HELMFILE=$2
TAGS_SET_TO_TRUE_ONLY=$3

echo "STATE_VALUES_FILE:" ${STATE_VALUES_FILE}
echo "PATH_TO_HELMFILE:" ${PATH_TO_HELMFILE}

HELMFILE_LIST="${HELMFILE} --environment build --state-values-file ${STATE_VALUES_FILE} --file ${PATH_TO_HELMFILE} list"

skipListTagTrue="false|eric-crd-ns|eric-data-object-storage-mn"
skipListTagFalse="eric-data-object-storage-mn"
#Temporary fix for helmfile that don't contain csar labels
# This script will be replaced by the new get_details_from_helmfile.py
if [[ $( cat ${PATH_TO_HELMFILE} | grep labels ) ]]; then
    order="new"
else
    order="old"
fi

# Get chart names from helmfile list command, awk to pull out chart name and version
if [[ "${TAGS_SET_TO_TRUE_ONLY}" == "true" ]]; then
    # Only list the application that will be installed according to the TAGS entered
    if [[ ${order} == "old" ]]; then
        CHARTS=$(${HELMFILE_LIST} | grep -v false | awk '$5 ~ "[0-9]"' | if [[ $(wc -c) -ne 0 ]]; then ${HELMFILE_LIST} | egrep -v "${skipListTagTrue}" | awk '{print $1,$5}'; else ${HELMFILE_LIST} | egrep -v "${skipListTagTrue}" | awk '{print $1,$4}'; fi)
    else
        CHARTS=$(${HELMFILE_LIST} | grep -v false | awk '$5 ~ "[0-9]"' | if [[ $(wc -c) -ne 0 ]]; then ${HELMFILE_LIST} | egrep -v "${skipListTagTrue}" | awk '{print $1,$6}'; else ${HELMFILE_LIST} | egrep -v "${skipListTagTrue}" | awk '{print $1,$6}'; fi)
    fi
else
    # Lists all the application within the helmfile
    if [[ ${order} == "old" ]]; then
        CHARTS=$(${HELMFILE_LIST} | awk '$5 ~ "[0-9]"' | if [[ $(wc -c) -ne 0 ]]; then ${HELMFILE_LIST} | egrep -v "${skipListTagFalse}" | awk '{print $1,$5}'; else ${HELMFILE_LIST} | egrep -v "${skipListTagFalse}" | awk '{print $1,$4}'; fi)
    else
        CHARTS=$(${HELMFILE_LIST} | awk '$5 ~ "[0-9]"' | if [[ $(wc -c) -ne 0 ]]; then ${HELMFILE_LIST} | egrep -v "${skipListTagFalse}" | awk '{print $1,$6}'; else ${HELMFILE_LIST} | egrep -v "${skipListTagFalse}" | awk '{print $1,$6}'; fi)
    fi
fi

# Read output into array
readarray -t CHARTS_ARRAY <<<"$CHARTS"
# Remove first element which contains headings from helmfile list output
CHARTS_ARRAY=("${CHARTS_ARRAY[@]:1}")
printf "\n---------- Charts in helmfile ----------\n"
printf '%s\n' "${CHARTS_ARRAY[@]}"

# For each chart name, append name and version to artifact.properties file
for chart in "${CHARTS_ARRAY[@]}"
do
   IFS=' ' read -ra chart_name_version_array <<< "$chart"
   if [ "${chart_name_version_array[1]}" != "" ]
   then
       printf "Writing ${chart_name_version_array[0]}=${chart_name_version_array[1]} to artifact.properties...\n"
       printf "${chart_name_version_array[0]}=${chart_name_version_array[1]}\n" >> artifact.properties
   fi
done
