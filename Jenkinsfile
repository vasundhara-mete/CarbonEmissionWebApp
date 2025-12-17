pipeline {
    agent any
    environment {
        // --- CONFIGURATION ---
        // MANDATORY: Must match the port 8082 in your deployment.yaml
        REGISTRY_URL = "192.168.25.11:8082" 
        
        IMAGE_NAME = "carbon-emission-app"
        NAMESPACE = "2401129"
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
                container('dind') {
                    script {
                        withCredentials([usernamePassword(credentialsId: "${NEXUS_CRED_ID}", usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                            // 1. Login
                            sh "docker login -u ${NEXUS_USER} -p ${NEXUS_PASS} ${REGISTRY_URL}"
                            
                            // 2. Build
                            sh "docker build -t ${REGISTRY_URL}/${IMAGE_NAME}:v1 ."
                            
                            // 3. Push
                            sh "docker push ${REGISTRY_URL}/${IMAGE_NAME}:v1"
                        }
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