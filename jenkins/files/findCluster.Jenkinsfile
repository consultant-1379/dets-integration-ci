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

        choice(
            name: 'DEPLOYMENT_SET',
            choices: ["adc-e2e-cicd","app-mgr-e2e-cicd","config-handling-e2e-cicd","dmm-e2e-cicd","eas-e2e-cicd","eca-e2e-cicd","eo-so","evnfm","full-EIAP","os-e2e-cicd","pf-e2e-cicd","pmh-e2e-cicd","so-e2e-cicd","ta-e2e-cicd","topology-handling-e2e-cicd","ud-eiap","uds-e2e-cicd","vm-vnfm"],
            description: 'Choose set from drop-down menu'
        )
        
        string(
            name: 'CPU_TRESHOLD',
            defaultValue: '5',
            description: 'Hom many CPU should be free after installation'
        )
        
        string(
            name: 'RAM_TRESHOLD',
            defaultValue: '20',
            description: 'How much ram (in GB) should be free after installation'
        )

        string(
            name: 'NAMESPACE',
            defaultValue: 'eric-eiap',
            description: 'Namespace to install the Chart'
        )
     
        string(
            name: 'SLAVE_LABEL',
            defaultValue: 'cENM',
            description: 'Specify the slave label that you want the job to run on'
        )

    }
    environment {
        USE_TAGS = 'true'
    }
    stages {
        stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} - ${params.DEPLOYMENT_SET}"
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
        
        stage ("FIND CLUSTER"){
            steps{
                resolveDeployment()
                findCluster()
            }
        }

        stage ("FIND DOMAIN and INGRESS"){
            steps{
                findDomain()
                findIngress()
            }
        }

        stage ('SET BUILD INFO and RUN the MASTER PIPELINE'){
            steps{
                script{
                    currentBuild.description = """
                        CPU = ${CPU_NEEDED}
                        RAM = ${RAM_NEEDED}
                        NAMESPACE = ${NAMESPACE}
                        CLUSTER = ${FOUND_CLUSTER}
                        DOMAIN = ${FOUND_DOMAIN}
                        INGRESS = ${FOUND_INGRESS}
                    """
                    currentBuild.displayName = "${env.BUILD_NUMBER} - ${params.DEPLOYMENT_SET} - ${FOUND_CLUSTER} "
                }
                // HERE INVOKE MASTER_PIPELINE TO BUIDL
                // buildJob: 
   
            }
        }
    }
}

def resolveDeployment(){
    env.CPU_NEEDED = sh (script:"cat jenkins/templates/KaaSresources.json | jq \'.[\"${DEPLOYMENT_SET}\"].cpu\'", returnStdout:true).trim()
    env.RAM_NEEDED = sh (script:"cat jenkins/templates/KaaSresources.json | jq \'.[\"${DEPLOYMENT_SET}\"].ram\'", returnStdout:true).trim()
    env.TAGS_NEDED = sh (script:"cat jenkins/templates/KaaSresources.json | jq \'.[\"${DEPLOYMENT_SET}\"].tags\'", returnStdout:true).trim()
}

def findCluster(){
    env.FOUND_CLUSTER = sh (script: "jenkins/scripts/find_cluster.sh ${CPU_NEEDED} ${RAM_NEEDED} ${CPU_TRESHOLD} ${RAM_TRESHOLD}", returnStdout:true).trim()
}

def findDomain(){
    env.FOUND_DOMAIN = sh (script: "jenkins/scripts/find_domain.sh ${env.FOUND_CLUSTER}", returnStdout:true).trim()
}

def findIngress(){
    env.FOUND_INGRESS = sh (script: "dig +short test${env.FOUND_DOMAIN} | tail -1", returnStdout:true).trim()
}