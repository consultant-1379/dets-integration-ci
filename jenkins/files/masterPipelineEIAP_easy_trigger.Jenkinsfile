#!/usr/bin/env groovy


def exec(command){
    sh command + " > .ip.tmpfile"
    def loadbalancer_ip = readFile '.ip.tmpfile'
    sh "rm -f .ip.tmpfile"
    return loadbalancer_ip.trim()
}

def getMinioBucketName(cluster_name, namespace_number){
    if(namespace_number == "0")
        return cluster_name
    else
        return cluster_name + "-x" + namespace_number
}

def getNamespaceName(cluster_name, namespace_number){
    return cluster_name + "-eric-eic-" + namespace_number
}

def getDomainName(cluster_name, namespace_number){
    def dns_suffix = ""
    if(namespace_number == "0")
        dns_suffix = cluster_name + "-eiap"
    else
        dns_suffix = cluster_name + "-x" + namespace_number
    dns_suffix = "." + dns_suffix + ".ews.gic.ericsson.se"
}

def getLoadBalancerIpAddress(domain_name){
    return exec("host endpoint${domain_name} | grep -o '[0-9][0-9]*\\.[0-9][0-9]*\\.[0-9][0-9]*\\.[0-9][0-9]*'")
}

def getDefaultOrCustomSiteValues(custom_site_values, minio_bucket, tags){
    if(custom_site_values == "NONE"){
        if(isTagEnabled(tags, 'sef'))
            return "site-values/idun/ci/template/site-values-latest.yaml"
        else
            return "com.ericsson.idunaas.ci/site-values/idun/ci/template/site-values-latest.yaml"
    } else {
        return "../cache/" + minio_bucket + "/" + custom_site_values
    }
}

def addToJson(json_value, addition){
    return exec("echo '${json_value}' | jq -r -c '. *= " + addition + "'")
}

def readFileToJson(fl_name){
    return exec("cat jenkins/scripts/pooled_eic/templates/add/"+fl_name+" | yq -o json . | jq -r -c")
}

def isTagEnabled(tags, tg_name){
    return (tags ==~ tg_name       ||
            tags ==~ tg_name+' .*' ||
            tags ==~'.* '+tg_name  ||
            tags ==~ '.* '+tg_name+' .*')
}

def addToJsonFromFile(json_value, fl_name){
    new_values = readFileToJson(fl_name)
    return addToJson(json_value, new_values)
}


def getAdditionalParameters(enable_tls, tags, enable_bdr, namespace, lightweight, enm_name){
    def add_to_site_values = '{}'

    //DETS-31662 - Add SFTP server mandatory for ADP DDC
    add_to_site_values = addToJsonFromFile(add_to_site_values, "sftp_adp_ddc.yaml")

    if("${enm_name}" != "NONE"){
        add_to_site_values = addToJsonFromFile(add_to_site_values, "adc_fns_query_v2.yaml")
        add_to_site_values = add_to_site_values.replace("ENM_NAME_REPLACE", enm_name)
        add_to_site_values = add_to_site_values.replace("NAMESPACE_REPLACE", namespace)
    }

    if("${enable_tls}" == "true")
        add_to_site_values = addToJsonFromFile(add_to_site_values, "tls.yaml")
    else
        add_to_site_values = addToJsonFromFile(add_to_site_values, "disable_tls.yaml")

    if(isTagEnabled(tags, 'sep')){
        add_to_site_values = addToJsonFromFile(add_to_site_values, "sep.yaml")
        add_to_site_values = add_to_site_values.replace("NAMESPACE", namespace)
    }

    if(isTagEnabled(tags, 'sef')){
        add_to_site_values = addToJsonFromFile(add_to_site_values, "sef.yaml")
        if (isTagEnabled(tags, 'dmm'))
            add_to_site_values = addToJsonFromFile(add_to_site_values, "sef_dmm.yaml")
    }

    if("${enable_bdr}" == "true")
        add_to_site_values = addToJsonFromFile(add_to_site_values, "bdr.yaml")

    if("${lightweight}" == "true")
        add_to_site_values = addToJsonFromFile(add_to_site_values, "lightweight-resources.yaml")

    if(add_to_site_values == '{}')
        return 'NONE'
    else
        return "'" + add_to_site_values + "'"
}

def getSlaveLabel(slave_label){
    if(slave_label == 'cENM-test')
        return slave_label
    try {
        def previous_display_name =
                    currentBuild
                        .getPreviousBuild()
                        .getDisplayName()
        echo "Previous Display Name is: ${previous_display_name}"
        def prev_slave = previous_display_name.split(" ")[-1]
        echo "Previous slave is: ${prev_slave}"
        if(prev_slave == 'cENM'){
             slave_label = 'cENM2'
        }
        if(prev_slave == 'EIAP_CICD'){
            slave_label = 'IDUN_CICD_ONE_POD_H'
        }
    }catch(Exception e) {
        echo "Warning: exception thrown while looking for the slave"
    }
    return slave_label
}

def getUseCertM(eic_version){
    // version can be in the format X.Y.Z-W (with X, Y, Z, W integer numbers)
    def (major, minor, patch) = eic_version.tokenize('.')

    // if EIC version < 2.793.0 certm=false
    if ( major.toInteger()<=2 && minor.toInteger()<793 )
        return "false"
    else
        return "true"
}

def getBuildName(deployment_name, eic_version, enable_tls, tags, slave_label, enable_bdr){
    def build_name = "${BUILD_NUMBER} ${deployment_name} ${eic_version}"
    if("${enable_tls}" == "true")
        build_name = "${build_name} TLS"
    build_name = "${build_name} ${tags}"
    if("${enable_bdr}" == "true")
        build_name = "${build_name} BDR"
    build_name = "${build_name} ${slave_label}"
    return build_name
}

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    parameters {
        string(
            name:           'CLUSTER_NAME',
            defaultValue:   'hall920',
            description:    'Cluster name'
        )
        string(
            name:           'NAMESPACE_NUMBER',
            defaultValue:   '0',
            description:    'Number of the namespace to install EIC'
        )
        string(
            name:           'TAGS',
            defaultValue:   'adc th dmm appmgr ch eas os pmh',
            description:    'List of tags for applications that have to be deployed, e.g: so adc pf'
        )
        string(
            name:           'EIC_VERSION',
            defaultValue:   '0.0.0',
            description:    'The version of base platform to install'
        )
        string(
            name:           'CUSTOM_SITE_VALUES_FILENAME',
            defaultValue:   'NONE',
            description:    'If not NONE the file will be taken from minio in ../cache/<cluster_bucket>/<CUSTOM_SITE_VALUES_FILENAME>'
        )
        booleanParam(
            name:           'ENABLE_TLS',
            defaultValue:   true,
            description:    'Enable mTLS in EIC'
        )
        booleanParam(
            name:           'GENERATE_HTTPS_CERTS',
            defaultValue:   true,
            description:    'This will genereate HTTPS certificates (self signed CA)'
        )
        string(
            name:           'TEAM_NAME',
            defaultValue:   'Muon',
            description:    'Booking team name'
        )
        booleanParam(
            name:           'ENABLE_BDR',
            defaultValue:   false,
            description:    'Enable BDR in EIC'
        )
        booleanParam(
            name:           'LIGHTWEIGHT',
            defaultValue:   false,
            description:    'Reduce the resource cpu requirements in EIC'
        )
        string(
            name:           'ENM_NAME',
            defaultValue:   'NONE',
            description:    'Inject values for FNS Queries (useful when connecting ENM or RestSim-PM). ' +
                            'This should be the same name that will be used in "Gas -> Connected Systems" ' +
                            'when finishing the configuration.'
        )
        string(
            name:           'SLAVE_LABEL',
            defaultValue:   'cENM',
            description:    'Specify the slave label that you want the job to run on (ex. IDUN_CICD_ONE_POD_H, EIAP_CICD, cENM, cENM2, cENM-test)'
        )
        string(
            name:           'GIT_BRANCH_TO_USE',
            defaultValue:   'master',
            description:    'Put refs/heads/${GIT_BRANCH_TO_USE} in the job configuration for the git branch'
        )
    }
    environment  {
        INT_CHART_VERSION = "${EIC_VERSION}"
        DEPLOYMENT_NAME   = getMinioBucketName(CLUSTER_NAME, NAMESPACE_NUMBER)
        NAMESPACE         = getNamespaceName(CLUSTER_NAME, NAMESPACE_NUMBER)
        DPL_PIPELINE_NAME = "${env.JOB_NAME.contains("EIAP_shared_MASTER_PIPELINE") ? "EIAP_shared_MASTER_PIPELINE" : "EIAP_deploy_MASTER_PIPELINE"}"
    }
    stages {
        stage ('Getting the latest EIC version'){
            when{expression {EIC_VERSION == '0.0.0'}}
            steps {
                script{
                    // withCredentials([usernameColonPassword(credentialsId: 'detsuser', variable: 'DETSUSER')]) {
                    withCredentials([usernamePassword( credentialsId: 'detsuser',
                                                       usernameVariable: 'REPO_USR',
                                                       passwordVariable: 'REPO_PSW')]) {
                        INT_CHART_VERSION = exec(
                            "bash jenkins/scripts/get_latest_eic_version.sh"      +
                                                        " --username ${REPO_USR}" +
                                                        " --password ${REPO_PSW}" )
                    }
                }
            }
        }
        stage ('RUNNING EIAP_deploy_MASTER_PIPELINE'){
            steps {
                echo "Running install job"
                script{
                    def DOMAIN          = getDomainName(CLUSTER_NAME, NAMESPACE_NUMBER)
                    def LOADBALANCER_IP = getLoadBalancerIpAddress(DOMAIN)
                    def SITE_VALUES     = getDefaultOrCustomSiteValues(CUSTOM_SITE_VALUES_FILENAME,
                                                                       DEPLOYMENT_NAME,
                                                                       TAGS)
                    def ADD_PARAMS_TO_SITE_VALUES = getAdditionalParameters(ENABLE_TLS,
                                                                            TAGS,
                                                                            ENABLE_BDR,
                                                                            NAMESPACE,
                                                                            LIGHTWEIGHT,
                                                                            ENM_NAME)
                    def SLAVE_LABEL_FOR_MASTER_PIPELINE = getSlaveLabel(SLAVE_LABEL)
                    def USE_CERTM = getUseCertM(INT_CHART_VERSION)

                    echo "DEPLOYMENT_NAME=${DEPLOYMENT_NAME}"
                    echo "NAMESPACE=${NAMESPACE}"
                    echo "DOMAIN=${DOMAIN}"
                    echo "LOADBALANCER_IP=${LOADBALANCER_IP}"
                    echo "SITE_VALUES=${SITE_VALUES}"
                    echo "ADD_PARAMS_TO_SITE_VALUES=${ADD_PARAMS_TO_SITE_VALUES}"
                    echo "INT_CHART_VERSION=${INT_CHART_VERSION}"
                    echo "SLAVE_LABEL_FOR_MASTER_PIPELINE=${SLAVE_LABEL_FOR_MASTER_PIPELINE}"
                    echo "USE_CERTM=${USE_CERTM}"
                    echo "GENERATE_CERTS=${GENERATE_HTTPS_CERTS}"

                    currentBuild.displayName = getBuildName(DEPLOYMENT_NAME, INT_CHART_VERSION, ENABLE_TLS, TAGS, SLAVE_LABEL_FOR_MASTER_PIPELINE, ENABLE_BDR)

                    build job: DPL_PIPELINE_NAME,
                                parameters: [
                                    string(name: 'DEPLOYMENT_MANAGER_DOCKER_IMAGE', value:
                                      "armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:default")
                                  , string(name: 'GIT_BRANCH_TO_USE',               value: "${GIT_BRANCH_TO_USE}"),
                                  , string(name: 'DEPLOYMENT_NAME',                 value: "${DEPLOYMENT_NAME}")
                                  , string(name: 'NAMESPACE',                       value: "${NAMESPACE}")
                                  , string(name: 'TEAM_NAME',                       value: "${TEAM_NAME}")
                                  , string(name: 'DOMAIN',                          value: "${DOMAIN}")
                                  , string(name: 'KUBECONFIG_FILE',                 value: "${CLUSTER_NAME}_kubeconfig")
                                  , string(name: 'TAGS',                            value: "${TAGS}")
                                  , string(name: 'INT_CHART_VERSION',               value: "${INT_CHART_VERSION}")
                                  , string(name: 'ADD_PARAMS_TO_SITE_VALUES',       value: "${ADD_PARAMS_TO_SITE_VALUES}")
                                  , string(name: 'INGRESS_IP',                      value: "${LOADBALANCER_IP}")
                                  , string(name: 'FH_SNMP_ALARM_IP',                value: "${LOADBALANCER_IP}")
                                  , string(name: 'HELM_TIMEOUT',                    value: "5400")
                                  , string(name: 'FULL_PATH_TO_SITE_VALUES_FILE',   value: "${SITE_VALUES}")
                                  , string(name: 'SLAVE_LABEL_FOR_MASTER_PIPELINE', value: "${SLAVE_LABEL_FOR_MASTER_PIPELINE}")
                                  , string(name: 'DOCKER_REGISTRY_CREDENTIALS',     value: "None")
                                  , string(name: 'USE_DM_PREPARE',                  value: "false")
                                  , string(name: 'USE_CERTM',                       value: "${USE_CERTM}")
                                  , string(name: 'GENERATE_CERTS',                  value: "${GENERATE_HTTPS_CERTS}")
                                  , string(name: 'DEPLOY_ALL_CRDS',                 value: "true")
                                  //, string(name: '', value: "")
                                ]
                }
            }
        }
        stage('Post-Install Reduction of Resources') {
            when {
                environment ignoreCase: true, name: 'LIGHTWEIGHT', value: 'true'
            }
            steps {
                sh 'git submodule update --init bob'

                withCredentials([file(credentialsId: "${CLUSTER_NAME}_kubeconfig", variable: 'KUBECONFIG')]) {
                    sh "install -m 600 ${KUBECONFIG} ./admin.conf"
                }
                sh "bob/bob -r jenkins/rulesets/ruleset2.0.yaml do-health-check:check-eks-connectivity"
                sh """
                   KCTL='kubectl --kubeconfig ./admin.conf --namespace ${NAMESPACE}'
                   \$KCTL get deploy -o yaml \
                   | yq '.items[].spec.template.spec.containers[].resources.requests.memory="1Mi"' \
                   | yq '.items[].spec.template.spec.containers[].resources.requests.cpu="1m" ' \
                   | \$KCTL apply -f -
                   \$KCTL get sts    -o yaml \
                   | yq '.items[].spec.template.spec.containers[].resources.requests.memory="1Mi"' \
                   | yq '.items[].spec.template.spec.containers[].resources.requests.cpu="1m" ' \
                   | \$KCTL apply -f -
                   """
            }
        }
    }
}
