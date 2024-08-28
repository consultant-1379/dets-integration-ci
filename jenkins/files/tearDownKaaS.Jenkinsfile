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
    parameters {
        string(name: 'CLUSTER_NAME', defaultValue: 'hallXXX', description: 'KaaS cluster name ie. hall144')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')
    }
    stages {
        stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} ${params.CLUSTER_NAME}"
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
        stage('List curent setup') {
            steps {

                withCredentials([file(credentialsId: "${params.CLUSTER_NAME}_kubeconfig", variable: "KUBECONFIG")]) {
                    sh 'install -m 600 ${KUBECONFIG} ./admin.conf'
                }
                getNamespaces()
                getCRDs()
            }
        }

	    stage('Delete obsolete namespaces and crds') {
	        steps {

                sh"""
                echo "====================== NAMESPACEs TO DELETE ==============================="
                cat ns_toDelete.txt
                echo "====================== CRDs TO DELETE ==============================="
                cat crd_toDelete.txt
                """
                input "Are you sure you want to teardown $CLUSTER_NAME cluster"
                deleteNamespaces()
                deleteCRDs()
	        
		    }
	    }
    }
    post {
        always{
            cleanWs disableDeferredWipeout: true
        }
    }
}

def getNamespaces(){
    sh """
        kubectl --kubeconfig ./admin.conf  get ns | grep -v NAME | cut -d " " -f1 | sort > ns_list.txt
        sort jenkins/templates/cleanKaaSNSwhiteList.txt > sorted_cleanKaaSNSwhiteList.txt
        comm -13 sorted_cleanKaaSNSwhiteList.txt ns_list.txt > ns_toDelete.txt
    """
}

def getCRDs(){
    sh """
        kubectl --kubeconfig ./admin.conf get crd | grep -v NAME | cut -d " " -f1 | sort > crd_list.txt
        sort jenkins/templates/cleanKaaSCRDwhiteList.txt > sorted_cleanKaaSCRDwhiteList.txt
        comm -13 sorted_cleanKaaSCRDwhiteList.txt crd_list.txt > crd_toDelete.txt
    """
}

def deleteNamespaces(){
    sh"""
        echo "Deleting Namespaces"
        for i in \$(cat ns_toDelete.txt)
        do 
            kubectl --kubeconfig ./admin.conf delete ns \$i
        done 
    """
}

def deleteCRDs(){
    sh"""
        echo "Deleting crds"
        for i in \$(cat crd_toDelete.txt)
        do 
            kubectl --kubeconfig ./admin.conf delete crd \$i
        done 
    """
}