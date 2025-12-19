pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: dind
    image: docker:dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    volumeMounts:
    - name: docker-config
      mountPath: /etc/docker/daemon.json
      subPath: daemon.json
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["cat"]
    tty: true
    securityContext:
      runAsUser: 0
    env:
    - name: KUBECONFIG
      value: /kube/config
    volumeMounts:
    - name: kubeconfig-secret
      mountPath: /kube/config
      subPath: kubeconfig
  volumes:
  - name: docker-config
    configMap:
      name: docker-daemon-config
  - name: kubeconfig-secret
    secret:
      secretName: kubeconfig-secret
'''
        }
    }
    options { skipDefaultCheckout() }
    environment {
        IMAGE_NAME     = "carbon-emission-app"
        NAMESPACE      = "2401129"
        // Separate Hostname and Port to prevent DNS errors
        NEXUS_DOMAIN   = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local"
        NEXUS_PORT     = "8085"
    }
    stages {
        // --- STAGE 1: CHECKOUT ---
        stage('Checkout') {
            steps {
                deleteDir()
                sh "git clone https://github.com/vasundhara-mete/CarbonEmissionWebApp.git ." 
            }
        }

        // --- STAGE 2: SONARQUBE ---
        stage('SonarQube Analysis') {
            steps {
                container('dind') {
                    script {
                        timeout(time: 1, unit: 'MINUTES') {
                            waitUntil {
                                try { sh 'docker info >/dev/null 2>&1'; return true } 
                                catch (Exception e) { sleep 5; return false }
                            }
                        }
                        sh """
                            docker run --rm \
                                -v "\$PWD/app:/usr/src" \
                                sonarsource/sonar-scanner-cli \
                                -Dsonar.projectBaseDir=/usr/src
                        """
                    }
                }
            }
        }

        // --- STAGE 3: DOCKER ---
        stage('Docker Build') {
            steps {
                container('dind') {
                    script {
                        echo "Building Docker Image..."
                        sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                    }
                }
            }
        }

        // --- STAGE 4: NEXUS ---
        stage('Nexus Push') {
            steps {
                container('dind') {
                    script {
                        echo "Resolving Nexus IP..."
                        // 👇 FIX: resolve ONLY the domain, not the port
                        def nexus_ip = sh(script: "getent hosts ${NEXUS_DOMAIN} | awk '{ print \$1 }'", returnStdout: true).trim()
                        
                        if (!nexus_ip) { 
                            error("❌ DNS Error: Could not resolve Nexus IP for ${NEXUS_DOMAIN}") 
                        }
                        
                        echo "✅ Nexus IP Resolved: ${nexus_ip}"
                        
                        // Save IP for the deployment stage
                        writeFile file: 'nexus_ip.txt', text: nexus_ip
                        
                        // Construct the full URL using the IP
                        def registry_ip_url = "${nexus_ip}:${NEXUS_PORT}/${NAMESPACE}"
                        
                        echo "Logging into Nexus (${nexus_ip})..."
                        sh "docker login ${nexus_ip}:${NEXUS_PORT} -u admin -p Changeme@2025"
                        
                        echo "Pushing Image..."
                        sh """
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${registry_ip_url}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${registry_ip_url}/${IMAGE_NAME}:latest
                            
                            docker push ${registry_ip_url}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${registry_ip_url}/${IMAGE_NAME}:latest
                        """
                    }
                }
            }
        }

        // --- STAGE 5: KUBERNETES ---
        stage('Kubernetes Deploy') {
            steps {
                container('kubectl') {
                    script {
                        echo "Deploying to Kubernetes..."
                        
                        // 1. Get the IP detected in the previous stage
                        def nexus_ip = readFile('nexus_ip.txt').trim()
                        def full_nexus_host = "${NEXUS_DOMAIN}:${NEXUS_PORT}"
                        def full_nexus_ip   = "${nexus_ip}:${NEXUS_PORT}"
                        
                        // 2. Patch deployment.yaml to use IP (Avoids Node DNS failure)
                        sh "sed -i 's|${full_nexus_host}|${full_nexus_ip}|g' k8s/deployment.yaml"
                        
                        // 3. Create Secret with IP
                        sh "kubectl delete secret nexus-secret -n ${NAMESPACE} --ignore-not-found"
                        sh """
                            kubectl create secret docker-registry nexus-secret \
                            --docker-server=${full_nexus_ip} \
                            --docker-username=admin \
                            --docker-password=Changeme@2025 \
                            -n ${NAMESPACE}
                        """
                        
                        // 4. Apply & Restart
                        sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
                        sh "kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                        
                        // 5. Delete old pods to force immediate pull
                        sh "kubectl delete pods -l app=carbon-emission-app -n ${NAMESPACE} --wait=false || true"
                        
                        // 6. Wait for Green Status
                        sh "kubectl rollout status deployment/carbon-app-deployment -n ${NAMESPACE} --timeout=300s"
                    }
                }
            }
        }
    }
}