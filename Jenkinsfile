pipeline {
    agent any
    environment {
        // --- CONFIGURATION ---
        REGISTRY_URL = "nexus.imcc.com:8085"
        
        // The real internal host you found
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
                        // --- STEP 1: FORCE INSECURE REGISTRY ---
                        echo "Configuring Docker to allow insecure HTTP registry..."
                        
                        // FIX: Create the directory first!
                        sh 'mkdir -p /etc/docker'
                        
                        // 1. Create the daemon.json file
                        sh 'echo "{ \\"insecure-registries\\": [\\"nexus.imcc.com:8085\\"] }" > /etc/docker/daemon.json'
                        
                        // 2. Reload Docker to apply changes (Sending SIGHUP signal)
                        sh 'kill -SIGHUP $(pidof dockerd)'
                        
                        // 3. Wait 5 seconds for Docker to restart
                        sh 'sleep 5'
                        
                        // --- STEP 2: DNS SPOOFING ---
                        def internalIP = sh(script: "getent hosts ${INTERNAL_HOST} | awk '{ print \$1 }'", returnStdout: true).trim()
                        echo "Internal IP is: ${internalIP}"
                        sh "echo '${internalIP} nexus.imcc.com' >> /etc/hosts"
                        
                        // --- STEP 3: LOGIN & BUILD ---
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
                sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
            }
        }
    }
}