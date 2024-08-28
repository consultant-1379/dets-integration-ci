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
	string(
	    name: 'DEPLOYMENT_NAME',
	    defaultValue: 'hallXXX',
	    description: 'Deployment name - must match with the name created in bucket \"eiap\" in MiniIO'
	)
        choice(
            name: 'DEPLOYMENT_TYPE',
            choices: ['install', 'upgrade'],
            description: 'Deployment Type, set \"install\" or \"upgrade\"'
        )
        string(
            name: 'NAMESPACE',
            defaultValue: 'eric-eiap',
            description: 'Namespace to install the Chart'
        )
        string(
            name: 'TEAM_NAME',
            defaultValue: 'TEaaS-support',
            description: 'Booking team name'
        )
        string(
            name: 'DOMAIN',
            defaultValue: '.<sample>-eiap.ews.gic.ericsson.se',
            description: 'DOMAIN in which hostname should be resolved'
        )
        string(
            name: 'KUBECONFIG_FILE',
            defaultValue: '<sample>_kubeconfig',
            description: 'Kubernetes configuration file to specify which environment to install on (secret_id)'
        )
        string(
            name: 'TAGS',
            defaultValue: 'so pf uds adc th dmm appmgr ch ta eas os',
            description: 'List of tags for applications that have to be deployed, e.g: so adc pf'
        )
        string(
            name: 'INT_CHART_VERSION',
            defaultValue: '2.2.0-82',
            description: 'The version of base platform to install'
        )
        string(
            name: 'BOOKED',
            defaultValue: 'true',
            description: 'The booking status of the namespace'
        )

    }
    environment {
        USE_TAGS = 'true'
        STATE_VALUES_FILE = "site_values_${params.INT_CHART_VERSION}.yaml"
        CSAR_STORAGE_URL = 'https://arm.seli.gic.ericsson.se/artifactory/proj-eric-oss-drop-generic-local/csars/'
        PATH_TO_HELMFILE = "${params.INT_CHART_NAME}/helmfile.yaml"
        CSAR_STORAGE_INSTANCE = 'arm.seli.gic.ericsson.se'
        CSAR_STORAGE_REPO = 'proj-eric-oss-drop-generic-local'
        FETCH_CHARTS = 'true'
    }
    stages {
        stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} ${params.NAMESPACE} ${params.KUBECONFIG_FILE.split("-|_")[0]} - ${params.DEPLOYMENT_TYPE}"
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



        stage ('Annotate namespace'){
	        steps {
                withCredentials([file(credentialsId: params.KUBECONFIG_FILE, variable: 'KUBECONFIG')]) {
                    sh "install -m 600 ${KUBECONFIG} ./admin.conf"
                }
	            sh "${bob} annotate-namespace-installed-helmfile"
                sh "kubectl --kubeconfig ./admin.conf annotate --overwrite namespace ${NAMESPACE} eiap-version=\"${INT_CHART_VERSION}\" "
                sh "kubectl --kubeconfig ./admin.conf annotate --overwrite namespace ${NAMESPACE} booked=\"${BOOKED}\" "
                echo "Booking Status = \"${BOOKED}\""
                sh """
                    kubectl --kubeconfig ./admin.conf get ns bookings || kubectl --kubeconfig ./admin.conf create ns bookings
                    kubectl --kubeconfig ./admin.conf get configmap ${NAMESPACE} -n bookings || { touch users.txt; kubectl --kubeconfig ./admin.conf create configmap ${NAMESPACE} -n bookings --from-file=users.txt; }
                    kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${NAMESPACE} -n bookings eiap-version=\"${INT_CHART_VERSION}\"
                    kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${NAMESPACE} -n bookings eo-version=\"N/A\"
                    kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${NAMESPACE} -n bookings domain=\"${DOMAIN}\"
                    kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${NAMESPACE} -n bookings tags=\"${TAGS}\"
                    kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${NAMESPACE} -n bookings team-name=\"${TEAM_NAME}\"
                    kubectl --kubeconfig ./admin.conf annotate --overwrite configmap ${NAMESPACE} -n bookings booked=\"${BOOKED}\"
                """
                echo "ENABLE federation to dets-monitoring"
                sh "kubectl --kubeconfig ./admin.conf apply -f jenkins/templates/networkPolicyMonitoring.yaml -n ${NAMESPACE}"
	        }
        }

        stage ('POSTCHECK'){

            steps{
                echo "Running postcheck"
                withCredentials([file(credentialsId: params.KUBECONFIG_FILE, variable: 'KUBECONFIG')]) {
                    sh "install -m 600 ${KUBECONFIG} ./admin.conf"
                }
                sh "jenkins/scripts/eiap_postcheck.sh admin.conf ${NAMESPACE} ${DOMAIN}"
            }
        }

    }
    post{
        always{
            archiveArtifacts allowEmptyArchive: true, artifacts: "postcheck_logs.txt", followSymlinks: false
            cleanWs disableDeferredWipeout: true
        }
    }
}
