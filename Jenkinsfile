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
        // --- STAGE 1: JENKINS (Checkout) ---
        stage('Checkout Code') {
            steps {
                deleteDir()
                sh "git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git ." 
            }
        }

        // --- STAGE 2: SONARQUBE (Analysis) ---
        stage('SonarQube Analysis') {
            steps {
                container('dind') {
                    sh """
                        docker run --rm \
                            -v "\$PWD/app:/usr/src" \
                            sonarsource/sonar-scanner-cli \
                            -Dsonar.projectBaseDir=/usr/src
                    """
                }
            }
        }

        // --- STAGE 3: DOCKER (Build Only) ---
        stage('Build Docker Image') {
            steps {
                container('dind') {
                    script {
                        timeout(time: 1, unit: 'MINUTES') {
                            waitUntil {
                                try { sh 'docker info >/dev/null 2>&1'; return true } 
                                catch (Exception e) { sleep 5; return false }
                            }
                        }
                        echo "Building Image with Docker..."
                        sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                    }
                }
            }
        }

        // --- STAGE 4: NEXUS (Login & Push Only) ---
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

        // --- STAGE 5: KUBERNETES (Deploy) ---
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    echo "Deploying manifests to Kubernetes..."
                    sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
                    sh "kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                }
            }
        }
    }
}