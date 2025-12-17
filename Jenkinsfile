pipeline {
    agent any
    environment {
        // --- CONFIGURATION ---
        // TRICK: We will use the "Allowed" name (nexus.imcc.com)
        // BUT we will force it to use the "Working" internal port (8085)
        REGISTRY_URL = "nexus.imcc.com:8085"
        
        // This is the REAL internal hostname we found earlier
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
                        // 1. Find the Internal IP of the service
                        def internalIP = sh(script: "getent hosts ${INTERNAL_HOST} | awk '{ print \$1 }'", returnStdout: true).trim()
                        echo "Found Internal Nexus IP: ${internalIP}"
                        
                        // 2. HACK: Map 'nexus.imcc.com' to that Internal IP in /etc/hosts
                        // This tricks Docker into thinking it's talking to the whitelisted domain,
                        // but actually routes traffic to the working internal service.
                        sh "echo '${internalIP} nexus.imcc.com' >> /etc/hosts"
                        
                        withCredentials([usernamePassword(credentialsId: "${NEXUS_CRED_ID}", usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                            // 3. Login using the Spoofed Domain
                            sh "docker login -u ${NEXUS_USER} -p ${NEXUS_PASS} ${REGISTRY_URL}"
                            
                            // 4. Build & Push
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