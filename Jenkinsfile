pipeline {
    agent any
    environment {
        // --- CONFIGURATION ---
        // USE THE REAL INTERNAL HOST (No more spoofing)
        REGISTRY_URL = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
        
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
                        echo "Configuring Docker to allow insecure INTERNAL registry..."
                        sh 'mkdir -p /etc/docker'
                        
                        // FIX: Whitelist the INTERNAL address in daemon.json
                        sh 'echo "{ \\"insecure-registries\\": [\\"nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085\\"] }" > /etc/docker/daemon.json'
                        
                        sh 'kill -SIGHUP $(pidof dockerd)'
                        sh 'sleep 5'
                        
                        withCredentials([usernamePassword(credentialsId: "${NEXUS_CRED_ID}", usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                            sh "docker login -u ${NEXUS_USER} -p ${NEXUS_PASS} ${REGISTRY_URL}"
                            sh "docker build -t ${REGISTRY_URL}/${IMAGE_NAME}:v1 ."
                            sh "docker push ${REGISTRY_URL}/${IMAGE_NAME}:v1"
                        }
                    }
                }
            }
        }
        stage('Deploy to K8s') {
            steps {
                script {
                    echo "--- Installing kubectl temporarily ---"
                    sh "curl -LO https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
                    sh "chmod +x ./kubectl"
                    
                    echo "--- Creating Namespace if missing ---"
                    sh "./kubectl create namespace ${NAMESPACE} || true"
                    
                    echo "--- Deploying to Kubernetes ---"
                    sh "./kubectl apply -f k8s/ -n ${NAMESPACE}"
                    
                    echo "--- FORCING RESTART (To pick up new image) ---"
                    sh "./kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                }
            }
        }
    }
}