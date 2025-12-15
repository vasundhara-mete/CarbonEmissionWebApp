pipeline {
    agent any
    environment {
        // CORRECT COLLEGE URL
        REGISTRY_URL = "nexus.imcc.com" 
        IMAGE_NAME = "carbon-emission-app"
        // YOUR ROLL NUMBER
        NAMESPACE = "2401129"
        // CREDENTIAL ID (Ask instructor if this ID is different, usually 'nexus-credentials')
        NEXUS_CRED_ID = "nexus-credentials" 
    }
    stages {
        stage('Build') {
            steps {
                echo 'Using exported ROOT.war...'
            }
        }
        stage('Docker Build & Push') {
            steps {
                script {
                    // Securely logs in to Nexus using Jenkins credentials
                    withCredentials([usernamePassword(credentialsId: "${NEXUS_CRED_ID}", usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                        sh "docker login -u ${NEXUS_USER} -p ${NEXUS_PASS} ${REGISTRY_URL}"
                        docker.build("${REGISTRY_URL}/${IMAGE_NAME}:v1").push()
                    }
                }
            }
        }
        stage('Deploy to K8s') {
            steps {
                sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
            }
        }
    }
}