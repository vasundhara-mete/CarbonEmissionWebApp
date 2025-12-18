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
        REGISTRY_HOST = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local:8085"
        REGISTRY_URL  = "${REGISTRY_HOST}/${NAMESPACE}"
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

        stage('Build Docker Image') {
            steps {
                container('dind') {
                    script {
                        echo "Building Image with Docker..."
                        sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                    }
                }
            }
        }

        stage('Push to Nexus') {
            steps {
                container('dind') {
                    script {
                        echo "Logging into Nexus Registry..."
                        sh "docker login ${REGISTRY_HOST} -u admin -p Changeme@2025"
                        
                        echo "Pushing Image to Nexus..."
                        sh """
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${REGISTRY_URL}/${IMAGE_NAME}:latest
                            
                            docker push ${REGISTRY_URL}/${IMAGE_NAME}:${BUILD_NUMBER}
                            docker push ${REGISTRY_URL}/${IMAGE_NAME}:latest
                        """
                    }
                }
            }
        }

        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    script {
                        echo "Configuring Secrets & Deploying..."
                        
                        // 1. Delete old secret if it exists to ensure we have the fresh one
                        sh "kubectl delete secret nexus-secret -n ${NAMESPACE} --ignore-not-found"
                        
                        // 2. Create the secret so K8s can login to Nexus
                        sh """
                            kubectl create secret docker-registry nexus-secret \
                            --docker-server=${REGISTRY_HOST} \
                            --docker-username=admin \
                            --docker-password=Changeme@2025 \
                            -n ${NAMESPACE}
                        """
                        
                        // 3. Apply deployment
                        sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
                        
                        // 4. Restart to pick up new image
                        sh "kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                        
                        // 5. Wait for success
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