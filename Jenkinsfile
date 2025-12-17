pipeline {
    agent any
    environment {
        // --- CONFIGURATION ---
        // MANDATORY: The internal DNS name and port 8085
        REGISTRY_URL = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
        
        IMAGE_NAME = "carbon-emission-app"
        NAMESPACE = "2401129"  // Your Roll Number
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
                // We use the 'dind' container to ensure docker commands work
                container('dind') {
                    script {
                        withCredentials([usernamePassword(credentialsId: "${NEXUS_CRED_ID}", usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                            // 1. Login
                            sh "docker login -u ${NEXUS_USER} -p ${NEXUS_PASS} ${REGISTRY_URL}"
                            
                            // 2. Build the image
                            sh "docker build -t ${REGISTRY_URL}/${IMAGE_NAME}:v1 ."
                            
                            // 3. Push the image
                            sh "docker push ${REGISTRY_URL}/${IMAGE_NAME}:v1"
                        }
                    }
                }
            }
        }
        stage('Deploy to K8s') {
            steps {
                // Apply the Kubernetes manifests
                sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
            }
        }
    }
}