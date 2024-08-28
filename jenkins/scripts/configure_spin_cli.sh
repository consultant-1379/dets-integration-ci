#!/bin/bash

# This script is used in a jenkins job as part of the spinnaker as code, creating/ updating pipelines.
# Takes in 2 mandatory parameters, the spinnaker username and password to use.
# These are inserted into the spin/config file that is installed on the slave.

usage () {
    echo "Usage:
        $0 [-h] [spin_username spin_password]
          Examples:
                $0 -h                           | Prints this message.
                $0 spin_username spin_password  | execute script with spinnaker username and password."
    exit -1
}

# update placeholders in spin/config file with spinnaker username and password
configure_spin_cli_config() {
    sed -i -e "s/TB_USERNAME/${SPIN_USERNAME}/g" "${HOME}"/.spin/config
    check_for_exit_code "${?}"
    sed -i -e "s/TB_PASSWORD/${SPIN_PASSWORD}/g" "${HOME}"/.spin/config
    check_for_exit_code "${?}"
}

# check exit code from configure_spin_cli_config method. If non-zero, then exit with message.
function check_for_exit_code() {
    exit_code=${1}
    if [[ ${exit_code} -ne 0 ]]; then
        echo "Error: Unable to configure the spin/config in configure_spin_cli_config.sh"
        exit -1
    fi
}

# If no paramaters specified, then print message, call usage method and exit.
if [ $# -ne 2 ]; then
    echo 1>&2 "Invalid parameters provided."; usage;
    exit -1
fi

# Entry point of script
SPIN_USERNAME="${1}"
SPIN_PASSWORD="${2}"
configure_spin_cli_config