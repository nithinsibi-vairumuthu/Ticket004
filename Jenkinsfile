pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        ECR_REPO = '730335674713.dkr.ecr.ap-south-1.amazonaws.com/prod-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        IMAGE = "${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build --no-cache -t ${IMAGE} ."
            }
        }

        stage('Login to ECR') {
            steps {
                sh """
                aws ecr get-login-password --region ${AWS_REGION} | \
                docker login --username AWS --password-stdin ${ECR_REPO}
                """
            }
        }

        stage('Push to ECR') {
            steps {
                sh "docker push ${IMAGE}"
            }
        }

        stage('Deploy to Dev') {
            when {
                branch 'dev'
            }
            steps {
                sh """
                kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -

                sed -i 's|IMAGE_PLACEHOLDER|${IMAGE}|g' k8s/deployment.yaml

                kubectl apply -n dev -f k8s/deployment.yaml
                kubectl apply -n dev -f k8s/service.yaml

                kubectl rollout status deployment/eks-demo -n dev
                """
            }
        }

        stage('Approval for Prod') {
            when {
                branch 'main'
            }
            steps {
                input message: "Deploy to Production?"
            }
        }

        stage('Deploy to Prod') {
            when {
                branch 'main'
            }
            steps {
                sh """
                kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -

                sed -i 's|IMAGE_PLACEHOLDER|${IMAGE}|g' k8s/deployment.yaml

                kubectl apply -n prod -f k8s/deployment.yaml
                kubectl apply -n prod -f k8s/service.yaml

                kubectl rollout status deployment/eks-demo -n prod
                """
            }
        }
    }

    post {
        always {
            sh "docker image prune -f"
        }
        success {
            echo "CI/CD Completed Successfully 🚀"
        }
        failure {
            echo "Pipeline Failed ❌"
        }
    }
}
