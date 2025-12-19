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
        IMAGE_NAME    = "carbon-emission-app"
        NAMESPACE     = "2401129"
        // We start with the hostname, but we will overwrite this with the IP later
        NEXUS_HOSTNAME = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
    }
    stages {
        stage('Checkout Code') {
            steps {
                deleteDir()
                sh "git clone https://github.com/vasundhara-mete/CarbonEmissionWebApp.git ." 
            }
        }

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

        stage('Build & Push (IP Fix)') {
            steps {
                container('dind') {
                    script {
                        echo "🔍 resolving Nexus IP Address..."
                        // This command finds the IP address of Nexus from inside the pod
                        def nexus_ip = sh(script: "getent hosts nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local | awk '{ print \$1 }'", returnStdout: true).trim()
                        
                        if (!nexus_ip) {
                            error("❌ Could not resolve Nexus IP! The DNS is completely broken.")
                        }
                        
                        echo "✅ Resolved Nexus IP: ${nexus_ip}"
                        
                        // Set the Registry Host to use the IP instead of the name
                        env.REGISTRY_HOST = "${nexus_ip}:8085"
                        env.REGISTRY_URL  = "${env.REGISTRY_HOST}/${NAMESPACE}"
                        
                        echo "Building Image using IP: ${env.REGISTRY_HOST}..."
                        sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                        
                        echo "Logging into Nexus (IP)..."
                        sh "docker login ${env.REGISTRY_HOST} -u admin -p Changeme@2025"
                        
                        echo "Pushing Image to Nexus (IP)..."
                        sh """
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${env.REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${env.REGISTRY_URL}/${IMAGE_NAME}:latest
                            
                            docker push ${env.REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${env.REGISTRY_URL}/${IMAGE_NAME}:latest
                        """
                        
                        // Store the IP for the next stage
                        writeFile file: 'nexus_ip.txt', text: nexus_ip
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    script {
                        // Read the IP we found in the previous stage
                        def nexus_ip = readFile('nexus_ip.txt').trim()
                        def registry_host_ip = "${nexus_ip}:8085"
                        
                        echo "🛠️ Patching Deployment file to use IP: ${nexus_ip}..."
                        
                        // Use SED to replace the hostname with the IP in the deployment.yaml file
                        sh "sed -i 's|nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085|${registry_host_ip}|g' k8s/deployment.yaml"
                        
                        // Print to verify change
                        sh "cat k8s/deployment.yaml | grep image:"

                        echo "Configuring Secrets & Deploying..."
                        sh "kubectl delete secret nexus-secret -n ${NAMESPACE} --ignore-not-found"
                        
                        // Create secret using the IP address
                        sh """
                            kubectl create secret docker-registry nexus-secret \
                            --docker-server=${registry_host_ip} \
                            --docker-username=admin \
                            --docker-password=Changeme@2025 \
                            -n ${NAMESPACE}
                        """
                        
                        sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
                        sh "kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                        
                        // Force delete bad pods to trigger immediate restart with new config
                        sh "kubectl delete pods -l app=carbon-emission-app -n ${NAMESPACE} --wait=false || true"
                        
                        try {
                            sh "kubectl rollout status deployment/carbon-app-deployment -n ${NAMESPACE} --timeout=300s"
                        } catch (Exception e) {
                            echo "🔴 DEPLOYMENT FAILED - FETCHING DEBUG INFO..."
                            sh "kubectl get pods -n ${NAMESPACE}"
                            sh "kubectl describe pod -l app=carbon-emission-app -n ${NAMESPACE}"
                            sh "kubectl logs -l app=carbon-emission-app -n ${NAMESPACE} --tail=200 --all-containers || true"
                            error("Deployment Failed. Check logs above.")
                        }
                    }
                }
            }
        }
    }
}