pipeline {
  agent any

  environment {
    AWS_REGION = "us-east-1"
    ECR_ACCOUNT = "620356661348"
    ECR_REPO = "hello-devops"
    IMAGE_TAG = "${env.BUILD_NUMBER}"
    KUBECONFIG = "/var/lib/jenkins/.kube/config"
    HELM_RELEASE = "hello-devops"
    CHART_DIR = "charts/hello-devops"
  }

  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }

    stage('Unit tests') {
      steps {
        sh '''
          set -e
          docker run --rm -v "$PWD/app":/app -w /app golang:1.21 go test ./...
        '''
      }
    }

    stage('Build image') {
      steps {
        sh '''
          set -e
          IMAGE="${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${IMAGE_TAG}"
          docker build -t "${IMAGE}" app
          echo "${IMAGE}" > image.txt
        '''
      }
    }

    stage('Push & Deploy') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'aws-creds', usernameVariable: 'AWS_ACCESS_KEY_ID', passwordVariable: 'AWS_SECRET_ACCESS_KEY')]) {
          sh '''
            set -e
            IMAGE="$(cat image.txt)"
            aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            docker push "${IMAGE}"

            # Deploy via Helm
            helm upgrade --install "${HELM_RELEASE}" "${CHART_DIR}" \
              --namespace devops --create-namespace \
              --set image.repository="${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}" \
              --set image.tag="${IMAGE_TAG}" \
              --set service.nodePort=30080 \
              --set service.type=NodePort \
              --debug
          '''
        }
      }
    }
  }
}
