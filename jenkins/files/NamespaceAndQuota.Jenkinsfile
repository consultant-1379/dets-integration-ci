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
        choice(
            name: 'ACTION',
            choices: ['getQuota', 'removeNamespace','addQuota','removeQuota', 'addNamespace'],
            description: 'Do you want to add or remove quota for specific cluster and namespace'
        )
        string(name: 'NAMESPACE', defaultValue: 'eric-eiap', description: 'Namespace to be managed (will create it if does not exists)')
        string(name: 'KUBECONFIG_FILE', defaultValue: 'hall144_kubeconfig', description: 'Kubernetes configuration file to specify which environment to manage' )
        string(name: 'CPU_REQ_QUOTA', defaultValue: '20', description: 'CPU Request QUOTA for NAMESPACE')
        string(name: 'CPU_LIMIT_QUOTA', defaultValue: '20', description: 'CPU Limits QUOTA for NAMESPACE')
        string(name: 'MEM_REQ_QUOTA', defaultValue: '40Gi', description: 'CPU Request QUOTA for NAMESPACE')
        string(name: 'MEM_LIMIT_QUOTA', defaultValue: '40Gi', description: 'CPU Limits QUOTA for NAMESPACE')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')

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

        stage('ADD NAMESPACE') {
            when {
                expression { params.ACTION == 'addNamespace' || params.ACTION == 'addQuota' }
            }
            steps {
                echo "Adding namespace ${NAMESPACE}"
                sh"kubectl --kubeconfig ./admin.conf get ns ${NAMESPACE} || kubectl --kubeconfig ./admin.conf create ns ${NAMESPACE}"
            }
        }

        stage('REMOVE NAMESPACE') {
            when {
                equals(actual: params.ACTION , expected: "removeNamespace")
            }
            steps {
                echo "ADD CRB Clusterrole"
                sh"kubectl --kubeconfig ./admin.conf get ns ${NAMESPACE} && kubectl --kubeconfig ./admin.conf delete ns ${NAMESPACE}"
            }
        }

        stage('ADD QUOTAS') {
            when {
                equals(actual: params.ACTION , expected: "addQuota")
            }
            steps {
                echo "ADDING QUOTAS"
                addQuota()
            }
        }

        stage('REMOVE QUOTAS') {
            when {
                equals(actual: params.ACTION , expected: "removeQuota")
            }
            steps {
                echo "REMOVING QUOTA"
                removeQuota()
            }
        }

        stage('GET QUOTAS') {
            steps {
                echo "GETTING QUOTAS FOR ALL NS"
                getQuotas()
            }
            post {
                always{
                    archiveArtifacts allowEmptyArchive: true, artifacts: '*quotas.txt', followSymlinks: false
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

def addQuota(){
    sh "kubectl --kubeconfig ./admin.conf get LimitRange limit-range --namespace ${params.NAMESPACE} || kubectl --kubeconfig ./admin.conf apply -f jenkins/templates/limit-range.yaml --namespace ${params.NAMESPACE}"
    sh """
        mkdir -p  tmp
        cp jenkins/templates/quota.yaml tmp/quota.yaml
        sed -i "s/req_cpu/${params.CPU_REQ_QUOTA}/g" tmp/quota.yaml
        sed -i "s/limit_cpu/${params.CPU_LIMIT_QUOTA}/g" tmp/quota.yaml
        sed -i "s/req_mem/${params.MEM_REQ_QUOTA}/g" tmp/quota.yaml
        sed -i "s/limit_mem/${params.MEM_LIMIT_QUOTA}/g" tmp/quota.yaml
        kubectl --kubeconfig ./admin.conf apply -f tmp/quota.yaml --namespace ${params.NAMESPACE}
        rm tmp/quota.yaml
    """
}

def removeQuota(){
    sh "kubectl --kubeconfig ./admin.conf get LimitRange limit-range --namespace ${params.NAMESPACE} && kubectl --kubeconfig ./admin.conf delete LimitRange limit-range --namespace ${params.NAMESPACE}"
    sh "kubectl --kubeconfig ./admin.conf get ResourceQuota resource-quota --namespace ${params.NAMESPACE} && kubectl --kubeconfig ./admin.conf delete ResourceQuota resource-quota  --namespace ${params.NAMESPACE}"
}

def getQuotas(){
    echo "ListQuotas"
    sh "kubectl --kubeconfig ./admin.conf get ResourceQuota -A > ${params.KUBECONFIG_FILE.split("-|_")[0]}-quotas.txt"
}