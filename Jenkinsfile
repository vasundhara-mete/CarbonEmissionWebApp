pipeline {
    agent any
    environment {
        REGISTRY_URL = "nexus.imcc.com" 
        IMAGE_NAME = "carbon-emission-app"
        NAMESPACE = "<YOUR_ROLL_NO>" // Ensure this is your actual Roll Number
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
                // FIX: Run inside the 'dind' container which has the docker command
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
                // Note: If kubectl fails with "not found", we may need to wrap this in a container block too.
                // For now, let's assume the default agent has kubectl or the college set it up.
                sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
            }
        }
    }
}