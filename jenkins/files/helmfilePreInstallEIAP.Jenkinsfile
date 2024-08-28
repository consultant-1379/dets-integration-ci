#!/usr/bin/env groovy

/* IMPORTANT:
 *
 * In order to make this pipeline work, the following configuration on Jenkins is required:
 * - slave with a specific label (see pipeline.agent.label below)
 * - Credentials Plugin should be installed and have the secrets with the following names:
 */

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"
def checkout_oss_integration_ci() {
        checkout changelog: false, poll: false,
                scm: [$class: 'GitSCM', branches: [[name: '*/master']],
                extensions: [[$class: 'SubmoduleOption', disableSubmodules: true, parentCredentials: false, recursiveSubmodules: false, reference: '', trackingSubmodules: false],
                [$class: 'RelativeTargetDirectory', relativeTargetDir: 'oss-integration-ci']],
                userRemoteConfigs: [[url: "${GERRIT_MIRROR}/OSS/com.ericsson.oss.aeonic/oss-integration-ci"]]]
}

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    parameters {
        string(name: 'DEPLOYMENT_TYPE', defaultValue: 'install', description: 'Deployment Type, set \"install\" or \"upgrade\"' )
        string(name: 'NAMESPACE', defaultValue: 'eric-eiap', description: 'Namespace to purge environment')
        string(name: 'KUBECONFIG_FILE', defaultValue: 'kubeconfig', description: 'Kubernetes configuration file to specify which environment install on' )
        string(name: 'IDUN_USER_SECRET', defaultValue: 'idun_user', description: 'Jenkins secret ID for default IDUN user password')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')
        string(
            name: 'ARMDOCKER_USER_SECRET',
            defaultValue: 'detsuser_docker',
            description: 'ARM Docker secret'
        )
	    string(name: 'CRD_NAMESPACE', defaultValue: 'eric-crd-ns', description: 'Namespace to purge environment')
        string(name: 'SFTP_USER_SECRET', defaultValue: 'sftp_user_eic', description: 'Jenkins secret ID for default sftp user password')
    }
    stages {
	    stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} ${params.NAMESPACE} ${params.KUBECONFIG_FILE.split("-|_")[0]}"
                }
            }
        }
        stage('Clean Workspace') {
            steps {
                sh 'git clean -xdff'
                sh 'git submodule sync'
                sh 'git submodule update --init --recursive --remote'
//                checkout_oss_integration_ci()
            }
        }

        stage('Install Docker Config File') {
            steps {
                withCredentials ([
                    file (
                        credentialsId:  params.ARMDOCKER_USER_SECRET,
                        variable:       'DOCKERCONFIG'
                    )
                ]) {
                    sh 'install -m 600 -D ${DOCKERCONFIG} ${HOME}/.docker/config.json'
                    sh 'install -m 600 ${DOCKERCONFIG} ./dockerconfig.json'
                }
            }
        }
	    stage('Get Kube Config') {
            steps {
                withCredentials([file(credentialsId: params.KUBECONFIG_FILE, variable: 'KUBECONFIG')]) {
                    sh 'install -m 600 ${KUBECONFIG} ./admin.conf'
                    sh 'install -m 600 -D "${KUBECONFIG}" kube_config/config'
                        }
                }
        }
        stage('Check EWS Connectivity') {
            steps {
                sh "${bob} do-health-check:check-eks-connectivity"
            }
        }
        stage('Create namespaces if not exist') {
            steps {
                sh "${bob} create-release-namespace"
            }
        }
        stage('Pre Deployment Configurations') {
            steps {
                script {
                    if (env.DEPLOYMENT_TYPE == 'install') {
                        withCredentials([usernamePassword(credentialsId: env.IDUN_USER_SECRET, usernameVariable: 'IDUN_USER_USERNAME', passwordVariable: 'IDUN_USER_PASSWORD')]) {
                            sh "${bob} create-credentials-secrets"
                        }
                    }
                }
            }
        }
        stage("Add docker registry secret"){
            steps{
                sh returnStatus: true, script:"""kubectl --kubeconfig ./admin.conf create secret generic k8s-registry-secret-legacy --from-file=.dockerconfigjson=./dockerconfig.json --type=kubernetes.io/dockerconfigjson -n ${params.NAMESPACE}
                kubectl --kubeconfig ./admin.conf create secret generic k8s-registry-secret-legacy --from-file=.dockerconfigjson=./dockerconfig.json --type=kubernetes.io/dockerconfigjson -n ${params.CRD_NAMESPACE}
                kubectl --kubeconfig ./admin.conf create secret generic k8s-registry-secret --from-file=.dockerconfigjson=./dockerconfig.json --type=kubernetes.io/dockerconfigjson -n ${params.NAMESPACE}
                kubectl --kubeconfig ./admin.conf create secret generic k8s-registry-secret --from-file=.dockerconfigjson=./dockerconfig.json --type=kubernetes.io/dockerconfigjson -n ${params.CRD_NAMESPACE}
                """
            }
        }
        stage("Add SFTP secret"){
            steps{
                withCredentials([usernamePassword(credentialsId: env.SFTP_USER_SECRET, usernameVariable: 'SFTP_USER_USERNAME', passwordVariable: 'SFTP_USER_PASSWORD')]) {
                    sh returnStatus: true, script:"""kubectl --kubeconfig ./admin.conf create secret generic eric-odca-diagnostic-data-collector-sftp-credentials --from-literal='sftp_credentials.json={"username":"'$SFTP_USER_USERNAME'","password":"'$SFTP_USER_PASSWORD'"}' --namespace ${params.NAMESPACE}"""
                }
            }
        }
        stage("check storage class"){
            steps{
                sh"""kubectl --kubeconfig ./admin.conf get storageclass | grep default | grep block || { kubectl --kubeconfig ./admin.conf  patch storageclass network-file -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'; kubectl --kubeconfig ./admin.conf  patch storageclass network-block -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'; }
                """
            }
        }
    }
}
