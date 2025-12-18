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
        // 1. JENKINS & GIT (Checking out code)
        stage('Checkout Code') {
            steps {
                deleteDir()
                sh "git clone https://github.com/YOUR-USERNAME/YOUR-REPO.git ." 
            }
        }

        // 2. SONARQUBE (Checking Code Quality)
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

        // 3. DOCKER (Building the Image)
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
                        echo "Building Docker Image..."
                        sh "docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} ."
                    }
                }
            }
        }

        // 4. NEXUS (Pushing Image to Registry)
        stage('Push to Nexus') {
            steps {
                container('dind') {
                    script {
                        echo "Logging into Nexus..."
                        sh "docker login ${REGISTRY_HOST} -u admin -p Changeme@2025"
                        
                        echo "Pushing image to Nexus..."
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

        // 5. KUBERNETES (Deploying the App)
        stage('Deploy to Kubernetes') {
            steps {
                container('kubectl') {
                    echo "Deploying to Kubernetes Cluster..."
                    sh "kubectl apply -f k8s/ -n ${NAMESPACE}"
                    sh "kubectl rollout restart deployment/carbon-app-deployment -n ${NAMESPACE}"
                }
            }
        }
    }
}