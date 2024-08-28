#!/bin/bash

function usage {
    echo "[$(basename $0)] Usage:
    $0 --path-to-site-values-override-file <path> [--path-to-common-site-values-file <path>] --path-to-output-site-values-file <path>

    --path-to-site-values-override-file <path>
        Path to site-values-override.yaml. There is
        one file for each environment and it contains
        values to be added or replaced in the common
        site-values-latest.yaml. This file can be missing
        if no values needs to be added or updated.

    --path-to-common-site-values-file <path>
        Path to site-values-latest.yaml reachable from
        the git submodule. Tha path is relative to the
        root of this repository (com.ericsson.idunaas.ci).
        If this parameter is missing it will be derived
        from the path of site-values-override.yaml.

    --path-to-output-site-values-file <path>
        Path to the site_values.yaml to be created.
        This file is equal to site-values-latest.yaml if there
        is no site-values-override.yaml. Otherwise it will
        be a version of site-values-latest.yaml updated
        by the values in site-values-override.yaml.
    "
}

function is_pyyaml_available {
    python3 -B  <<"EOF" &>/dev/null
try:
    import yaml
except ImportError:
    exit(-1)
exit(0)
EOF
    echo $?
}

# extract parameters:
while [ $# -gt 0 ]; do
    case "$1" in
        "--path-to-common-site-values-file")
            shift
            PATH_TO_COMMON_SITE_VALUES_FILE="$1"
        ;;
        "--path-to-site-values-override-file")
            shift
            PATH_TO_SITE_VALUES_OVERRIDE_FILE="$1"
        ;;
        "--path-to-output-site-values-file")
            shift
            PATH_TO_OUTPUT_SITE_VALUES_FILE="$1"
        ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            usage
            exit -1
        ;;
    esac
    shift
done

echo "[$(basename $0)] Parameters from the command line:
    PATH_TO_SITE_VALUES_OVERRIDE_FILE=$PATH_TO_SITE_VALUES_OVERRIDE_FILE
    PATH_TO_COMMON_SITE_VALUES_FILE=$PATH_TO_COMMON_SITE_VALUES_FILE
    PATH_TO_OUTPUT_SITE_VALUES_FILE=$PATH_TO_OUTPUT_SITE_VALUES_FILE
"

test -z "$PATH_TO_OUTPUT_SITE_VALUES_FILE" \
    && echo "[$(basename $0)] ERROR: --path-to-output-site-values-file not found in command line arguments" \
    && usage \
    && exit -2

test -z "$PATH_TO_SITE_VALUES_OVERRIDE_FILE" \
    && echo "[$(basename $0)] ERROR: --path-to-site-values-override-file not found in command line arguments" \
    && usage \
    && exit -3

if [ -z "$PATH_TO_COMMON_SITE_VALUES_FILE" ]; then
    # example of site-values-override path: ~/com.ericsson.idunaas.ci/deployments/bmasidun01/workdir/site-values-override.yaml
    P="$PATH_TO_SITE_VALUES_OVERRIDE_FILE"
    P=$(dirname $P) # remove 'site-values-override.yaml'
    P=$(realpath "$P" 2>/dev/null)
    test -z "$P" \
        && echo "ERROR: site-values-override.yaml can be missing but its folder should exist."
    P=$(dirname $P) # remove 'workdir'
    P=$(dirname $P) # remove '<env_name>'
    P=$(dirname $P) # remove 'deployments'
    PATH_TO_COMMON_SITE_VALUES_FILE="$P/oss-integration-ci/site-values/ci/site-values-latest.yaml"
fi

echo "[$(basename $0)] Parameters after further processing:
    PATH_TO_SITE_VALUES_OVERRIDE_FILE=$PATH_TO_SITE_VALUES_OVERRIDE_FILE
    PATH_TO_COMMON_SITE_VALUES_FILE=$PATH_TO_COMMON_SITE_VALUES_FILE
    PATH_TO_OUTPUT_SITE_VALUES_FILE=$PATH_TO_OUTPUT_SITE_VALUES_FILE
"

test ! -e "$PATH_TO_COMMON_SITE_VALUES_FILE" \
    && echo "[$(basename $0)] ERROR: $PATH_TO_COMMON_SITE_VALUES_FILE not found on filesystem" \
    && exit -4

if [ ! -e  "$PATH_TO_SITE_VALUES_OVERRIDE_FILE" ]; then
    echo "[$(basename $0)] INFO: $PATH_TO_SITE_VALUES_OVERRIDE_FILE does not exist on filesystem,"
    echo "thus there is nothing to override and $PATH_TO_OUTPUT_SITE_VALUES_FILE will be equal to $PATH_TO_COMMON_SITE_VALUES_FILE"
    cp $PATH_TO_COMMON_SITE_VALUES_FILE $PATH_TO_OUTPUT_SITE_VALUES_FILE
    exit 0
else
    # check library
    IS_PYYAML_AVAILABLE=$(is_pyyaml_available)
    OK=0
    if [ "$IS_PYYAML_AVAILABLE" != "$OK" ]; then
        test ! -e /tmp/.idunaas.tmp.pylibs \
            && echo "[$(basename $0)] PyYaml not found. Installing in /tmp/.idunaas.tmp.pylibs" \
            && mkdir /tmp/.idunaas.tmp.pylibs \
            && pip3 install --target /tmp/.idunaas.tmp.pylibs "pyyaml==6.0"
        export PYTHONPATH="$PYTHONPATH:/tmp/.idunaas.tmp.pylibs"
    fi

    # run the script
    
	which python > /dev/null && \
	  PYTHON=python
	which python3 > /dev/null && \
	  PYTHON=python3
	which python3.9 > /dev/null && \
	  PYTHON=python3.9
	
	test -z "$PYTHON" && \
		echo "Error: python not found." && \
		exit -3
	
    THIS_SCRIPT_FOLDER="$(dirname $(realpath $0))"
    $PYTHON "$THIS_SCRIPT_FOLDER"/ymerge.py $PATH_TO_COMMON_SITE_VALUES_FILE $PATH_TO_SITE_VALUES_OVERRIDE_FILE $PATH_TO_OUTPUT_SITE_VALUES_FILE 2>&1
fi
