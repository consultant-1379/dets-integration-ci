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
	string(name: 'NAMESPACE', defaultValue: 'dets-monitoring', description: 'Namespace to install Prometheus')
	string(name: 'VERSION', defaultValue: '43.1.1', description: 'Prometheus version')
    }
    stages {
        stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} ${params.DEPLOYMENT_NAME} ${params.NAMESPACE} ${params.VERSION}"
                }
            }
        }
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
                	sh "${bob} get-from-minio:get-keys-certificates"
		}
            }
        }
	stage('Add monitoring') {
	    steps {
		sh "jenkins/scripts/add_dets_monitoring_to_ews.sh ${params.DEPLOYMENT_NAME}/kube_config/* ${params.NAMESPACE} ${params.VERSION}"
		}
	}
    }
}

