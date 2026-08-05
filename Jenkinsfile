/*
 * Expense Tracker DevOps
 * Jenkins CI Pipeline (Version 1)
 *
 * Current stages:
 * - Checkout Source
 * - Install Dependencies
 * - Verify Environment
 *
 * Future stages:
 * - Run Tests
 * - Build Docker Image
 * - Push Image
 * - Deploy
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