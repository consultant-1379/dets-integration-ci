#!/usr/bin/env groovy

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"
pipeline {
    agent {
        label env.SLAVE_LABEL
    }

    environment {
        AMS_URL = 'https://ams-dev.stsoss.seli.gic.ericsson.se/api/booking/'
    }

    parameters {
        string(name: 'NAMESPACE', defaultValue: 'eric-eiap', description: 'Namespace to purge environment')
        string(name: 'CRD_NAMESPACE', description: 'CRD Namespace to purge ')
        string(name: 'KUBECONFIG_FILE', defaultValue: 'kubeconfig', description: 'Kubernetes configuration file to specify which environment purge' )
        string(name: 'IDUN_USER_SECRET', defaultValue: 'idun_user', description: 'Jenkins secret ID for default IDUN user password')
        string(name: 'ARMDOCKER_USER_SECRET', defaultValue: 'detsuser_docker', description: 'ARM Docker secret')
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')
        string(name: 'DOCKER_REGISTRY',defaultValue: 'armdocker.rnd.ericsson.se',description: 'Set this to the docker registry to execute the deployment from. Used when deploying from Officially Released CSARs')
        booleanParam(name: 'REMOVE_BOOKED_ANNOTATION', defaultValue: false, description: 'Specify if the environment should be torn down, details removed from ams, namespace admins and annotations removed')
        string(
            name:         'GIT_BRANCH_TO_USE',
            defaultValue: 'master',
            description:  'Put refs/heads/${GIT_BRANCH_TO_USE} in the job configuration for the git branch'
        )
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
        stage('Cleanup Kubernetes Resources') {
            steps {
                sh returnStatus: true, script: "timeout 60  kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete deployment         --all"
                sh returnStatus: true, script: "timeout 60  kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete statefulset        --all"
                sh returnStatus: true, script: "timeout 60  kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete pod                --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete pod --force --grace-period=0 --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete all                --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete sa                 --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete secret             --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete role               --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete netpol             --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete destinationrule    --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete virtualservices    --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete peerauthentication --all"
                sh returnStatus: true, script: "            kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete configmaps         --all"
                sh returnStatus: true, script: "timeout 600 kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete pvc                --all"
                sh returnStatus: true, script: "timeout 300 kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete kafkatopic         --all"
            }
        }
        //Removing all rolebindings except the one's beginning with admin-<namesapce> (created using automation)
        stage('Delete Rolebindings') {
            steps {
                sh"""
                kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} get rolebinding | \
                    grep -v "^admin-${env.NAMESPACE}" | \
                    awk '{print \$1}' | \
                    grep -v "NAME" | \
                    xargs -r -I xxx kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} delete rolebinding xxx
                """
            }
        }
        stage('Delete potentially stuck PVCs') {
            steps {
                sh"""
                kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} get pvc | \
                    grep Terminating | \
                    awk '{print \$1}' | \
                    xargs -r -I xxx kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} patch pvc xxx -p '{"metadata":{"finalizers":null}}'
                """
            }
        }
        stage('Delete potentially stuck PVs') {
            steps {
                sh returnStatus: true, script:"""
                kubectl --kubeconfig ./admin.conf get pv | \
                    grep ${env.NAMESPACE} | \
                    awk '{print \$1}' | \
                    xargs -r -I xxx timeout 30 kubectl --kubeconfig ./admin.conf delete pv xxx
                """
                sh returnStatus: true, script:"""
                kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} get pv | \
                    grep Terminating | \
                    awk '{print \$1}' | \
                    xargs -r -I xxx kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} patch pv xxx -p '{"metadata":{"finalizers":null}}'
                """
            }
        }
        stage('Delete potentially stuck KafkaTopics') {
            steps {
                sh returnStatus: true, script:"""
                kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} get kafkatopic -o json \
                    | jq '.items[].metadata.finalizers=null' \
                    | kubectl --kubeconfig ./admin.conf --namespace ${env.NAMESPACE} apply -f -
                """
            }
        }
        stage('Remove Network Policies') {
            steps {
                    sh "${bob} remove-network-policies"
            }
        }

        stage('Remove secrets & cluster rolebindings') {
            steps {
                // Namespace scoped resources
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf -n ${params.NAMESPACE}     get secret k8s-registry-secret-legacy                           && kubectl --kubeconfig ./admin.conf -n ${params.NAMESPACE}     delete secret k8s-registry-secret-legacy"
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf -n ${params.CRD_NAMESPACE} get secret k8s-registry-secret-legacy                           && kubectl --kubeconfig ./admin.conf -n ${params.CRD_NAMESPACE} delete secret k8s-registry-secret-legacy"
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf -n ${params.NAMESPACE}     get secret k8s-registry-secret                                  && kubectl --kubeconfig ./admin.conf -n ${params.NAMESPACE}     delete secret k8s-registry-secret"
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf -n ${params.CRD_NAMESPACE} get secret k8s-registry-secret                                  && kubectl --kubeconfig ./admin.conf -n ${params.CRD_NAMESPACE} delete secret k8s-registry-secret"
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf -n ${params.NAMESPACE}     get secret eric-odca-diagnostic-data-collector-sftp-credentials && kubectl --kubeconfig ./admin.conf -n ${params.NAMESPACE}     delete secret eric-odca-diagnostic-data-collector-sftp-credentials"

                // Cluster wide scoped resources
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf get clusterrolebinding ${params.NAMESPACE}     && kubectl --kubeconfig ./admin.conf delete clusterrolebinding ${params.NAMESPACE}"
/*              sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf get      namespace     ${params.NAMESPACE}     && kubectl --kubeconfig ./admin.conf delete      namespace     ${params.NAMESPACE}"
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf get      namespace     ${params.CRD_NAMESPACE} && kubectl --kubeconfig ./admin.conf delete      namespace     ${params.CRD_NAMESPACE}"
*/
            }
        }

        stage('Remove namespace booked annotation') {
            when {
            expression { params.REMOVE_BOOKED_ANNOTATION == true }
            }
            steps {
                sh returnStatus: true, script: "kubectl --kubeconfig ./admin.conf annotate --overwrite namespace ${NAMESPACE} booked=false"
            }
        }

        stage('Remove AMS Booking') {
            when {
            expression {params.REMOVE_BOOKED_ANNOTATION == true}
            }
            steps {
                echo "Removing Booking information from AMS"
                removeAmsBooking()
            }
        }

        stage('Remove Namespace Admins') {
            when {
            expression {params.REMOVE_BOOKED_ANNOTATION == true}
            }
            steps {
                echo "Removing Namespace Admins"
                removeNamespaceAdmins()
            }
        }
    }
}

def removeAmsBooking(){

def response = sh(script: "curl -k -X DELETE -u admin:admin -H \"Content-Type: application/json\" ${AMS_URL}${namespace}/", returnStdout: true).trim()
echo "Response from AMS: ${response}"

}

def removeNamespaceAdmins(){

    def namespaceAdmins = sh(script: """
    (kubectl --kubeconfig ./admin.conf get clusterrolebindings --sort-by .metadata.creationTimestamp | grep admin-pv; \
    kubectl --kubeconfig ./admin.conf get rolebindings -A | grep admin) | \
    grep ${env.NAMESPACE} | \
    awk '{split(\$2,a,"-"); printf a[6] ","}' | \
    sed 's/,\$//'
    """, returnStdout: true).trim()

    build job: 'KaaS_manage_cluster_users', parameters: [
                string(name: 'ACTION', value: "removeNamespaceAdmins"),
                string(name: 'USERS', value: "${namespaceAdmins}"),
                string(name: 'NAMESPACE', value: "${env.NAMESPACE}"),
                string(name: 'KUBECONFIG_FILE', value: "${KUBECONFIG_FILE}"),
                string(name: 'SLAVE_LABEL', value: "cENM")]
    echo "Namespace Admins removed: ${namespaceAdmins} from namespace ${env.NAMESPACE}"
}
