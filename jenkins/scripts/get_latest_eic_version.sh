#!/bin/bash


# extract parameters:
while [ $# -gt 0 ]; do
    case "$1" in
        "--username")
            shift
            REPO_USERNAME="$1"
        ;;
        "--password")
            shift
            REPO_PASSWORD="$1"
        ;;
        *)
            echo "[$(basename $0)] ERROR: Bad command line argument: '$1'"
            echo "$0 --username <repo_username> --password <repo_password>"
            exit -1
        ;;
    esac
    shift
done

curl -s -u ${REPO_USERNAME}:${REPO_PASSWORD} https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-drop-helm/eric-eiae-helmfile/ | expand | tr -s ' ' > .eic_versions.txt

#date -d yesterday +%d-%b-%Y
#date -d today-1day
#DT=$(date -d today +%d-%b-%Y)
#MOST_RECENT_RELEASE_HOUR=$(cat eic_versions.txt | grep -F $DT | cut -d ' ' -f 4 | sort | tail -n 1)

C=0
while [ -z "$MOST_RECENT_RELEASE_HOUR" -a $C -le 5 ]; do
    DT=$(date -d today-${C}day +%d-%b-%Y)
    MOST_RECENT_RELEASE_HOUR=$(cat .eic_versions.txt | grep -F $DT | cut -d ' ' -f 4 | sort | tail -n 1)
    C=$(expr $C + 1)
done

grep "$DT $MOST_RECENT_RELEASE_HOUR" .eic_versions.txt | grep -o 'href="eric-eiae-helmfile-.*.tgz"' | sed -E 's/href="eric-eiae-helmfile-(.*).tgz"/\1/'

rm -f .eic_versions.txt
