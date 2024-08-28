#!/bin/bash

TMPDIR=.create_optionality_yaml.tmp
SCRIPT_DIR=$(dirname $(realpath $0))

which python > /dev/null && \
  PYTHON=python
which python3 > /dev/null && \
  PYTHON=python3
which python3.9 > /dev/null && \
  PYTHON=python3.9

test -z "$PYTHON" && \
	echo "Error: python not found." && \
	exit -3

# CSAR_DIR=/home/lciadm100/jenkins/fem2s11/workspace/idunaas_push_image_ecr_europe

function usage {
    echo "[$(basename $0)] Usage:
    $0 --csar-directory <path>

    --csar-directory:
        Path to the folder that contains the CSAR archive

    "
}

# extract parameters:
while [ $# -gt 0 ]; do
    case "$1" in
        "--csar-directory")
            shift
            CSAR_DIR="$1"
        ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            usage
            exit -1
        ;;
    esac
    shift
done


test -z "$SCRIPT_DIR" \
    && echo "Error: variable SCRIPT_DIR is empty" \
    && exit -1

test -z "$TMPDIR" \
    && echo "Error: variable TMPDIR is empty" \
    && exit -1

test -z "$CSAR_DIR" \
    && echo "Error: variable CSAR_DIR is empty" \
    && usage \
    && exit -1

test ! -d "$CSAR_DIR" \
    && echo "Error: variable CSAR_DIR='$CSAR_DIR' is not a directory" \
    && usage \
    && exit -1

CSAR_DIR=$(realpath $CSAR_DIR)
cd $CSAR_DIR

test -e $TMPDIR && rm -rf $TMPDIR
mkdir $TMPDIR
pushd $TMPDIR
for i in `find $CSAR_DIR/*.csar`; do
    BASENAME=`basename ${i:0:-5}` # removing the extension from filename (last 4 characters)
    echo "==> $BASENAME"
    mkdir $BASENAME
    pushd $BASENAME
    unzip $i
    cat Definitions/OtherTemplates/*.tgz | tar xvz
    popd
done
popd

LIST_OF_OPTIONALITY=$(find $TMPDIR -name optionality.yaml)
$PYTHON $SCRIPT_DIR/merge_optionality.py \
    eric-eiae-helmfile/optionality.yaml \
    $LIST_OF_OPTIONALITY
RC=$?

rm -rf $TMPDIR

test $RC -ne 0 \
    && echo "Error: merge_optionality.py returned $RC (not zero)" \
    && exit $RC

mv optionality.yaml eric-eiae-helmfile/optionality.yaml

exit 0
