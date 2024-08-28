#!/bin/bash

# Team Muon (IDUNaaS)
# This helper script is triggered by a cron job which runs the health checks on the deployments
# PLEASE NOTE! This script should only be run from the atvts9061 host due to issues with sending email from the new Jenkins slave
# This script is schedued for deprecation in future once a comprehensive Prometheus + Grafana monitoring solution is in place for IDUNaaS

DEPLOYMENT=${1}
NAMESPACE=${2}  
PF_USER=${3}
PF_PASS=${4}

PATH=/usr/local/bin:/usr/local/sbin:/usr/sbin:/usr/bin:/bin

WORKDIR="/home/bucinwci/idunaas/healthcheck" # health_check.py and health_check_cron.sh should be located here.
                                             # ci and logs folders will be created in this folder if not already present

if [ -z ${NAMESPACE} ]; then NAMESPACE=oss; fi
if [ -z ${PF_USER} ]; then PF_USER=pf-user; fi
if [ -z ${PF_PASS} ]; then PF_PASS=Ericsson; fi

exec >> ${WORKDIR}/logs/health_check_cron_${DEPLOYMENT}_ns_${NAMESPACE}.log
cd ${WORKDIR}

echo "- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -"
echo "health_check_cron.sh execution started at $(date -u)"

case ${DEPLOYMENT} in
    bnewidun01   ) ;;
    bnewidun02   ) ;;
    idunaasdev01 ) ;;
    openlab01    ) ;;
    ossautoapp01 ) ;;
    *            ) echo; echo "An invalid deployment name was provided. Please check and try again."; exit -1; ;;
esac

if [ -d ci ]; then
    cd ci
    ret=$(git status > /dev/null 2>&1; echo $?)
    if [ ! ${ret} = 0 ]; then
        cd ..; rm -rf ci; git clone https://zapsauc@gerrit.ericsson.se/a/ENMaaS/com.ericsson.idunaas.ci.git ci
    else 
        git pull; cd ..
    fi
else
    git clone https://zapsauc@gerrit.ericsson.se/a/ENMaaS/com.ericsson.idunaas.ci.git ci
fi

KUBECONFIG="$(pwd)/ci/deployments/${DEPLOYMENT}/workdir/kube_config/config"
CFG_PATH="$(pwd)/ci/deployments/${DEPLOYMENT}/workdir/config.yaml"
PF_URL=$(/usr/local/bin/yq eval .Hostnames.pf ${CFG_PATH})

echo; echo "Switching to ${DEPLOYMENT} AWS account credentials"
sudo cp $(pwd)/ci/deployments/${DEPLOYMENT}/aws/config /workdir/aws/config
sudo cp $(pwd)/ci/deployments/${DEPLOYMENT}/aws/credentials /workdir/aws/credentials
echo; echo "Contents of /workdir/aws/config: $(echo; cat /workdir/aws/config)"
echo; echo "Contents of /workdir/aws/credentials: $(echo; cat /workdir/aws/credentials)"
export AWS_CONFIG_FILE=/workdir/aws/config;
export AWS_SHARED_CREDENTIALS_FILE=/workdir/aws/credentials;
echo; echo "Output of aws sts get-caller-identity after switching to ${DEPLOYMENT} credentials:"
echo "$(aws sts get-caller-identity)"

echo; echo "Calling health_check.py with following args:"
echo "--name ${DEPLOYMENT}"
echo "--namespace ${NAMESPACE}"
echo "--pf_user ${PF_USER}"
echo "--pf_pass ${PF_PASS}"
echo "--url ${PF_URL}"
echo "--kubeconfig ${KUBECONFIG}"

python3 health_check.py --kubeconfig ${KUBECONFIG} \
                        --url ${PF_URL} \
                        --pf_user ${PF_USER} \
                        --pf_pass ${PF_PASS} \
                        --namespace ${NAMESPACE} \
                        --name ${DEPLOYMENT} > /dev/null 2>&1
if [ ${?} = 0 ]; then 
    echo "health_check.py exited with status code 0"
else
    echo "health_check.py exited with non-zero status"
fi

echo; echo "health_check_cron.sh execution finished at $(date -u)"
