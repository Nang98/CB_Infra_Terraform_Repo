pipeline {
    agent any

    stages {
        stage('Checkout Git') {
            steps {
                echo 'Cloning source code from Git repository...'
                sleep(time: 15, unit: 'SECONDS') // Simulate 15 seconds for clone
            }
        }

        stage('Sonar Code Scan') {
            steps {
                echo 'Running SonarQube scan...'
                sleep(time: 30, unit: 'SECONDS') // Simulate 30 seconds for code analysis
            }
        }

        stage('Trufflehog Secrets Scan') {
            steps {
                echo 'Scanning repository for secrets using TruffleHog...'
                sleep(time: 20, unit: 'SECONDS') // Simulate 20 seconds for secrets scan
            }
        }

        stage('Terraform Init') {
            steps {
                echo 'Initializing Terraform...'
                sleep(time: 10, unit: 'SECONDS') // Simulate 10 seconds for terraform init
            }
        }

        stage('Terraform Plan') {
            steps {
                echo 'Running terraform plan...'
                sleep(time: 15, unit: 'SECONDS') // Simulate 15 seconds for terraform plan
            }
        }

        stage('Terraform Apply') {
            steps {
                echo 'Applying terraform changes...'
                sleep(time: 60, unit: 'SECONDS') // Simulate 20 seconds for terraform apply
            }
        }

        stage('Test Url') {
            steps {
                echo 'Applying terraform changes...'
                sleep(time: 20, unit: 'SECONDS') // Simulate 20 seconds for terraform apply
            }
        }

        stage('Notify Deployment Status') {
            steps {
                echo 'Sending notification about deployment result...'
                sleep(time: 5, unit: 'SECONDS') // Simulate 5 seconds for notification
            }
        }
    }
}
