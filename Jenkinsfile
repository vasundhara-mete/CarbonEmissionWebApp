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
        // This hostname is a placeholder; we will auto-resolve the IP in the pipeline
        NEXUS_HOSTNAME = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
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
                        // Auto-detect the IP to fix the DNS/ImagePull error
                        def nexus_ip = sh(script: "getent hosts ${NEXUS_HOSTNAME} | awk '{ print \$1 }'", returnStdout: true).trim()
                        if (!nexus_ip) { error("❌ DNS Error: Could not resolve Nexus IP.") }
                        
                        // Save the IP to a file so the Kubernetes stage can use it
                        writeFile file: 'nexus_ip.txt', text: nexus_ip
                        
                        def registry_ip_url = "${nexus_ip}:8085/${NAMESPACE}"
                        
                        echo "Logging into Nexus (${nexus_ip})..."
                        sh "docker login ${nexus_ip}:8085 -u admin -p Changeme@2025"
                        
                        echo "Pushing Image to Nexus..."
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
                        
                        // 1. Read the IP detected in the previous stage
                        def nexus_ip = readFile('nexus_ip.txt').trim()
                        
                        // 2. Update deployment.yaml to use the IP address (Fixes ImagePullBackOff)
                        sh "sed -i 's|${NEXUS_HOSTNAME}|${nexus_ip}:8085|g' k8s/deployment.yaml"
                        
                        // 3. Create the Secret using the IP
                        sh "kubectl delete secret nexus-secret -n ${NAMESPACE} --ignore-not-found"
                        sh """
                            kubectl create secret docker-registry nexus-secret \
                            --docker-server=${nexus_ip}:8085 \
                            --docker-username=admin \
                            --docker-password=Changeme@2025 \
                            -n ${NAMESPACE}
                        """
                        
                        // 4. Apply Manifests
                        sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
                        
                        // 5. Force Restart
                        sh "kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                        
                        // 6. Delete old pods to ensure instant restart
                        sh "kubectl delete pods -l app=carbon-emission-app -n ${NAMESPACE} --wait=false || true"
                        
                        // 7. Wait for Success
                        sh "kubectl rollout status deployment/carbon-app-deployment -n ${NAMESPACE} --timeout=300s"
                    }
                }
            }
        }
    }
}