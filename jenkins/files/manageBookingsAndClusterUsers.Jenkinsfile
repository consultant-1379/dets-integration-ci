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
            choices: ['add', 'remove'],
            description: 'Do you want to add or remove users to specific cluster'
        )

        string(
            name: 'NAMESPACE',
            defaultValue: 'eric-eiap',
            description: 'Booked namespce'
        )

        string(
            name: 'CLUSTER_NAME',
            defaultValue: 'hall144',
            description: 'Cluster name'
        )

        string(
            name: 'USERS',
            defaultValue: 'egajada,qradpol',
            description: 'Comma separated '
        )

        string(
            name: 'START_DATE',
            defaultValue: '12-01-2023',
            description: 'BOOKING starts this day'
        )

        string(
            name: 'END_DATE',
            defaultValue: '12-01-2023',
            description: 'BOOKING ends this day'
        )

        string(
            name: 'JIRA_ID',
            defaultValue: 'JIRA_ID',
            description: 'Jira associated with the booking'
        )

        string(
            name: 'APP_SET',
            defaultValue: 'APP_SET',
            description: 'EIC apps to be installed'
        )

        string(
            name: 'TEAM_NAME',
            defaultValue: 'TEaaS-support',
            description: 'Booking team name'
        )

    }

    stages {

        stage('RUNNING KAAS MANAGE CLUSTER USERS') {
            steps {
                build job: 'KaaS_manage_cluster_users', parameters: [
                string(name: 'ACTION', value: "${params.ACTION}NamespaceAdmins"),
                string(name: 'USERS', value: "${params.USERS}"),
                string(name: 'NAMESPACE', value: "${params.NAMESPACE}"),
                string(name: 'KUBECONFIG_FILE', value: "${CLUSTER_NAME}_kubeconfig"),
                string(name: 'SLAVE_LABEL', value: "cENM")] //env and param
            }
        }

         stage('RUNNING KAAS MANAGE BOOKINGS') {
         when {expression { params.ACTION == 'add' }}
            steps {
                build job: 'KaaS_manage_BOOKINGS', parameters: [
                string(name: 'ACTION', value: "${params.ACTION}"),
                string(name: 'BOOKED_FOR', value: "${params.USERS}"),
                string(name: 'NAMESPACE', value: "${params.NAMESPACE}"),
                string(name: 'START_DATE', value: "${params.START_DATE}"),
                string(name: 'END_DATE', value: "${params.END_DATE}"),
                string(name: 'KUBECONFIG_FILE', value: "${CLUSTER_NAME}_kubeconfig"),
                string(name: 'SLAVE_LABEL', value: "cENM"), //env and param)
                string(name: 'TEAM_NAME', value: "${params.TEAM_NAME}"),
                string(name: 'JIRA_ID', value: "${params.JIRA_ID}"),
                string(name: 'APP_SET', value: "${params.APP_SET}"),
                string(name: 'BOOKED', value: "true")]
            }
        }

    }
}
