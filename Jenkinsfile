pipeline {
    agent any
    tools { maven 'M3'; jdk 'JDK17' }
    options { timestamps() }
    stages {
      stage('Checkout') { steps { checkout scm } }
      stage('Build & Test') { steps { sh 'mvn -B -U clean verify' } }
      stage('Archive') {
        steps {
          archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
          junit 'target/surefire-reports/*.xml'
        }
      }
    }
    post { always { cleanWs() } }
  }

