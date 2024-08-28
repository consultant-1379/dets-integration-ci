#!/usr/bin/env groovy

def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"
pipeline {
    agent {
        label env.SLAVE_LABEL
    }

    environment {
        AMS_URL = 'https://ams-dev.stsoss.seli.gic.ericsson.se/api/booking/'
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '15', artifactNumToKeepStr: '15'))
    }

    parameters {
        choice(
            name: 'ACTION',
            choices: ['get','add', 'remove',],
            description: 'Do you want to add or remove users to specific cluster'
        )
        string(name: 'BOOKED_FOR',defaultValue: 'egajada,qradpol',description: 'Comma separated list of user for which booking is made')
        string(name: 'NAMESPACE', defaultValue: 'eric-eiap', description: 'Booked namespce', trim: true)
        string(name: 'JIRA_ID', defaultValue: 'JIRA ID', description: 'JIRA ID')
        string(name: 'EIC_VERSION', defaultValue: 'not set yet', description: 'EIC version')
        string(name: 'APP_SET', defaultValue: 'not set yet', description: 'App set')
        string(name: 'START_DATE', defaultValue: '12-01-2023',description: 'BOOKING starts this day')
        string(name: 'END_DATE', defaultValue: '12-01-2023',description: 'BOOKING ends this day')
        string(name: 'KUBECONFIG_FILE', defaultValue: 'hall144_kubeconfig', description: 'Kubernetes configuration file to specify which environment to manage' )
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')

        string(
            name: 'TEAM_NAME',
            defaultValue: 'TEaaS-support',
            description: 'Booking team name'
        )

        string(
            name: 'BOOKED',
            defaultValue: 'true',
            description: 'The booking status of the namespace'
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

        stage('ADD Booking') {
            when {
                equals(actual: params.ACTION , expected: "add")
            }
            steps {
                echo "ADDING Booking information"
                listUsers()
                addBooking()
            }
        }

        stage('REMOVE Booking') {
            when {
                equals(actual: params.ACTION , expected: "remove")
            }
            steps {
                echo "REMOVING Booking info"
                listUsers()
                removeBooking()
            }
        }


        stage('GET Booking info') {
            steps {
                getBooking()
            }
            post {
                always{
                    archiveArtifacts allowEmptyArchive: true, artifacts: '*bookings.txt', followSymlinks: false
                }
            }
        }

        stage('Update AMS Booking') {
            when {
                equals(actual: params.ACTION , expected: "add")
            }
            steps {
                echo "ADDING Booking information to AMS"
                updateAmsBooking()
            }
        }

    }
    post {
        always{
            cleanWs disableDeferredWipeout: true
        }
    }
}

def addBooking(){
    sh "kubectl --kubeconfig ./admin.conf annotate --overwrite namespace ${NAMESPACE} booked=\"${BOOKED}\" "
    sh """
        kubectl --kubeconfig ./admin.conf get ns bookings || kubectl --kubeconfig ./admin.conf create ns bookings
        cat ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt | awk '/admins:/{ f = 1; next } /cluster/{ f = 0 } f' > users.txt
        annotateUsers="\$(cat ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt | awk '/admins:/{ f = 1; next } /cluster/{ f = 0 } f' | tr '\\n' ',')"
        kubectl --kubeconfig ./admin.conf create configmap ${params.NAMESPACE} -n bookings --from-file=users.txt --dry-run=client -o yaml | kubectl --kubeconfig ./admin.conf  apply -f -
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings users=\"\$annotateUsers\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings booking-start=\"${START_DATE}\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings booking-end=\"${END_DATE}\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings booked-for=\"${BOOKED_FOR}\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE} -n bookings team-name=\"${TEAM_NAME}\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE} -n bookings booked=\"${BOOKED}\"
    """
}

def updateAmsBooking(){

    def response = sh(script: "curl -k -X GET -u admin:admin -H \"Content-Type: application/json\" ${AMS_URL}${namespace}/", returnStdout: true).trim()

    if (response == '{"detail":"No booking found with this namespace."}') {

        sh """
            echo "Booking does not exist - Creating AMS Booking for namespace ${NAMESPACE}"
            curl -k -X POST -u admin:admin -H "Content-Type: application/json" -d '{"namespace": \"${NAMESPACE}\", "jira_id": \"${JIRA_ID}\", "team": \"${TEAM_NAME}\", "fqdn": "fqdn Test", "eic_version": \"${EIC_VERSION}\", "booking_start_date": \"${START_DATE}\", "booking_end_date": \"${END_DATE}\", "app_set": \"${APP_SET}\"}' ${AMS_URL}

        """
    } else {

        sh """
            echo 'Booking Already exists - Updating AMS Booking'
            curl -k -X PATCH -u admin:admin -H "Content-Type: application/json" -d '{"jira_id": \"${JIRA_ID}\", "fqdn": "fqdn Test", "eic_version": \"${EIC_VERSION}\", "booking_start_date": \"${START_DATE}\", "booking_end_date": \"${END_DATE}\", "app_set": \"${APP_SET}\"}' ${AMS_URL}${NAMESPACE}/
        """
    }
}

def removeBooking(){
   sh """
        cat ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt | awk '/admins:/{ f = 1; next } /cluster/{ f = 0 } f' > users.txt
        kubectl --kubeconfig ./admin.conf create configmap ${params.NAMESPACE} -n bookings --from-file=users.txt --dry-run=client -o yaml | kubectl --kubeconfig ./admin.conf  apply -f -
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings users=\"\$annotateUsers\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings booking-start=\"N/A\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings booking-end=\"N/A\"
        kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${params.NAMESPACE}  -n bookings booked-for=\"N/A\"
        sleep 30
        kubectl --kubeconfig ./admin.conf delete configmap ${params.NAMESPACE} -n bookings
   """

}

def getBooking(){
    echo "List user for ${params.NAMESPACE} namespace"
    sh """ kubectl --kubeconfig ./admin.conf  get configmap -n bookings | cut -d \" \" -f1 | grep -v NAME | xargs kubectl --kubeconfig ./admin.conf  describe configmap -n bookings  | grep -v \"Namespace\" | grep -v crt | grep -v txt | grep -e \"Name\" -e \"users\" -e \"book\" -e \"version\" > ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-bookings.txt
    """
}

def listUsers(){
    echo "List user for ${params.NAMESPACE} namespace"
    sh "echo 'Namespace ${params.NAMESPACE} admins:' > ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
    sh "kubectl --kubeconfig ./admin.conf get rolebinding -A | grep admin-${params.NAMESPACE} | cut -d\' \' -f1 |awk -F \"admin-${params.NAMESPACE}-\" \'{print\$2}\' >> ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
    sh "echo 'cluster Admins:' >> ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
    sh "kubectl --kubeconfig ./admin.conf get clusterrolebindings | grep admin-cluster- | cut -d\' \' -f 1| cut -d\'-\' -f3 >> ${params.KUBECONFIG_FILE.split("-|_")[0]}-${NAMESPACE}-userlist.txt"
}
