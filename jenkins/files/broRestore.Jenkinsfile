#!/usr/bin/env groovy

/* IMPORTANT:
 *
 * In order to make this pipeline work, the following configuration on Jenkins is required:
 * - slave with a specific label (see pipeline.agent.label below)
 * - Credentials Plugin should be installed and have the secrets with the following names:
 */

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"
def bob_oss = "bob/bob -r \${WORKSPACE}/oss-integration-ci/ci/jenkins/rulesets/ruleset2.0.yaml"
def checkout_oss_integration_ci() {
    checkout changelog: false, poll: false,
        scm: [$class: 'GitSCM', branches: [[name: '*/master']],
        extensions: [[$class: 'SubmoduleOption', disableSubmodules: false, parentCredentials: false, recursiveSubmodules: true, reference: '', trackingSubmodules: false],
        [$class: 'RelativeTargetDirectory', relativeTargetDir: 'oss-integration-ci']],
         userRemoteConfigs: [[url: "${GERRIT_MIRROR}/OSS/com.ericsson.oss.aeonic/oss-integration-ci"]]]
}

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    parameters {
        string(
            name: 'TAGS',
            defaultValue: 'so pf uds adc th dmm appmgr ch ta eas os pmh',
            description: 'List of tags for applications that have to be deployed, e.g: so adc pf'
        )
        string(
            name: 'BACKUP_NAME',
            defaultValue: 'NONE',
            description: 'If no backup is specified, Backup annotated in namespace will be used'
        )
        string(
            name: 'INT_CHART_VERSION',
            defaultValue: '2.2.0-82',
            description: 'The version of base platform to install'
        )
        string(
            name: 'PATH_TO_SITE_VALUES_FILE',
            defaultValue: 'oss-integration-ci/site-values/idun/ci/template/site-values-latest.yaml',
            description: 'Full path within the Repo to the site_values.yaml file FOR EIAP site-values/idun/ci/template/site-values-latest.yaml FOR EO site-values/eo/ci/template/site-values-latest.yaml'
        )
        string(
            name: 'ARMDOCKER_USER_SECRET',
            defaultValue: 'detsuser_docker',
            description: 'ARM Docker secret'
        )
        string(
            name: 'NAMESPACE',
            defaultValue: 'eric-eiap',
            description: 'Namespace to install the Chart'
        )
        string(
            name: 'KUBECONFIG_FILE', 
            defaultValue: 'kubeconfig', 
            description: 'Kubernetes configuration file to specify which environment backup' 
        )
        string(
            name: 'FUNCTIONAL_USER_SECRET',
            defaultValue: 'detsuser',
            description: 'Jenkins secret ID for ARM Registry Credentials'
        )
        string(
            name: 'DOMAIN',
            defaultValue: '.<sample>-eiap.ews.gic.ericsson.se',
            description: 'DOMAIN NAME TO FILL SITE VALUES if provide template site values'
        )
        string(
            name: 'BRO_SVC_URL',
            defaultValue: 'so.<sample>-eiap.ews.gic.ericsson.se',
            description: 'DM will use this to contact backup API'
        )
        string(
            name: 'IDUN_USER_SECRET',
            defaultValue: 'idun_user',
            description: 'Jenkins secret ID for default IDUN user password'
        )
        string(
            name: 'BACKUP_USER_SECRET',
            defaultValue: 'backup_user',
            description: 'Jenkins secret ID for default backup server username and password'
        )
        string(
            name: 'BACKUP_SERVER',
            defaultValue: '10.82.14.5:2022/backups',
            description: 'Server for image backup and retrieval for KaaS SELI 10.82.14.5:2022/backups, for KaaS SERO 10.41.3.5:2022/backups, vpod3 10.41.0.5 vpod5 10.82.13.60'
        )
        string(
            name: 'SLAVE_LABEL',
            defaultValue: 'cENM',
            description: 'Specify the slave label that you want the job to run on'
        )
        string(
            name: 'ENV_NAME',
            description: 'The name of the environment'
        )
        string(
           name: 'DEPLOYMENT_MANAGER_DOCKER_IMAGE',
           defaultValue: 'armdocker.rnd.ericsson.se/proj-eric-oss-drop/eric-oss-deployment-manager:latest',
           description: 'The version of the deployment manager'
        )
    }
    stages {
        stage('Prepare') {
            steps {
                sh 'git submodule update --init bob'
                sh "${bob} git-clean"
                sh 'git submodule sync'
                sh 'git submodule update --init --recursive --remote'
                checkout_oss_integration_ci()
            }
        }
        stage('Fetching oss-integration-ci repo') {
            steps {
                sh '''
                    cd ${PWD}/oss-integration-ci
                    git submodule update --init 
                    git submodule sync
                    git submodule update --init --recursive --remote
                '''
            }
        }        
        stage('Prepare Working Directory') {
            steps {
                withCredentials([file(credentialsId: params.KUBECONFIG_FILE, variable: 'KUBECONFIG')]) {
                    sh "install -m 600 ${KUBECONFIG} ./admin.conf"
                    sh "mkdir -p kube_config; cp admin.conf kube_config/config"
                    sh "${bob} do-health-check:check-eks-connectivity"
                }
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} ${params.NAMESPACE} ${params.KUBECONFIG_FILE.split("-|_")[0]} - restore"
                }
            }
        }

        stage ('Annotate backup if needed'){
            when {
                expression { params.BACKUP_NAME != 'NONE'}
            }
            steps{
                sh "kubectl --kubeconfig ./admin.conf  annotate --overwrite namespace ${params.NAMESPACE}  backupname=${params.BACKUP_NAME}"
            }
        }

        stage('Gather the backup name') {
            steps {
                sh "${bob} get-backup-name"
            }
        }

        stage('Copy and Override Site Values') {
            steps {
                withCredentials([usernamePassword(credentialsId: env.BACKUP_USER_SECRET, usernameVariable: 'BACKUP_USER_USERNAME', passwordVariable: 'BACKUP_USER_PASSWORD')]) {
                    sh "${bob} prepare-site-values:copy-site-values"
                    replaceSTFP("${BACKUP_USER_USERNAME}","${BACKUP_USER_PASSWORD}")
                }
            }
        }

        stage('Update site values') {
            steps {
                script {
                    withCredentials([
                        usernamePassword(credentialsId: env.IDUN_USER_SECRET, usernameVariable: 'IDUN_USER_USERNAME', passwordVariable: 'IDUN_USER_PASSWORD'),
                        usernamePassword(credentialsId: env.BACKUP_USER_SECRET, usernameVariable: 'BACKUP_USER_USERNAME', passwordVariable: 'BACKUP_USER_PASSWORD'),
                        usernamePassword(credentialsId: env.FUNCTIONAL_USER_SECRET, usernameVariable: 'FUNCTIONAL_USER_USERNAME', passwordVariable: 'FUNCTIONAL_USER_PASSWORD')]) {
                        prepareEnvForSiteValue()
                        sh "${bob_oss} update-site-values:substitute-application-hosts"
                        sh "${bob_oss} update-site-values:substitute-application-deployment-option"
                    }
                }
                sh """
                    mkdir -p output_files
                    cp site_values_${env.INT_CHART_VERSION}.yaml output_files/
                    cat output_files/site_values_${env.INT_CHART_VERSION}.yaml
                """
            }
        }
        stage('Check if backup is already in BRO') {
            when { expression { return fileExists ('.bob/var.backup_name') } }
            steps{
                sh "${bob} check-backup-in-bro"
            }
        }
        stage('Delete backup from BRO') {
            when { expression { return fileExists ('.delete_backup') } }
            steps{
                sh "${bob} delete-backup"
                sh "rm -f .delete_backup"
            }
        }
        stage('Import the Backup from SFTP Server') {
            when { expression { return fileExists ('.bob/var.backup_name') } }
            steps {
                sh "${bob} import-backup-from-sftp"
            }
        }
        stage('Restore the Backup') {
            when { expression { return fileExists ('.bob/var.backup_name') } }
            steps {
                sh "${bob} pre-restoration-hook"
                // temporary workaround: see IDUN-33220 and https://eteamproject.internal.ericsson.com/browse/ADPPRG-77657
                sh "bash jenkins/scripts/apply_workaround_for_restore.sh --path-to-kubeconfig-file ${env.PATH_TO_KUBECONFIG_FILE} --namespace ${env.NAMESPACE}"
                sh "${bob} restore-from-backup"
            }
            post {
               always {
                    sh "${bob} post-restoration-hook"
                }
            }
        }
    }
    post {
        always {
            archiveArtifacts artifacts: 'logs/*.log', allowEmptyArchive: true
            cleanWs disableDeferredWipeout: true
        }
    }
}

void replaceSTFP(String user, String passwd){
    sh """sed -i "s/username: \"dummy\"/username: \"${user}\"/" \$(pwd)/site_values_${env.INT_CHART_VERSION}.yaml
        sed -i "s/password: \"dummy\"/password: \"${passwd}\"/" \$(pwd)/site_values_${env.INT_CHART_VERSION}.yaml
        sed -i "s/username: \'dummy\'/username: \"${user}\"/" \$(pwd)/site_values_${env.INT_CHART_VERSION}.yaml
        sed -i "s/password: \'dummy\'/password: \"${passwd}\"/" \$(pwd)/site_values_${env.INT_CHART_VERSION}.yaml
    """
}

void prepareEnvForSiteValue(){
    env.IAM_HOSTNAME = "iam${params.DOMAIN}"
    env.SO_HOSTNAME = "so${params.DOMAIN}"
    env.UDS_HOSTNAME = "uds${params.DOMAIN}"
    env.PF_HOSTNAME = "pf${params.DOMAIN}"
    env.GAS_HOSTNAME = "gas${params.DOMAIN}"
    env.ADC_HOSTNAME = "adc${params.DOMAIN}"
    env.APPMGR_HOSTNAME = "appmgr${params.DOMAIN}"
    env.TA_HOSTNAME = "ta${params.DOMAIN}"
    env.EAS_HOSTNAME = "eas${params.DOMAIN}"
    env.CH_HOSTNAME = "ch${params.DOMAIN}"
    env.TH_HOSTNAME = "th${params.DOMAIN}"
    env.OS_HOSTNAME = "os${params.DOMAIN}"
    env.VNFM_HOSTNAME = "evnfm${params.DOMAIN}"
    env.VNFM_REGISTRY_HOSTNAME = "registry${params.DOMAIN}"
    env.GR_HOSTNAME = "gr${params.DOMAIN}"
    env.ML_HOSTNAME = "ml${params.DOMAIN}"
    env.AVIZ_HOSTNAME = "aviz${params.DOMAIN}"
    env.EO_CM_HOSTNAME = "eocm${params.DOMAIN}"
    env.HELM_REGISTRY_HOSTNAME = "helm${params.DOMAIN}"
    env.EO_CM_IP = "default"
    env.EO_CM_ESA_IP = "default"
    env.VNFLCM_SERVICE_IP = "default"
    env.INGRESS_IP = "default"
}