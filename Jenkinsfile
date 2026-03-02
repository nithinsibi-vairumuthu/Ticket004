pipeline {
    agent any

    environment {
        AWS_REGION = 'ap-south-1'
        CLUSTER_NAME = 'devops-eks-cluster'
        ECR_REPO = '730335674713.dkr.ecr.ap-south-1.amazonaws.com/prod-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        IMAGE = "${ECR_REPO}:${IMAGE_TAG}"
    }

    stages {

        stage('Checkout') {
            steps { checkout scm }
        }

        stage('Build') {
            steps {
                sh "docker build --no-cache -t ${IMAGE} ."
            }
        }

        stage('Trivy Scan') {
            steps {
                sh "trivy image --exit-code 0 --severity CRITICAL,${IMAGE}"
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                aws ecr get-login-password --region ${AWS_REGION} | \
                docker login --username AWS --password-stdin ${ECR_REPO}

                docker push ${IMAGE}
                """
            }
        }

        stage('Deploy to Dev') {
            when { branch 'dev' }
            steps {
                sh """
                helm upgrade --install app ./helm \
                --namespace dev \
                --set image.repository=${ECR_REPO} \
                --set image.tag=${IMAGE_TAG}
                """
            }
        }

        stage('Approval') {
            when { branch 'main' }
            steps {
                input message: "Deploy to Production?"
            }
        }

        stage('Deploy to Prod') {
            when { branch 'main' }
            steps {
                sh """
                helm upgrade --install app ./helm \
                --namespace prod \
                --set image.repository=${ECR_REPO} \
                --set image.tag=${IMAGE_TAG}
                """
            }
        }
    }

    post {
        always {
            sh "docker image prune -f"
        }
    }
}
