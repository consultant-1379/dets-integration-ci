#!/usr/bin/env groovy

/* IMPORTANT:
 *
 * In order to make this pipeline work, the following configuration on Jenkins is required:
 * - slave with a specific label (see pipeline.agent.label below)
 * - Credentials Plugin should be installed and have the secrets with the following names:
 *   + c12a011-config-file (admin.config to access c12a011 cluster)
 */

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    parameters {
        string(
            name: 'DEPLOYMENT_NAME',
            defaultValue: 'hallXXX',
            description: 'Deployment name - must match with the name created in bucket \"eo-deploy\" in MiniIO'
        )
        choice(
            name: 'DEPLOYMENT_TYPE',
            choices: ['install', 'upgrade'],
            description: 'Deployment Type, set \"install\" or \"upgrade\"'
        )
        string(
            name: 'NAMESPACE',
            defaultValue: 'eric-eo',
            description: 'Namespace to install the Chart'
        )
        string(
            name: 'DOMAIN',
            defaultValue: '.<sample>-eiap.ews.gic.ericsson.se',
            description: 'DOMAIN in which hostname should be resolved'
        )
        string(
            name: 'KUBECONFIG_FILE',
            defaultValue: '<sample>_kubeconfig',
            description: 'Kubernetes configuration file to specify which environment to install on (secret_id)'
        )
        string(
            name: 'TAGS',
            defaultValue: 'eoEvnfm',
            description: 'List of tags for applications that have to be deployed, e.g: eoEvnfm eoVmvnfm'
        )
        string(
            name: 'INT_CHART_VERSION',
            defaultValue: '2.2.0-82',
            description: 'The version of base platform to install'
        )
        booleanParam(
            defaultValue: false,
            description: 'This will genereate on fly certs with with CA provided below',
            name: 'GENERATE_CERTS'
        )
        string (
            defaultValue: 'certs/ca-photon.crt',
            description: '(OPTIONAL) when used generate certs. PATH TO CA.crt file (relative to the pipeline root).',
            name: 'CA_CRT_PATH'
        )
        string (
            defaultValue: 'certs/ca-photon.key',
            description: '(OPTIONAL) when used generate certs. PATH TO CA.key file (relative to the pipeline root).',
            name: 'CA_KEY_PATH'
        )

        string (
            defaultValue: 'certs/tls-int+photon.crt',
            description: '(OPTIONAL) when used generate certs. PATH TO intermidiate.crt file (relative to the pipeline root).',
            name: 'INT_CERT_PATH'
        )

        string (
            defaultValue: 'NONE',
            description: '(OPTIONAL - only works when USE_DM_PREPARE=false) JSON FORMAT IF specified will be merged into site-values.yaml provided below in FULL_PATH_TO_SITE_VALUES_FILE. ie. \'{"global":{"security": {"tls":{"enabled": true}}}}\'',
            name: 'ADD_PARAMS_TO_SITE_VALUES'
        )

        string(
            name: 'INGRESS_IP',
            defaultValue: 'default',
            description: 'INGRESS IP'
        )
        string(
           name: 'DEPLOYMENT_MANAGER_DOCKER_IMAGE',
           defaultValue: 'armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:latest',
           description: 'The version of the deployment manager'
        )
        string(
            name: 'ARMDOCKER_USER_SECRET',
            defaultValue: 'detsuser_docker',
            description: 'ARM Docker secret'
        )
        string(
            name: 'HELM_TIMEOUT',
            defaultValue: '5400',
            description: 'Time in seconds for the Deployment Manager to wait for the deployment to execute, default 1800'
        )
        string(
            name: 'VNFM_HOSTNAME',
            defaultValue: 'default',
            description: 'Hostname for EO EVNFM'
        )
        string(
            name: 'VNFM_REGISTRY_HOSTNAME',
            defaultValue: 'default',
            description: 'Registry Hostname for EO EVNFM'
        )
        string(
            name: 'VNFLCM_SERVICE_DEPLOY',
            defaultValue: 'false',
            description: 'EO VM VNFM Deploy, set \"true\" or \"false\"'
        )
        string(
            name: 'HELM_REGISTRY_DEPLOY',
            defaultValue: 'false',
            description: 'EO HELM Registry Deploy, set \"true\" or \"false\"'
        )
        string(
            name: 'HELM_REGISTRY_HOSTNAME',
            defaultValue: 'default',
            description: 'Hostname for EO HELM Registry'
        )

        string(
            name: 'FULL_PATH_TO_SITE_VALUES_FILE',
            defaultValue: 'site-values/eo/ci/template/site-values-latest.yaml',
            description: 'Full path within the oss-integration-ci Repo to the site_values.yaml file OR for minio and DETS REPO ../cache/<deployment>/<site-values-file.yaml>'
        )
        string(
            name: 'PATH_TO_SITE_VALUES_OVERRIDE_FILE',
            defaultValue: 'NONE',
            description: 'Path within the Repo to the location of the site values override file. Content of this file will override the content for the site values set in the FULL_PATH_TO_SITE_VALUES_FILE paramater.'
        )
        string(
            name: 'PATH_TO_AWS_FILES',
            defaultValue: 'NONE',
            description: 'Path within the Repo to the location of the Idun aaS AWS credentials and config directory'
        )
        string(
            name: 'AWS_ECR_TOKEN',
            defaultValue: 'NONE',
            description: 'AWS ECR token for aws public environments for Idun aaS'
        )
        string(
            name: 'INT_CHART_NAME',
            defaultValue: 'eric-eo-helmfile',
            description: 'Integration Chart Name'
        )
        string(
            name: 'INT_CHART_REPO',
            defaultValue: 'https://arm.epk.ericsson.se/artifactory/proj-eo-drop-helm',
            description: 'Integration Chart Repo'
        )

        string(
            name: 'FUNCTIONAL_USER_SECRET',
            defaultValue: 'detsuser',
            description: 'Jenkins secret ID for ARM Registry Credentials'
        )
        string(
            name: 'IDUN_USER_SECRET',
            defaultValue: 'idun_user',
            description: 'Jenkins secret ID for default IDUN user password'
        )
        string(
            name: 'SLAVE_LABEL',
            defaultValue: 'cENM',
            description: 'Specify the slave label that you want the job to run on'
        )
        string(
            name: 'WHAT_CHANGED',
            defaultValue: 'None',
            description: 'Variable to store what chart contains the change'
        )
        string(
            name: 'DOCKER_REGISTRY',
            defaultValue: 'armdocker.rnd.ericsson.se',
            description: 'Set this to the docker registry to execute the deployment from. Used when deploying from Officially Released CSARs'
        )
        string(
            name: 'DOCKER_REGISTRY_CREDENTIALS',
            defaultValue: 'detsuser_docker',
            description: 'Jenkins secret ID for the Docker Registry. Not needed if deploying from armdocker.rnd.ericsson.se'
        )
        string(
            name: 'DOWNLOAD_CSARS',
            defaultValue: 'false',
            description: 'When set to true the script will try to download the officially Released CSARs relation to the version of the applications within the helmfile being deployed.'
        )
        string(
            name: 'CRD_NAMESPACE',
            defaultValue: 'crd-namespace',
            description: 'Namespace which was used to deploy the CRD (crd-namespace, eric-crd-ns)'
        )
        string(
            name: 'CRD_RELEASE',
            defaultValue: 'crd-release',
            description: 'Helm Release name where the CRD was deployed to'
        )
        string(
            name: 'DEPLOY_ALL_CRDS',
            defaultValue: 'true',
            description: 'Used within CI when deploying multiple deployments in the one cluster. When set to true ensures all tagged CRDs are set to true, to ensure no dependency mismatch between deployments'
        )
        string(
            name: 'VNFLCM_SERVICE_IP',
            defaultValue: '0.0.0.0',
            description: 'LB IP for the VNF LCM service'
        )
        string(
            name: 'COLLECT_LOGS_WITH_DM',
            defaultValue: 'false',
            description: 'If set to "false" (by default) - logs will be collected by ADP logs collection script. If true - with deployment-manager tool.'
        )
        string(
            name: 'COLLECT_LOGS',
            defaultValue: 'false',
            description: 'If set to "false" (by default) - logs will be collected by ADP logs collection script. If true - with deployment-manager tool.'
        )
        string(
            name: 'EO_CM_HOSTNAME',
            defaultValue: 'default',
            description: 'EO_CM_HOSTNAME'
        )
        string(
            name: 'EO_CM_IP',
            defaultValue: 'default',
            description: 'EO CM IP'
        )
        string(
            name: 'EO_CM_ESA_IP',
            defaultValue: 'default',
            description: 'EO CM ESA IP'
        )
        string(
            name: 'USE_DM_PREPARE',
            defaultValue: 'false',
            description: 'Set to true to use the Deploymet Manager function \"prepare\" to generate the site values file'
        )
        string(
            name: 'GERRIT_REFSPEC',
            defaultValue: 'refs/heads/master',
            description: 'This reffers on oss-integration-ci repo (most cases should be left to master). Can be used to fetch job JenkinsFile from branch (refs/heads/master) or commit (refs/changes/95/156395/1) | 95 - last 2 digits of Gerrit commit number | 156395 - is Gerrit commit number | 1 - patch number of gerrit commit | **Only to be used during testing **'
        )
        string(name: 'SFTP_USER_SECRET', defaultValue: 'sftp_user_eic', description: 'Jenkins secret ID for default sftp user password')
    }
    environment {
        USE_TAGS = 'true'
        STATE_VALUES_FILE = "site_values_${params.INT_CHART_VERSION}.yaml"
        CSAR_STORAGE_URL = 'https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-drop-generic-local/csars/'
        PATH_TO_HELMFILE = "${params.INT_CHART_NAME}/helmfile.yaml"
        CSAR_STORAGE_INSTANCE = 'arm.seli.gic.ericsson.se'
        CSAR_STORAGE_REPO = 'proj-eric-oss-drop-generic-local'
        FETCH_CHARTS = 'true'
        SITE_VALUES_FILE="${params.FULL_PATH_TO_SITE_VALUES_FILE}"
    }
    stages {
        stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} ${params.NAMESPACE} ${params.KUBECONFIG_FILE.split("-|_")[0]} - ${params.DEPLOYMENT_TYPE} - ${params.INT_CHART_VERSION}"
                }
            }
        }
        stage('Prepare') {
            steps {
                sh 'git submodule update --init bob'
                sh "git submodule sync"
                sh "git submodule update --init --recursive --remote"
                sh "${bob} git-clean"
            }
        }

        stage ('GET ENVIRONMENT'){
            steps{
                echo "Running getEnv job"
                build job: 'EO_shared_deploy_getEnv',
                      parameters: [
                          string(name: 'DEPLOYMENT_NAME', value: "${params.DEPLOYMENT_NAME}"),
                          string(name: 'SLAVE_LABEL', value: "${env.SLAVE_LABEL}")
                      ]
                script{
                    if ( "${params.GENERATE_CERTS}" == 'true') {
                        echo "GENERATING CERTS"
                        generateCerts()
                        archiveArtifacts allowEmptyArchive: true, artifacts: 'gen_certs/*.tgz', followSymlinks: false
                    }
                }
            }
        }

        stage ("CUSTOM SITE VALUE"){
            when {
                expression { params.ADD_PARAMS_TO_SITE_VALUES != 'NONE' && params.ADD_PARAMS_TO_SITE_VALUES != ''}
            }
            steps{
                echo "CREATING SITE VALUE WITH EXTRA PARAMS"
                createCustomSiteValues()

                sh "cp ${SITE_VALUES_FILE} custom_site_values.yaml"
                archiveArtifacts artifacts: "custom_site_values.yaml",
                                 allowEmptyArchive: true,
                                 followSymlinks: false
            }
        }

        stage ('TEARDOWN'){
            when {
                environment ignoreCase: true, name: 'DEPLOYMENT_TYPE', value: 'install'
            }
            steps{
                echo "Running teardown job"
                build job: 'EO_shared_deploy_teardown',
                      parameters: [
                          string(name: 'NAMESPACE', value: "${params.NAMESPACE}"),
                          string(name: 'CRD_NAMESPACE', value: "${params.CRD_NAMESPACE}"),
                          string(name: 'KUBECONFIG_FILE', value: "${params.KUBECONFIG_FILE}"),
                          string(name: 'IDUN_USER_SECRET', value: "${params.IDUN_USER_SECRET}"),
                          string(name: 'ARMDOCKER_USER_SECRET', value: "${params.ARMDOCKER_USER_SECRET}"),
                          string(name: 'SLAVE_LABEL', value: "${env.SLAVE_LABEL}"),
                          string(name: 'DOCKER_REGISTRY', value: "${params.DOCKER_REGISTRY}")
                      ]
            }
        }

        stage ('PREINSTAL'){
            when {
                environment ignoreCase: true, name: 'DEPLOYMENT_TYPE', value: 'install'
            }
            steps{
                echo "Running preinstall job"
                build job: 'EO_shared_deploy_preinstall', parameters: [string(name: 'SFTP_USER_SECRET', value: "${params.SFTP_USER_SECRET}"), string(name: 'VNFM_REGISTRY_HOSTNAME', value: "${params.VNFM_REGISTRY_HOSTNAME}"), string(name: 'DEPLOYMENT_TYPE', value: "${params.DEPLOYMENT_TYPE}"), string(name: 'NAMESPACE', value: "${params.NAMESPACE}"), string(name: 'KUBECONFIG_FILE', value: "${params.KUBECONFIG_FILE}"), string(name: 'IDUN_USER_SECRET', value: "${params.IDUN_USER_SECRET}"), string(name: 'SLAVE_LABEL', value: "${env.SLAVE_LABEL}"), string(name: 'CRD_NAMESPACE', value: "${params.CRD_NAMESPACE}")]

            }
        }

        stage ('INITIAL INSTALL'){
            when {
                environment ignoreCase: true, name: 'DEPLOYMENT_TYPE', value: 'install'
            }
            steps {
                echo "Running install job"
                build job: 'EO_shared_deploy_helmfile', parameters: [
                 string(name: 'TAGS', value: "${params.TAGS}"),
                 string(name: 'INT_CHART_VERSION', value: "${params.INT_CHART_VERSION}"),
                 string(name: 'DEPLOYMENT_TYPE', value: "${params.DEPLOYMENT_TYPE}"),
                 string(name: 'DEPLOYMENT_MANAGER_DOCKER_IMAGE', value: "${params.DEPLOYMENT_MANAGER_DOCKER_IMAGE}"),
                 string(name: 'ARMDOCKER_USER_SECRET', value: "${params.ARMDOCKER_USER_SECRET}"),
                 string(name: 'HELM_TIMEOUT', value: "${params.HELM_TIMEOUT}"),
                 string(name: 'IAM_HOSTNAME', value: "iam${params.DOMAIN}"),
                 string(name: 'SO_HOSTNAME', value: "so${params.DOMAIN}"),
                 string(name: 'BDR_HOSTNAME', value: "bdr${params.DOMAIN}"),
                 string(name: 'UDS_HOSTNAME', value: "uds${params.DOMAIN}"),
                 string(name: 'EIC_HOSTNAME', value: "eic${params.DOMAIN}"),
                 string(name: 'PF_HOSTNAME', value: "pf${params.DOMAIN}"),
                 string(name: 'GAS_HOSTNAME', value: "gas${params.DOMAIN}"),
                 string(name: 'VNFM_HOSTNAME', value: "${params.VNFM_HOSTNAME}"),
                 string(name: 'VNFM_REGISTRY_HOSTNAME', value: "${params.VNFM_REGISTRY_HOSTNAME}"),
                 string(name: 'VNFLCM_SERVICE_DEPLOY', value: "${params.VNFLCM_SERVICE_DEPLOY}"),
                 string(name: 'HELM_REGISTRY_DEPLOY', value: "${params.HELM_REGISTRY_DEPLOY}"),
                 string(name: 'HELM_REGISTRY_HOSTNAME', value: "${params.HELM_REGISTRY_HOSTNAME}"),
                 string(name: 'ADC_HOSTNAME', value: "adc${params.DOMAIN}"),
                 string(name: 'APPMGR_HOSTNAME', value: "appmgr${params.DOMAIN}"),
                 string(name: 'OS_HOSTNAME', value: "os${params.DOMAIN}"),
                 string(name: 'GR_HOSTNAME', value: "gr${params.DOMAIN}"),
                 string(name: 'TA_HOSTNAME', value: "ta${params.DOMAIN}"),
                 string(name: 'EAS_HOSTNAME', value: "eas${params.DOMAIN}"),
                 string(name: 'TH_HOSTNAME', value: "th${params.DOMAIN}"),
                 string(name: 'CH_HOSTNAME', value: "ch${params.DOMAIN}"),
                 string(name: 'PATH_TO_CERTIFICATES_FILES', value: "../cache/${params.DEPLOYMENT_NAME}/certificates"),
                 string(name: 'FULL_PATH_TO_SITE_VALUES_FILE', value: "${SITE_VALUES_FILE}"),
                 string(name: 'PATH_TO_SITE_VALUES_OVERRIDE_FILE', value: "${params.PATH_TO_SITE_VALUES_OVERRIDE_FILE}"),
                 string(name: 'PATH_TO_AWS_FILES', value: "${params.PATH_TO_AWS_FILES}"),
                 string(name: 'AWS_ECR_TOKEN', value: "${params.AWS_ECR_TOKEN}"),
                 string(name: 'INT_CHART_NAME', value: "${params.INT_CHART_NAME}"),
                 string(name: 'INT_CHART_REPO', value: "${params.INT_CHART_REPO}"),
                 string(name: 'NAMESPACE', value: "${params.NAMESPACE}"),
                 string(name: 'KUBECONFIG_FILE', value: "${params.KUBECONFIG_FILE}"),
                 string(name: 'FUNCTIONAL_USER_SECRET', value: "${params.FUNCTIONAL_USER_SECRET}"),
                 string(name: 'IDUN_USER_SECRET', value: "${params.IDUN_USER_SECRET}"),
                 string(name: 'SLAVE_LABEL', value: "${env.SLAVE_LABEL}"),
                 string(name: 'WHAT_CHANGED', value: "${params.WHAT_CHANGED}"),
                 string(name: 'DOCKER_REGISTRY', value: "${params.DOCKER_REGISTRY}"),
                 string(name: 'DOCKER_REGISTRY_CREDENTIALS', value: "${params.DOCKER_REGISTRY_CREDENTIALS}"),
                 string(name: 'DOWNLOAD_CSARS', value: "${params.DOWNLOAD_CSARS}"),
                 string(name: 'CRD_NAMESPACE', value: "${params.CRD_NAMESPACE}"),
                 string(name: 'CRD_RELEASE', value: "${params.CRD_RELEASE}"),
                 string(name: 'DEPLOY_ALL_CRDS', value: "${params.DEPLOY_ALL_CRDS}"),
                 string(name: 'INGRESS_IP', value: "${params.INGRESS_IP}"),
                 string(name: 'VNFLCM_SERVICE_IP', value: "${params.VNFLCM_SERVICE_IP}"),
                 string(name: 'COLLECT_LOGS_WITH_DM', value: "${params.COLLECT_LOGS_WITH_DM}"),
                 string(name: 'COLLECT_LOGS', value: "${params.COLLECT_LOGS}"),
                 string(name: 'EO_CM_HOSTNAME', value: "${params.EO_CM_HOSTNAME}"),
                 string(name: 'EO_CM_IP', value: "${params.EO_CM_IP}"),
                 string(name: 'EO_CM_ESA_IP', value: "${params.EO_CM_ESA_IP}"),
                 string(name: 'USE_DM_PREPARE', value: "${params.USE_DM_PREPARE}"),
                 string(name: 'GERRIT_REFSPEC', value: "${params.GERRIT_REFSPEC}")]
            }

        }

        stage ('UPGRADE'){

            when {
                environment ignoreCase: true, name: 'DEPLOYMENT_TYPE', value: 'upgrade'
            }
            steps{
                echo "Running upgrade job"
                build job: 'EO_shared_deploy_helmfile', parameters: [
                 string(name: 'TAGS', value: "${params.TAGS}"),
                 string(name: 'INT_CHART_VERSION', value: "${params.INT_CHART_VERSION}"),
                 string(name: 'DEPLOYMENT_TYPE', value: "${params.DEPLOYMENT_TYPE}"),
                 string(name: 'DEPLOYMENT_MANAGER_DOCKER_IMAGE', value: "${params.DEPLOYMENT_MANAGER_DOCKER_IMAGE}"),
                 string(name: 'ARMDOCKER_USER_SECRET', value: "${params.ARMDOCKER_USER_SECRET}"),
                 string(name: 'HELM_TIMEOUT', value: "${params.HELM_TIMEOUT}"),
                 string(name: 'IAM_HOSTNAME', value: "iam${params.DOMAIN}"),
                 string(name: 'SO_HOSTNAME', value: "so${params.DOMAIN}"),
                 string(name: 'BDR_HOSTNAME', value: "bdr${params.DOMAIN}"),
                 string(name: 'UDS_HOSTNAME', value: "uds${params.DOMAIN}"),
                 string(name: 'EIC_HOSTNAME', value: "eic${params.DOMAIN}"),
                 string(name: 'PF_HOSTNAME', value: "pf${params.DOMAIN}"),
                 string(name: 'GAS_HOSTNAME', value: "gas${params.DOMAIN}"),
                 string(name: 'VNFM_HOSTNAME', value: "${params.VNFM_HOSTNAME}"),
                 string(name: 'VNFM_REGISTRY_HOSTNAME', value: "${params.VNFM_REGISTRY_HOSTNAME}"),
                 string(name: 'VNFLCM_SERVICE_DEPLOY', value: "${params.VNFLCM_SERVICE_DEPLOY}"),
                 string(name: 'HELM_REGISTRY_DEPLOY', value: "${params.HELM_REGISTRY_DEPLOY}"),
                 string(name: 'HELM_REGISTRY_HOSTNAME', value: "${params.HELM_REGISTRY_HOSTNAME}"),
                 string(name: 'ADC_HOSTNAME', value: "adc${params.DOMAIN}"),
                 string(name: 'APPMGR_HOSTNAME', value: "appmgr${params.DOMAIN}"),
                 string(name: 'OS_HOSTNAME', value: "os${params.DOMAIN}"),
                 string(name: 'GR_HOSTNAME', value: "gr${params.DOMAIN}"),
                 string(name: 'TA_HOSTNAME', value: "ta${params.DOMAIN}"),
                 string(name: 'EAS_HOSTNAME', value: "eas${params.DOMAIN}"),
                 string(name: 'TH_HOSTNAME', value: "th${params.DOMAIN}"),
                 string(name: 'CH_HOSTNAME', value: "ch${params.DOMAIN}"),
                 string(name: 'PATH_TO_CERTIFICATES_FILES', value: "../cache/${params.DEPLOYMENT_NAME}/certificates"),
                 string(name: 'FULL_PATH_TO_SITE_VALUES_FILE', value: "${SITE_VALUES_FILE}"),
                 string(name: 'PATH_TO_SITE_VALUES_OVERRIDE_FILE', value: "${params.PATH_TO_SITE_VALUES_OVERRIDE_FILE}"),
                 string(name: 'PATH_TO_AWS_FILES', value: "${params.PATH_TO_AWS_FILES}"),
                 string(name: 'AWS_ECR_TOKEN', value: "${params.AWS_ECR_TOKEN}"),
                 string(name: 'INT_CHART_NAME', value: "${params.INT_CHART_NAME}"),
                 string(name: 'INT_CHART_REPO', value: "${params.INT_CHART_REPO}"),
                 string(name: 'NAMESPACE', value: "${params.NAMESPACE}"),
                 string(name: 'KUBECONFIG_FILE', value: "${params.KUBECONFIG_FILE}"),
                 string(name: 'FUNCTIONAL_USER_SECRET', value: "${params.FUNCTIONAL_USER_SECRET}"),
                 string(name: 'IDUN_USER_SECRET', value: "${params.IDUN_USER_SECRET}"),
                 string(name: 'SLAVE_LABEL', value: "${env.SLAVE_LABEL}"),
                 string(name: 'WHAT_CHANGED', value: "${params.WHAT_CHANGED}"),
                 string(name: 'DOCKER_REGISTRY', value: "${params.DOCKER_REGISTRY}"),
                 string(name: 'DOCKER_REGISTRY_CREDENTIALS', value: "${params.DOCKER_REGISTRY_CREDENTIALS}"),
                 string(name: 'DOWNLOAD_CSARS', value: "${params.DOWNLOAD_CSARS}"),
                 string(name: 'CRD_NAMESPACE', value: "${params.CRD_NAMESPACE}"),
                 string(name: 'CRD_RELEASE', value: "${params.CRD_RELEASE}"),
                 string(name: 'DEPLOY_ALL_CRDS', value: "${params.DEPLOY_ALL_CRDS}"),
                 string(name: 'INGRESS_IP', value: "${params.INGRESS_IP}"),
                 string(name: 'VNFLCM_SERVICE_IP', value: "${params.VNFLCM_SERVICE_IP}"),
                 string(name: 'COLLECT_LOGS_WITH_DM', value: "${params.COLLECT_LOGS_WITH_DM}"),
                 string(name: 'COLLECT_LOGS', value: "${params.COLLECT_LOGS}"),
                 string(name: 'EO_CM_HOSTNAME', value: "${params.EO_CM_HOSTNAME}"),
                 string(name: 'EO_CM_IP', value: "${params.EO_CM_IP}"),
                 string(name: 'EO_CM_ESA_IP', value: "${params.EO_CM_ESA_IP}"),
                 string(name: 'USE_DM_PREPARE', value: "${params.USE_DM_PREPARE}"),
                 string(name: 'GERRIT_REFSPEC', value: "${params.GERRIT_REFSPEC}")]
            }

        }

        stage ('POSTCHEKS'){
            when {
                environment ignoreCase: true, name: 'DEPLOYMENT_TYPE', value: 'install'
            }
            steps{
                echo "Running postchek job"
                echo "A placeholder for some needed post checks"
                build job: 'EO_shared_deploy_postchecks', parameters: [string(name: 'TEAM_NAME', value: "${params.TEAM_NAME}"),string(name: 'DEPLOYMENT_NAME', value: "${params.DEPLOYMENT_NAME}"), string(name: 'DEPLOYMENT_TYPE', value: "${params.DEPLOYMENT_TYPE}"), string(name: 'NAMESPACE', value:  "${params.NAMESPACE}"), string(name: 'DOMAIN', value: "${params.DOMAIN}"), string(name: 'KUBECONFIG_FILE', value: "${params.KUBECONFIG_FILE}"), string(name: 'TAGS', value: "${params.TAGS}"), string(name: 'INT_CHART_VERSION', value: "${params.INT_CHART_VERSION}")]
            }
        }
    }

    post {
        always{
            cleanWs disableDeferredWipeout: true
            sh "rm -rf ../cache/${env.DEPLOYMENT_NAME}/*"
        }
    }
}

def generateCerts(){
    sh"""
        mkdir -p ../cache/${env.DEPLOYMENT_NAME}/certificates/
        cp ${INT_CERT_PATH} ../cache/${env.DEPLOYMENT_NAME}/certificates/intermediate-ca.crt
        rm -rf gen_certs
        mkdir -p gen_certs
        cp ../cache/${env.DEPLOYMENT_NAME}/certificates/intermediate-ca.crt gen_certs/

        cd gen_certs
        DMN=${params.DOMAIN}
        ../jenkins/scripts/generate-tls-certs.v2.sh \
            --dns-domain "\${DMN:1}" \
            --app-list adc,appmgr,bdr,bootstrap,ch,eas,gas,iam,la,ml,os,th,eic,evnfm,helm,registry,gr,pf,so,uds,eca,eocm,prov.eocm,notif.eocm \
            --ca-crt "../${CA_CRT_PATH}" \
            --ca-key "../${CA_KEY_PATH}"
        tar cvfz "certs_${env.DEPLOYMENT_NAME}_${env.BUILD_NUMBER}.tgz" ./*
        cp *.key ../../cache/${env.DEPLOYMENT_NAME}/certificates/
        cp *.crt ../../cache/${env.DEPLOYMENT_NAME}/certificates/
        cd ../../cache/${env.DEPLOYMENT_NAME}/certificates/
        find . | sort
    """
}
/* OLD WAY
def generateCerts(){
    sh"""
        mkdir -p ../cache/${env.DEPLOYMENT_NAME}/certificates/
        cp ${INT_CERT_PATH} ../cache/${env.DEPLOYMENT_NAME}/certificates/intermediate-ca.crt
        mkdir -p gen_certs
        cd gen_certs
        ../jenkins/scripts/generate-tls-certs.sh "${DOMAIN}" "gr evnfm helm registry pf so uds eca eocm prov.eocm notif.eocm th" "../${CA_CRT_PATH}"  "../${CA_KEY_PATH}"
        tar cvfz "certs_${env.DEPLOYMENT_NAME}_${env.BUILD_NUMBER}.tgz" ./*
        mkdir -p ../../cache/${env.DEPLOYMENT_NAME}/certificates/
        cp *.key ../../cache/${env.DEPLOYMENT_NAME}/certificates/
        cp *.crt ../../cache/${env.DEPLOYMENT_NAME}/certificates/
    """
}
*/

def createCustomSiteValues(){
    SITE_VALUES_W_EXTRA_PARAMS = "../cache/${env.DEPLOYMENT_NAME}/site_values-${env.BUILD_NUMBER}.yaml"

    //GIT CHECKOUTS EO REPO
    dir ('oss-integration-ci'){
        git credentialsId: 'lciadm100_gerrit_ssh', url: 'ssh://gerrit-gamma.gic.ericsson.se:29418/OSS/com.ericsson.oss.aeonic/oss-integration-ci', branch: 'master'
    }
    //MERGE SITE_VALUES

    if (SITE_VALUES_FILE.contains('../')){
        sh"""
         echo $ADD_PARAMS_TO_SITE_VALUES > extra.json
            yq '. *= load("extra.json")' ${SITE_VALUES_FILE} -P > ${SITE_VALUES_W_EXTRA_PARAMS}
        """
    }else{
                sh"""
         echo $ADD_PARAMS_TO_SITE_VALUES > extra.json
            yq '. *= load("extra.json")' oss-integration-ci/${SITE_VALUES_FILE} -P > ${SITE_VALUES_W_EXTRA_PARAMS}
        """
    }

    SITE_VALUES_FILE = "${SITE_VALUES_W_EXTRA_PARAMS}"
}
