pipeline {
    agent any

    parameters {
        booleanParam(name: 'ROLLBACK', defaultValue: false, description: 'Rollback prod to previous image')
    }

    environment {
        AWS_REGION   = 'ap-south-1'
        CLUSTER_NAME = 'devops-eks-cluster'
        ECR_REPO     = '730335674713.dkr.ecr.ap-south-1.amazonaws.com/prod-app'
        IMAGE_TAG    = "${env.GIT_COMMIT[0..6]}-${BUILD_NUMBER}"
        IMAGE        = "${ECR_REPO}:${IMAGE_TAG}"
        PREV_TAG     = "${ECR_REPO}:previous"
    }

    triggers {
        githubPush()
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Docker Image') {
            when {
                not { expression { return params.ROLLBACK } }
            }
            steps {
                sh "docker build --no-cache -t ${IMAGE} ."
            }
        }

        stage('Login to ECR') {
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh """
                        aws ecr get-login-password --region ${AWS_REGION} | \
                        docker login --username AWS --password-stdin ${ECR_REPO}
                    """
                }
            }
        }

        stage('Push to ECR') {
            when {
                not { expression { return params.ROLLBACK } }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh """
                        CURRENT=\$(aws ecr describe-images \
                            --repository-name prod-app \
                            --region ${AWS_REGION} \
                            --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' \
                            --output text 2>/dev/null || echo "")

                        if [ ! -z "\$CURRENT" ] && [ "\$CURRENT" != "previous" ] && [ "\$CURRENT" != "None" ]; then
                            docker pull ${ECR_REPO}:\$CURRENT
                            docker tag  ${ECR_REPO}:\$CURRENT ${PREV_TAG}
                            docker push ${PREV_TAG}
                            echo "Saved previous image: \$CURRENT → previous"
                        fi

                        docker push ${IMAGE}
                        echo "Pushed new image: ${IMAGE_TAG}"
                    """
                }
            }
        }

        stage('Deploy to Dev') {
            when {
                allOf {
                    branch 'dev'
                    not { expression { return params.ROLLBACK } }
                }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                        kubectl create namespace dev --dry-run=client -o yaml | kubectl apply -f -
                        sed -i 's|IMAGE_PLACEHOLDER|${IMAGE}|g' k8s/deployment.yaml
                        kubectl apply -n dev -f k8s/deployment.yaml
                        kubectl apply -n dev -f k8s/service.yaml
                        kubectl rollout status deployment/eks-demo -n dev --timeout=120s
                        echo "✅ Auto deployed to Dev | Image: ${IMAGE_TAG}"
                    """
                }
            }
        }

        stage('Approval for Prod') {
            when {
                allOf {
                    branch 'main'
                    not { expression { return params.ROLLBACK } }
                }
            }
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    input message: "Deploy ${IMAGE_TAG} to Production?", ok: "Deploy"
                }
            }
        }

        stage('Deploy to Prod') {
            when {
                allOf {
                    branch 'main'
                    not { expression { return params.ROLLBACK } }
                }
            }
            steps {
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                        kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
                        sed -i 's|IMAGE_PLACEHOLDER|${IMAGE}|g' k8s/deployment.yaml
                        kubectl apply -n prod -f k8s/deployment.yaml
                        kubectl apply -n prod -f k8s/service.yaml
                        kubectl rollout status deployment/eks-demo -n prod --timeout=180s
                        echo "✅ Deployed to Prod | Image: ${IMAGE_TAG}"
                    """
                }
            }
        }

        stage('Rollback Prod') {
            when {
                allOf {
                    branch 'main'
                    expression { return params.ROLLBACK }
                }
            }
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    input message: "⚠️ Confirm ROLLBACK to previous image in Prod?", ok: "Rollback"
                }
                withCredentials([
                    string(credentialsId: 'AWS_ACCESS_KEY_ID',     variable: 'AWS_ACCESS_KEY_ID'),
                    string(credentialsId: 'AWS_SECRET_ACCESS_KEY', variable: 'AWS_SECRET_ACCESS_KEY')
                ]) {
                    sh """
                        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                        echo "Rolling back to previous image..."
                        kubectl set image deployment/eks-demo \
                            eks-demo=${PREV_TAG} -n prod
                        kubectl rollout status deployment/eks-demo -n prod --timeout=180s
                        echo "✅ Rollback complete"
                    """
                }
            }
        }
    }

    post {
        always {
            sh """
                docker rmi ${IMAGE} || true
                docker image prune -f
                docker builder prune -f --keep-storage 2GB || true
            """
        }
        success {
            echo "✅ Pipeline Succeeded | Image: ${IMAGE_TAG} | Branch: ${env.BRANCH_NAME}"
        }
        failure {
            echo "❌ Pipeline Failed | Build: ${BUILD_NUMBER} | Branch: ${env.BRANCH_NAME}"
        }
    }
}
