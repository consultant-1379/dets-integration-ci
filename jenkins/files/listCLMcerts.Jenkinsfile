#!/usr/bin/env groovy

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"
pipeline {
    agent {
        label env.SLAVE_LABEL
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
    }

    parameters {
        string(name: 'DEPLOYMENT_NAME',defaultValue: 'hallXXX',description: 'This is used to determine the path certs on minio')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM2', description: 'Specify the slave label that you want the job to run on')


    }
    stages {
	    stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} - ${params.DEPLOYMENT_NAME}"
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

        stage('CLM availability') {
            steps {
                sh """curl -sL --connect-timeout 30  https://clm-api.ericsson.net
                """
            }
        }

        stage('List CERTS') {
            steps{
                sh """
                    jenkins/scripts/cert_list_clm.sh "${params.DEPLOYMENT_NAME}" 
                """
            }
            post{
                success{
                    archiveArtifacts allowEmptyArchive: true, artifacts: "${params.DEPLOYMENT_NAME}_cert_list.txt", followSymlinks: false
                }
            }
        }


    }
    post {
        always{
            cleanWs disableDeferredWipeout: true
        }
    }
}




