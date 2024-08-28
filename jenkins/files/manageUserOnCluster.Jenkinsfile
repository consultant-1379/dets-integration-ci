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
            choices: ['get', 'add', 'remove', 'addAdmins', 'removeAdmins', 'addNamespaceAdmins', 'removeNamespaceAdmins'],
            description: 'Do you want to add or remove users to specific cluster'
        )
        string(
            name: 'USERS',
            defaultValue: 'egajada,qradpol',
            description: 'Comma separated '
        )
        string(
            name: 'NAMESPACE',
            defaultValue: 'eric-eiap',
            description: 'Namespace to limit user acces'
        )
        string(
            name: 'CRD_NAMESPACE',
            defaultValue: 'eric-crd-ns',
            description: 'CRD Namespace used by users'
        )
        string(
            name: 'KUBECONFIG_FILE',
            defaultValue: 'hall144_kubeconfig',
            description: 'Kubernetes configuration file to specify which environment to manage'
        )
        string(
            name: 'SLAVE_LABEL',
            defaultValue: 'cENM',
            description: 'Specify the slave label that you want the job to run on'
        )
        string(
            name: 'GIT_BRANCH_TO_USE',
            defaultValue: 'master',
            description: 'Put refs/heads/${GIT_BRANCH_TO_USE} in the job configuration for the git branch'
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

        stage('ADD CRB CLUSTEROLE') {
            when {
                equals(actual: params.ACTION , expected: "add")
            }
            steps {
                echo "Add CRB Clusterrole"
                sh"kubectl --kubeconfig ./admin.conf apply -f jenkins/templates/crb-role.yaml"
            }
        }

        stage('ADD CRB USERS') {
            when {
                equals(actual: params.ACTION , expected: "add")
            }
            steps {
                echo "Adding CRB users"
                addCrbUsers(params.USERS.split(','))
            }
        }

        stage('REMOVE CRB USERS') {
            when {
                equals(actual: params.ACTION , expected: "remove")
            }
            steps {
                echo "Removing CRB users"
                removeCrbUsers(params.USERS.split(','))
            }
        }

        stage('ADD CLUSTER ADMINS') {
            when {
                equals(actual: params.ACTION , expected: "addAdmins")
            }
            steps {
                echo "Adding cluster admin users"
                sh """jenkins/scripts/pooled_eic/manage_users.sh \
                            --kubeconfig ./admin.conf            \
                            --action ADD-CLUSTER-ADMINS          \
                            --users ${params.USERS}
                """
            }
        }

        stage('REMOVE CLUSTER ADMINS') {
            when {
                equals(actual: params.ACTION , expected: "removeAdmins")
            }
            steps {
                echo "Removing cluster admin users"
                sh """jenkins/scripts/pooled_eic/manage_users.sh \
                            --kubeconfig ./admin.conf            \
                            --action DEL-CLUSTER-ADMINS          \
                            --users ${params.USERS}
                """
            }
        }

        stage('ADD ADMINS OF NAMESPACE') {
            when {
                equals(actual: params.ACTION , expected: "addNamespaceAdmins")
            }
            steps {
                echo "Adding namesapce admin users"
                sh """jenkins/scripts/pooled_eic/manage_users.sh \
                            --kubeconfig ./admin.conf            \
                            --action ADD-NAMESPACE-USERS         \
                            --users ${params.USERS}              \
                            --namespace ${params.NAMESPACE}
                """
            }
        }

        stage('REMOVE ADMIN OF NAMESPACE') {
            when {
                equals(actual: params.ACTION , expected: "removeNamespaceAdmins")
            }
            steps {
                echo "Removing namesapce admin users"
                sh """jenkins/scripts/pooled_eic/manage_users.sh \
                            --kubeconfig ./admin.conf            \
                            --action DEL-NAMESPACE-USERS         \
                            --users ${params.USERS}              \
                            --namespace ${params.NAMESPACE}
                """
            }
        }

        stage('GET USERS') {
            steps {
                echo "GETTING USERLIST"
                listUsers()
                annotateUsers()
            }
            post {
                always{
                    archiveArtifacts allowEmptyArchive: true, artifacts: '*userlist.txt', followSymlinks: false
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

def addCrbUsers(userList){
     userList.each{ user ->
        echo "Adding ${user}"
        sh""" kubectl --kubeconfig ./admin.conf get clusterrolebinding read-all-ns-${user} && echo "user ${user} already exists" || {
                kubectl --kubeconfig ./admin.conf create clusterrolebinding read-all-ns-${user} --clusterrole=view --user=${user}
                kubectl --kubeconfig ./admin.conf create clusterrolebinding crb-admin-ns-${user} --clusterrole=crb-admin --user=${user}
                kubectl --kubeconfig ./admin.conf create rolebinding admin-${params.NAMESPACE}-${user} --clusterrole=cluster-admin  --user=${user} --namespace=${params.NAMESPACE}
                kubectl --kubeconfig ./admin.conf create rolebinding admin-${params.CRD_NAMESPACE}-${user} --clusterrole=cluster-admin --user=${user} --namespace=${params.CRD_NAMESPACE}
            }
        """
    }
}

def removeCrbUsers(userList){
     userList.each{ user ->
        echo "Removing ${user}"
        sh """kubectl --kubeconfig ./admin.conf get clusterrolebinding read-all-ns-${user} &&{
                kubectl --kubeconfig ./admin.conf delete clusterrolebinding read-all-ns-${user}
                kubectl --kubeconfig ./admin.conf delete clusterrolebinding crb-admin-ns-${user}
                kubectl --kubeconfig ./admin.conf delete rolebinding admin-${params.NAMESPACE}-${user} --namespace=${params.NAMESPACE}
                kubectl --kubeconfig ./admin.conf delete rolebinding admin-${params.CRD_NAMESPACE}-${user} --namespace=${params.CRD_NAMESPACE}
            } || echo "user ${user} does not exists"
        """
    }
}

def listUsers(){
    if ("${params.NAMESPACE}" == "") {
        NAMESPACE = "eric-eiap"
    }
    echo "List user for ${NAMESPACE} namespace"
    sh "echo 'Namespace ${NAMESPACE} admins:' > ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
    sh "kubectl --kubeconfig ./admin.conf get rolebinding -A | grep admin-${NAMESPACE}  |awk -F \"admin-${NAMESPACE}-\" \'{print\$2}\' | cut -d\' \' -f1 >> ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
    sh "echo 'cluster Admins:' >> ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
    sh "kubectl --kubeconfig ./admin.conf get clusterrolebindings | grep admin-cluster- | cut -d\' \' -f 1| cut -d\'-\' -f3 >> ${KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
}

def annotateUsers(){
    sh """
        cat ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt | awk '/admins:/{ f = 1; next } /cluster/{ f = 0 } f' > users.txt
        annotateUsers="\$(cat ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt | awk '/admins:/{ f = 1; next } /cluster/{ f = 0 } f' | tr '\n' ','| sed 's/.\$//')"
        kubectl --kubeconfig ./admin.conf get ns bookings || kubectl --kubeconfig ./admin.conf create ns bookings
        kubectl --kubeconfig ./admin.conf create configmap ${NAMESPACE} -n bookings --from-file=users.txt --dry-run=client -o yaml | kubectl --kubeconfig ./admin.conf  apply -f -
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${NAMESPACE}  -n bookings  users=\"\$annotateUsers\"
        cat ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt | awk '/Admins:/{ f = 1; next } /EOF/{ f = 0 } f' > clusterAdmin.txt
        annotateAdmin="\$(cat ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt | awk '/Admins:/{ f = 1; next } /EOF/{ f = 0 } f' | tr '\n' ','| sed 's/.\$//')"
        kubectl --kubeconfig ./admin.conf create configmap  cluster-admins -n bookings --from-file=clusterAdmin.txt --dry-run=client -o yaml | kubectl --kubeconfig ./admin.conf  apply -f -
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap cluster-admins -n bookings admin-users=\"\$annotateAdmin\"
    """
}
