def bob = "bob/bob -r \${WORKSPACE}/jenkins/rulesets/ruleset2.0.yaml"

pipeline {
    agent {
        label env.SLAVE_LABEL
    }
    environment  {
	MINIO_USER_SECRET = 'miniosecret'
    }
    parameters {
        string(name: 'SLAVE_LABEL', defaultValue: 'cENM', description: 'Specify the slave label that you want the job to run on')
	    string(name: 'NAMESPACE', defaultValue: 'dets-monitoring', description: 'Namespace to install Prometheus')
	    string(name: 'VERSION', defaultValue: '43.1.1', description: 'Prometheus version')
    }
    stages {
        stage('Set build name') {
            steps {
                script {
                    currentBuild.displayName = "${env.BUILD_NUMBER} Reinstall ${params.NAMESPACE} ${params.VERSION}"
                }
            }
        }
        stage('Trigger install Jobs') {
            steps {
                reinstallAll()

            }
        }
	}	
}

def reinstallAll() {
        deployments = sh(returnStdout: true, script: "cat jenkins/templates/KaaSclusterList.txt")
        deployments.split('\n').each{ deployment ->
            build job: 'KaaS_add_To_Monitoring', parameters: [string(name: 'DEPLOYMENT_NAME', value: "${deployment}"), string(name: 'SLAVE_LABEL', value: "${params.SLAVE_LABEL}"), string(name: 'NAMESPACE', value: "${params.NAMESPACE}" ), string(name: 'VERSION', value: "${params.VERSION}")]
        }
}