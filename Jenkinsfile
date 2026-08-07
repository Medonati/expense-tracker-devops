/*
 * Expense Tracker DevOps
 * Jenkins Continuous Integration Pipeline
 *
 * Purpose:
 * - Install project dependencies
 * - Verify build environment
 * - Validate application source
 * - Run automated integration tests
 *
 * Upcoming Stages
 * - Docker Build
 * - Image Security Scan
 * - Push Image
 * - Deployment
 */

pipeline {
    agent any

    tools {
        nodejs 'node22'
    }

    stages {

        stage('Install Dependencies') {
            steps {
                dir('app/backend') {
                    sh 'npm install'
                }
            }
        }

        stage('Application Validation') {
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

        stage('Verify Environment') {
            steps {
                dir('app/backend') {
                    sh 'node --version'
                    sh 'npm --version'
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully.'
        }

        failure {
            echo '❌ Pipeline failed.'
        }

        always {
            echo 'Pipeline execution finished.'
        }
    }
}