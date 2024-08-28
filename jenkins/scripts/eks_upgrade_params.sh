#!/bin/bash

# This script is only used for eks_upgrade pipelines to replace values in config.yaml.

usage () {
    echo "Usage:
        $0 [-h] [deployments key value]
          Examples:
                $0 -h                           | Prints this message.
                $0 deployments key value        | Replace value in config.yaml."
    exit 2
}


# Update value of key in deployment config

update_config()  {

    echo "Updating ${KEY}"
    sed  -i -e "s/${KEY}.*/${KEY}: ${VALUE}/" ${CONFIG}
}


# If no paramaters specified, then print message, call usage method and exit.
if [ $# -ne 3 ]; then
    echo 1>&2 "Invalid parameters provided."; usage;
    exit 2
fi


# Entrypoint of script

DEPLOYMENT=$1
KEY=$2
VALUE=$3
CONFIG="ci/deployments/${DEPLOYMENT}/workdir/config.yaml"

update_config
