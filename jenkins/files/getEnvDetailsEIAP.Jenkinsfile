#!/usr/bin/env groovy

/* IMPORTANT:
 * In order to make this pipeline work, the following configuration on Jenkins is required:
 * - slave with a specific label (see pipeline.agent.label below)
 * - Credentials Plugin should be installed and have the secrets with the following names:
 */

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    environment  {
        MINIO_USER_SECRET = 'miniosecret'
    }
    parameters {
        string(name: 'DEPLOYMENT_NAME', defaultValue: 'hallXXX', description: 'Deployment name')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')
        booleanParam(
            defaultValue: false,
            description: 'This will check as well REPO (deployments/<DEPLOYMENT_NAME>) path for CERTS  and SITE_VALUES  and store it chache (you will need provide ../cache/<deployment>/<site-values-file.yaml> as PATH_TO_SITE_VALUES',
            name: 'ENV_FROM_REPO'
        )
    }
    stages {
        stage('Clean Workspace') {
            steps {
                sh 'git clean -xdff'
                sh 'git submodule sync'
                sh 'git submodule update --init --recursive --remote'
            }
        }
        stage('Get Env details from MinIO') {
            steps {
                withCredentials([usernameColonPassword(credentialsId: env.MINIO_USER_SECRET, variable: 'MINIO_CREDS')]) {
                    sh returnStatus: true, script: "${bob} get-from-minio"
                }
            }
        }
        stage('Get Env details from DETS repo') {
            when {
                expression { "${params.ENV_FROM_REPO}" == 'true'}
            }
            steps {
                sh """
                    mkdir -p  ../cache/${params.DEPLOYMENT_NAME}
                    cp --recursive deployments/${params.DEPLOYMENT_NAME} ../cache/
                """
            }
        }
    }
}


