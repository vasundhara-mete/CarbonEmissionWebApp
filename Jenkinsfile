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
        // 1. We keep Hostname and Port separate to avoid script errors
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

        // --- STAGE 4: NEXUS (Push with Hostname) ---
        stage('Nexus Push') {
            steps {
                container('dind') {
                    script {
                        // We use the HOSTNAME here because Docker allows it (configured in daemon.json)
                        def full_nexus_host = "${NEXUS_DOMAIN}:${NEXUS_PORT}"
                        def registry_url    = "${full_nexus_host}/${NAMESPACE}"
                        
                        echo "Logging into Nexus (Hostname)..."
                        sh "docker login ${full_nexus_host} -u admin -p Changeme@2025"
                        
                        echo "Pushing Image..."
                        sh """
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${registry_url}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${registry_url}/${IMAGE_NAME}:latest
                            
                            docker push ${registry_url}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${registry_url}/${IMAGE_NAME}:latest
                        """
                    }
                }
            }
        }

        // --- STAGE 5: KUBERNETES (Deploy with IP) ---
        stage('Kubernetes Deploy') {
            steps {
                container('kubectl') {
                    script {
                        echo "Resolving Nexus IP for Kubernetes..."
                        
                        // 1. Get the IP Address (Fixes 'server misbehaving' error on Nodes)
                        def nexus_ip = sh(script: "getent hosts ${NEXUS_DOMAIN} | awk '{ print \$1 }'", returnStdout: true).trim()
                        if (!nexus_ip) { error("❌ DNS Error: Could not resolve Nexus IP.") }
                        
                        echo "✅ Nexus IP: ${nexus_ip}. Swapping Hostname -> IP for deployment."
                        
                        // Define strings for replacement
                        def hostname_str = "${NEXUS_DOMAIN}:${NEXUS_PORT}"
                        def ip_str       = "${nexus_ip}:${NEXUS_PORT}"
                        
                        // 2. Patch deployment.yaml: Replace Hostname with IP
                        sh "sed -i 's|${hostname_str}|${ip_str}|g' k8s/deployment.yaml"
                        
                        // 3. Create Secret using the IP
                        sh "kubectl delete secret nexus-secret -n ${NAMESPACE} --ignore-not-found"
                        sh """
                            kubectl create secret docker-registry nexus-secret \
                            --docker-server=${ip_str} \
                            --docker-username=admin \
                            --docker-password=Changeme@2025 \
                            -n ${NAMESPACE}
                        """
                        
                        // 4. Apply & Restart
                        sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
                        sh "kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                        
                        // 5. Delete old pods to force immediate restart
                        sh "kubectl delete pods -l app=carbon-emission-app -n ${NAMESPACE} --wait=false || true"
                        
                        // 6. Wait for Success
                        sh "kubectl rollout status deployment/carbon-app-deployment -n ${NAMESPACE} --timeout=300s"
                    }
                }
            }
        }
    }
}