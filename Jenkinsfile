pipeline {
    agent any
    environment {
        // --- CONFIGURATION ---
        REGISTRY_URL = "nexus.imcc.com:8085"
        INTERNAL_HOST = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local"
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
                        echo "Configuring Docker to allow insecure HTTP registry..."
                        sh 'mkdir -p /etc/docker'
                        sh 'echo "{ \\"insecure-registries\\": [\\"nexus.imcc.com:8085\\"] }" > /etc/docker/daemon.json'
                        sh 'kill -SIGHUP $(pidof dockerd)'
                        sh 'sleep 5'
                        
                        def internalIP = sh(script: "getent hosts ${INTERNAL_HOST} | awk '{ print \$1 }'", returnStdout: true).trim()
                        sh "echo '${internalIP} nexus.imcc.com' >> /etc/hosts"
                        
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
                    // FIX: Create the namespace. '|| true' ignores the error if it already exists.
                    sh "./kubectl create namespace ${NAMESPACE} || true"
                    
                    echo "--- Deploying to Kubernetes ---"
                    sh "./kubectl apply -f k8s/ -n ${NAMESPACE}"
                }
            }
        }
    }
}