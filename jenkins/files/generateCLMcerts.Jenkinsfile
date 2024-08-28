#!/usr/bin/env groovy

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"
pipeline {
    agent {
        label env.SLAVE_LABEL
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
    }

    environment  {
	    MINIO_USER_SECRET = 'miniosecret'
    }

    parameters {
        string(name: 'DEPLOYMENT_NAME',defaultValue: 'hallXXX',description: 'This is used to determine the path certs on minio')
        choice(
            name: 'FOLDER',
            choices: ['eiap','eo-deploy', 'custom',],
            description: 'Provide folder name where your deployment is located (certs will be saved under <FOLDER>/<DEPLOYMENT_NAME>/<CERTS_PATH>.\nNOTE: Please choose custom to specify full path to certs'
        )
        string(name: 'CERTS_PATH',defaultValue: 'certificates',description: 'Certs will be saved under  <FOLDER>/<DEPLOYMENT_NAME>/<CERTS_PATH>.\nNOTE: If custom was chosen, FOLDER and DEPLOYMENT_NAME will be ignored')
        string(name: 'DOMAIN', defaultValue: '.<sample>-eiap.ews.gic.ericsson.se', description: 'Certs will be generated for <TAG>.<DOMAIN>')
        string(name: 'PREFIXES', defaultValue: 'iam gas', description: 'LIST OF PREFIXES. Certs will be generated for <prefix>.<DOMAIN>')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM2', description: 'Specify the slave label that you want the job to run on')


    }
    stages {
	    stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} ${params.FOLDER}-${params.DEPLOYMENT_NAME}"
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

        stage('GENERATE CERTS') {
            steps{
          
                dir("${params.DEPLOYMENT_NAME}"){
                    sh """
                    ../jenkins/scripts/cert_generate_clm.sh "${PREFIXES}" "${DOMAIN}" ..
                    """
                }
            }
        }

        stage('MOVE CERTS to MINIO') {
            steps {
              dir("${params.DEPLOYMENT_NAME}"){
                copy_certs_to_minio()
                sh "tar cvfz \"certs_${params.DEPLOYMENT_NAME}_${env.BUILD_NUMBER}.tgz\" ./*"    
              }

            }
            post{
                success{
                    archiveArtifacts allowEmptyArchive: true, artifacts: "${params.DEPLOYMENT_NAME}/*.tgz", followSymlinks: false
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


def copy_certs_to_minio(){
    if ("${params.FOLDER}" == "custom"){
      remote_dir = "${params.CERTS_PATH}"
    }else{
      remote_dir = "${params.FOLDER}/${params.DEPLOYMENT_NAME}/${params.CERTS_PATH}"
    }
   
    withCredentials([usernameColonPassword(credentialsId: "${MINIO_USER_SECRET}", variable: 'MINIO_SECRET')]) {
        sh """
            cp ../certs/tls-int-clm.crt ./intermediate-ca.crt
            docker run --rm --volume \$(pwd):/workdir --workdir /workdir -e MC_HOST_minio='http://${MINIO_SECRET}@minio.stsoss.seli.gic.ericsson.se:9000' armdocker.rnd.ericsson.se/dockerhub-ericsson-remote/minio/mc:latest cp -r ./ minio/${remote_dir}		 
        """
    }   

}


