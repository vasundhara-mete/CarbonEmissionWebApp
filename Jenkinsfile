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
        NEXUS_DOMAIN   = "nexus-service-for-docker-hosted-registry.nexus.svc.cluster.local"
        NEXUS_PORT     = "8085"
    }
    stages {
        // --- STAGE 1 ---
        stage('Checkout') {
            steps {
                deleteDir()
                sh "git clone https://github.com/vasundhara-mete/CarbonEmissionWebApp.git ." 
            }
        }

        // --- STAGE 2 ---
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

        // --- STAGE 3 ---
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

        // --- STAGE 4 ---
        stage('Nexus Push') {
            steps {
                container('dind') {
                    script {
                        echo "Resolving Nexus IP..."
                        def nexus_ip = sh(script: "getent hosts ${NEXUS_DOMAIN} | awk '{ print \$1 }'", returnStdout: true).trim()
                        writeFile file: 'nexus_ip.txt', text: nexus_ip
                        
                        def full_nexus_host = "${NEXUS_DOMAIN}:${NEXUS_PORT}"
                        def registry_url    = "${full_nexus_host}/${NAMESPACE}"
                        
                        echo "Logging into Nexus..."
                        sh "docker login ${full