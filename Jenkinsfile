/*
 * Expense Tracker DevOps
 * Jenkins Continuous Integration & Release Pipeline
 *
 * Purpose:
 * - Install project dependencies
 * - Verify build environment
 * - Validate application source
 * - Run automated integration tests
 * - Build versioned Docker release artifacts
 * - Verify Docker artifacts
 * - Publish release artifacts to Docker Hub
 */

pipeline {
    agent any

    environment {
        IMAGE_NAME = "medonati/expense-tracker-backend"
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

        /*
         * Determine Docker image version from the Git release tag.
         *
         * Example:
         * v1.0.0 → 1.0.0
         * v1.0.1 → 1.0.1
		 * The Git commit is also captured so the Docker artifact
         * can later be traced back to the exact source code
         * that produced it.
         */
        stage('Determine Release Version') {
            when {
                buildingTag()
            }

            steps {
                script {
                    def gitTag = sh(
                        script: 'git describe --tags --exact-match',
                        returnStdout: true
                    ).trim()

                    if (!gitTag.startsWith('v')) {
                        error "❌ Expected a release tag starting with 'v', but found: ${gitTag}"
                    }

                    env.IMAGE_TAG = gitTag.substring(1)
					
					env.GIT_COMMIT = sh(
					    script: 'git rev-parse HEAD',
						returnStdout: true
					).trim()

                    echo "🏷️ Git release tag: ${gitTag}"
                    echo "📦 Docker image tag: ${env.IMAGE_TAG}"
					echo "🔗 Git commit: ${env.GIT_COMMIT}"
                }
            }
        }

        // Build the Docker image for a tagged release.
		// Embed release and Git commit metadata for artifact traceability.
        stage('Build Docker Image') {
			when {
				buildingTag()
			}

			steps {
				sh """
					docker build \
					  --build-arg VERSION=${IMAGE_TAG} \
					  --build-arg GIT_COMMIT=${GIT_COMMIT} \
					  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
					  -t ${IMAGE_NAME}:${IMAGE_TAG} \
					  -f docker/backend/Dockerfile \
					  app/backend
				"""
			}

			post {
				success {
					echo "🐳 Docker image built successfully."
				}
			}
		}

        // Verify that the versioned Docker artifact exists locally.
        stage('Verify Docker Artifact') {
            when {
                buildingTag()
            }

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

        // Authenticate with Docker Hub and publish the versioned release artifact.
        stage('Push Docker Image') {
            when {
                buildingTag()
            }

            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USERNAME',
                        passwordVariable: 'DOCKER_PASSWORD'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_PASSWORD" | docker login \
                            --username "$DOCKER_USERNAME" \
                            --password-stdin

                        docker push ${IMAGE_NAME}:${IMAGE_TAG}
                    '''
                }
            }

            post {
                success {
                    echo '✅ Docker image pushed successfully.'
                }

                failure {
                    echo '❌ Docker image push failed.'
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