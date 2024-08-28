#!/usr/bin/env groovy

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"
pipeline {
    agent {
        label env.SLAVE_LABEL
    }

    parameters {
        string(name: 'NAMESPACE', defaultValue: 'evnfm2', description: 'Namespace to purge environment')
        string(name: 'CRD_NAMESPACE', description: 'CRD Namespace to purge ')
        string(name: 'KUBECONFIG_FILE', defaultValue: 'kubeconfig', description: 'Kubernetes configuration file to specify which environment purge' )
        string(name: 'IDUN_USER_SECRET', defaultValue: 'idun_user', description: 'Jenkins secret ID for default IDUN user password')
        string(name: 'ARMDOCKER_USER_SECRET', defaultValue: 'detsuser_docker', description: 'ARM Docker secret')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')
        string(name: 'DOCKER_REGISTRY',defaultValue: 'armdocker.rnd.ericsson.se',description: 'Set this to the docker registry to execute the deployment from. Used when deploying from Officially Released CSARs')

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
                sh 'chmod +x jenkins/scripts/*'
            }
        }


        stage('Check K8S Connectivity') {
            steps {
                withCredentials([file(credentialsId: params.KUBECONFIG_FILE, variable: 'KUBECONFIG')]) {
                    sh "install -m 600 ${KUBECONFIG} ./admin.conf"
                }
                sh "${bob} do-health-check:check-eks-connectivity"
            }
        }

        stage('Cleanup ALL Helm Charts') {
            steps {
                sh "${bob} remove-helm3-installed-release:remove-all-charts"
            }
        }

        stage('Remove SA and CRB') {
            steps {
                    sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf get sa evnfm -n ${params.NAMESPACE} && kubectl --kubeconfig ./admin.conf delete sa evnfm -n ${params.NAMESPACE}"
                    sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf get clusterrolebinding evnfm-${NAMESPACE} && kubectl --kubeconfig ./admin.conf delete clusterrolebinding evnfm-${NAMESPACE}"

            }
        }

        
        stage('Remove namespace') {
            steps {
                    sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf get ns ${params.NAMESPACE} && kubectl --kubeconfig ./admin.conf delete ns ${params.NAMESPACE}"
                    sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf get ns ${params.CRD_NAMESPACE} && kubectl --kubeconfig ./admin.conf delete ns ${params.CRD_NAMESPACE}"

            }
        }
    }
}
