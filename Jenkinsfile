pipeline {
    agent any

    environment {
        IMAGE_NAME = "expense-tracker-backend"
        IMAGE_TAG  = "1.0.0"
    }

    tools {
        nodejs 'node22'
    }

    stages {

        // Install all project dependencies using package-lock.json.
        stage('Install Dependencies') {
            steps {
                dir('app/backend') {
                    sh 'npm ci'
                }
            }
        }

        // Verify the required build tools are available.
        stage('Verify Environment') {
            steps {
                sh 'node --version'
                sh 'npm --version'
                sh 'docker --version'
            }
        }

        // Validate the application source code.
        stage('Validate Source') {
            steps {
                dir('app/backend') {
                    sh 'npm run validate'
                }
            }

            post {
                success {
                    echo '✅ Application validation passed.'
                }

                failure {
                    echo '❌ Application validation failed.'
                }
            }
        }

        // Execute automated integration tests.
        stage('Run Tests') {
            steps {
                dir('app/backend') {
                    sh 'npm test'
                }
            }

            post {
                success {
                    echo '✅ All automated tests passed.'
                }

                failure {
                    echo '❌ Automated tests failed.'
                }
            }
        }

        // Build the Docker image after all quality checks pass.
        stage('Build Docker Image') {
            steps {
                sh """
                    docker build \
                      -t ${IMAGE_NAME}:${IMAGE_TAG} \
                      -f docker/backend/Dockerfile \
                      app/backend
                """
            }

            post {
                success {
                    echo '✅ Docker image built successfully.'
                }

                failure {
                    echo '❌ Docker image build failed.'
                }
            }
        }

        // Verify the Docker artifact exists.
        stage('Verify Docker Artifact') {
            steps {
                sh """
                    docker images | grep ${IMAGE_NAME}
                """
            }

            post {
                success {
                    echo '✅ Docker artifact verified.'
                }

                failure {
                    echo '❌ Docker artifact verification failed.'
                }
            }
        }
    }

    post {

        success {
            echo '🎉 Jenkins pipeline completed successfully.'
        }

        failure {
            echo '❌ Jenkins pipeline failed.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}