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
        string(name: 'CLUSTER_NAME', defaultValue: 'All', description: 'You can override this with cluster name. KaaS cluster name ie. hall144')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')
        string(name: 'EMAIL_LIST', defaultValue: 'adam.gajak@ericsson.com,gary.wheeler@ericsson.com,trupti.zalkikar@ericsson.com,ilir.koci.ext@ericsson.com', description: 'List of emails which will be notified about this job pending')
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
                listSetup()	
                archiveArtifacts allowEmptyArchive: true, artifacts: 'deletion_list.txt', followSymlinks: false 
            }
        }

        stage('Confirmation Satge') {
            steps {
                timeout(time: 7, unit: 'HOURS') {
                    mail to: "${params.EMAIL_LIST}",
                        subject: "[JENKINS-STOSS] Namespace deletion notification",
                        body: "List: \n${DELETION_LIST}  \n\nLink to job: \n ${BUILD_URL} "
                    input message: "${DELETION_LIST}", ok: 'DELETE NAMESPACES'
                }              
            }
        }


	    stage('Delete obsolete namespaces') {
	        steps {                  
                cleanUp()    
		    }
	    }
    }
    post {
        always{
            cleanWs disableDeferredWipeout: true
        }
    }
}

def getNamespaces(String deployment_name){
    sh """
        rm -f ns_list.txt
        rm -f cleanKaaSNSwhiteList.txt
        kubectl --kubeconfig ./${deployment_name}_admin.conf  get ns | grep -v NAME | cut -d " " -f1 > ns_list.txt
        cat jenkins/templates/cleanKaaSNSwhiteList.txt > cleanKaaSNSwhiteList.txt
        echo "\n" >> cleanKaaSNSwhiteList.txt
        kubectl --kubeconfig ./${deployment_name}_admin.conf  get configmap -n bookings | grep -v NAME | cut -d " " -f1  >> cleanKaaSNSwhiteList.txt 
        sort cleanKaaSNSwhiteList.txt > sorted_cleanKaaSNSwhiteList.txt
        sort ns_list.txt > sorted_ns_list.txt
        comm -13 sorted_cleanKaaSNSwhiteList.txt sorted_ns_list.txt > ${deployment_name}_ns_toDelete.txt
        echo "${deployment_name}: " >> deletion_list.txt
        cat ${deployment_name}_ns_toDelete.txt >> deletion_list.txt
    """
     env.DELETION_LIST = sh(script: "cat deletion_list.txt", returnStdout: true).trim()
}



def deleteNamespaces(String deployment_name){
    sh"""
        echo "Deleting Namespaces"
        for i in \$(cat ${deployment_name}_ns_toDelete.txt)
        do 
            kubectl --kubeconfig ./${deployment_name}_admin.conf delete ns \$i
        done 
    """
}



def listSetup(){

    if ("${params.CLUSTER_NAME}" == "All"){
        deployments = sh(returnStdout: true, script: "cat jenkins/templates/KaaSclusterList.txt")
        deployments.split('\n').each{ deployment ->
            withCredentials([file(credentialsId: "${deployment}_kubeconfig", variable: "KUBECONFIG")]) {
                sh """install -m 600 ${KUBECONFIG} ./${deployment}_admin.conf"""
            }
            getNamespaces("${deployment}")
        }

    }else{
        withCredentials([file(credentialsId: "${params.CLUSTER_NAME}_kubeconfig", variable: "KUBECONFIG")]) {
                sh """install -m 600 ${KUBECONFIG} ./${params.CLUSTER_NAME}_admin.conf"""
            }
        getNamespaces("${params.CLUSTER_NAME}")
    }
}

def cleanUp(){
    if ("${params.CLUSTER_NAME}" == "All"){
        deployments = sh(returnStdout: true, script: "cat jenkins/templates/KaaSclusterList.txt")
        deployments.split('\n').each{ deployment ->
            deleteNamespaces("${deployment}")
        }

    }else{
        sh"""
            echo "====================== NAMESPACEs TO DELETE ==============================="
            cat ${params.CLUSTER_NAME}_ns_toDelete.txt
        """
        deleteNamespaces("${params.CLUSTER_NAME}")
    }

}
