Jenkins Enterprise Guide
========================

Table of Contents
-----------------
1. Introduction to Jenkins  
2. Jenkins Architecture (Enterprise View)  
3. Installing and Accessing Jenkins  
4. Core Jenkins Concepts  
5. Job Types: Freestyle vs Pipeline  
6. Example: Freestyle Build Job  
7. Jenkins Pipeline and Jenkinsfile Basics  
8. Enterprise Build Pipeline Example (Java / Maven)  
9. Enterprise Deployment Pipeline (Docker & Kubernetes)  
10. CI/CD with GitHub and Webhooks  
11. Integrations with Other DevOps Tools  
12. Security, Credentials, and RBAC  
13. Best Practices for Enterprise Jenkins  
14. Common Issues and Troubleshooting  
15. Essential Jenkins Plugins and How to Install Them  
16. Step-by-Step: Creating a Pipeline Job in Jenkins UI  

1) Introduction to Jenkins
--------------------------
- Open-source automation server for CI/CD.
- Supports Freestyle and Pipeline jobs; declarative pipelines stored as code (`Jenkinsfile`).
- Scales with controller + agents; integrates with VCS, artifact repos, cloud, and infra tools.

2) Jenkins Architecture (Enterprise View)
-----------------------------------------
- Controller: UI, scheduling, credentials, job config; avoid running builds here (set executors to 0).
- Agents: run builds/tests; labeled for OS/capabilities (docker, k8s, windows).
- SCM: GitHub/GitLab/Bitbucket; webhooks trigger jobs.
- Artifact storage: Nexus/Artifactory/S3.
- Deployment targets: Kubernetes, VMs, cloud services.
- Observability: logs to centralized logging; metrics via Prometheus/JMX; alerts to Slack/email.

3) Installing and Accessing Jenkins
-----------------------------------
- Linux (Debian/Ubuntu) quick install (controller):
  ```
  # install Java + tools
  sudo apt-get update
  sudo apt-get install -y fontconfig openjdk-17-jre gnupg curl
  # add Jenkins apt repo/key
  curl -fsSL https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc >/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian binary/' | sudo tee /etc/apt/sources.list.d/jenkins.list
  sudo apt-get update
  sudo apt-get install -y jenkins
  # service
  sudo systemctl enable --now jenkins
  sudo systemctl status jenkins
  ```
- Access: `http://<host>:8080`.
- Initial admin password: `/var/lib/jenkins/secrets/initialAdminPassword`.
- For this project: installed via Ansible (apt repo + service).

4) Core Jenkins Concepts
------------------------
- Job/Project: unit of work (Freestyle or Pipeline).
- Build: a single run of a job.
- Node/Agent: machine that runs a build; labeled.
- Executor: slot on a node; controls parallelism.
- Workspace: working directory on agent per job.
- Credentials: stored secrets (username/password, SSH key, secret text, token); referenced by ID.
- Plugins: extend Jenkins (SCM, pipeline steps, cloud, notifications).

5) Job Types: Freestyle vs Pipeline
-----------------------------------
- Freestyle: GUI-defined steps; quick but less portable.
- Pipeline: code-defined (`Jenkinsfile`); supports stages, parallelism, shared libraries, durability.
- Use Pipeline for anything non-trivial or production.

6) Example: Freestyle Build Job
-------------------------------
- Use case: simple build of a shell project.
- Steps:
  1. New Item → Freestyle.
  2. Source Code Management: Git URL, branch.
  3. Build: Execute shell:
     ```
     ./build.sh
     ./run-tests.sh
     ```
  4. Post-build: Archive artifacts (`**/target/*.jar`), JUnit (`**/target/surefire-reports/*.xml`).

7) Jenkins Pipeline and Jenkinsfile Basics
------------------------------------------
- Declarative pipeline skeleton:
```groovy
pipeline {
  agent any
  options { timestamps(); timeout(time: 30, unit: 'MINUTES') }
  environment {
    SOME_VAR = "value"
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Build') { steps { sh 'make build' } }
    stage('Test') { steps { sh 'make test' } }
  }
  post {
    always { cleanWs() }
  }
}
```
- Notes: use `checkout scm`; set timeouts; clean workspace; prefer declarative for clarity.

8) Enterprise Build Pipeline Example (Java / Maven)
---------------------------------------------------
```groovy
pipeline {
  agent any
  options { timestamps(); timeout(time: 45, unit: 'MINUTES') }
  tools { maven 'M3' }            // Configure in Global Tool Config
  environment {
    JAVA_HOME = tool name: 'JDK11', type: 'jdk'
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
    stage('Build & Test') {
      steps {
        sh 'mvn -B -U clean verify'
      }
    }
    stage('Archive') {
      steps {
        archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
        junit 'target/surefire-reports/*.xml'
      }
    }
  }
  post {
    always { cleanWs() }
  }
}
```
- Explain: uses configured Maven/JDK; runs clean verify; archives JARs; publishes tests; cleans workspace.

9) Enterprise Deployment Pipeline (Docker & Kubernetes)
-------------------------------------------------------
Ready-to-run pattern (adapt to your registry/cluster). This matches our stack (AWS ECR + k3s + Helm, namespace `devops`). Copy into a “Pipeline” job or `Jenkinsfile`.

Prereqs (one-time):
- Jenkins credentials: `aws-creds` (kind “Username with password”; username = AWS_ACCESS_KEY_ID, password = AWS_SECRET_ACCESS_KEY).
- Kubeconfig readable at `/var/lib/jenkins/.kube/config` on the agent running the job.
- Kubernetes imagePullSecret named `ecr-creds` in namespace `devops` (created with `aws ecr get-login-password | kubectl create secret docker-registry ...`).
- ECR repo exists (`hello-devops` in account 620356661348, region us-east-1).

```groovy
pipeline {
  agent any
  options { timestamps(); timeout(time: 40, unit: 'MINUTES') }
  environment {
    AWS_REGION   = "us-east-1"
    ECR_ACCOUNT  = "620356661348"
    ECR_REPO     = "hello-devops"
    IMAGE_TAG    = "${env.BUILD_NUMBER}"
    KUBECONFIG   = "/var/lib/jenkins/.kube/config"
    HELM_RELEASE = "hello-devops"
    CHART_DIR    = "charts/hello-devops"
  }
  stages {
    stage('Checkout') { steps { checkout scm } }
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
            helm upgrade --install "${HELM_RELEASE}" "${CHART_DIR}" \
              --namespace devops --create-namespace \
              --set image.repository="${ECR_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}" \
              --set image.tag="${IMAGE_TAG}" \
              --set service.nodePort=30080 \
              --set service.type=NodePort \
              --set imagePullSecrets[0].name=ecr-creds \
              --debug
          '''
        }
      }
    }
  }
  post {
    always { cleanWs() }
  }
}
```
- Explain: builds/tests Go app, builds image, logs into ECR with `aws-creds`, pushes, deploys via Helm to namespace `devops`, uses imagePullSecret `ecr-creds`, and cleans workspace.

10) CI/CD with GitHub and Webhooks
----------------------------------
- Create a GitHub token/webhook (Settings → Webhooks): payload URL `http://<jenkins>/github-webhook/`, content type JSON, trigger `push`/PR events.
- In Jenkins: install GitHub plugin; in job config, choose “GitHub hook trigger for GITScm polling”.
- Protect branches and require status checks before merge.

11) Integrations with Other DevOps Tools
----------------------------------------
- SCM: GitHub/GitLab/Bitbucket.
- Artifacts: Nexus/Artifactory/S3.
- Containers: Docker, ECR/GCR/ACR.
- K8s: Kubernetes plugin or Helm via shell; use kubeconfig/ServiceAccount tokens.
- Infra: Terraform/Ansible via pipelines (CLI).
- Observability: Prometheus/JMX Exporter; log forwarding to ELK/Loki.

12) Security, Credentials, and RBAC
-----------------------------------
- Enforce RBAC: use folders + Matrix/Auth strategies; avoid shared admin accounts; enable SSO/2FA.
- Credentials: store in Jenkins credentials store; scope narrowly; rotate regularly. Prefer cloud identities (OIDC/IRSA) when possible.
- Lock down script console/CLI; enable audit logs; restrict who can configure agents.
- Run agents as non-root; least-privileged mounts/tokens.

13) Best Practices for Enterprise Jenkins
-----------------------------------------
- Controller with 0 executors; use agents for builds.
- Pin plugins; keep minimal set; test upgrades in staging.
- Pipelines as code (`Jenkinsfile`); use shared libraries for common steps.
- Stage timeouts; retries only on safe steps; workspace cleanup (`cleanWs()`).
- Discard old builds/artifacts; monitor disk/CPU/RAM.

14) Common Issues and Troubleshooting
-------------------------------------
- Disk full: prune workspaces (`cleanWs`), remove old builds, `docker system prune`.
- Agents offline: check Java/SSH; verify labels; restart agent service.
- Credential errors: confirm credential ID matches Jenkinsfile; rotate keys.
- SCM webhook not firing: verify webhook URL reachable; check logs at `Manage Jenkins -> System Log`.
- K8s deploy failures: check kubeconfig permission, image pull secrets, and namespace existence.

15) Essential Jenkins Plugins and How to Install Them
-----------------------------------------------------
- Must-haves: Pipeline, Git/GitHub, Credentials Binding, Workspace Cleanup, Timestamper, ANSI Color.
- Container/K8s: Docker Pipeline, Kubernetes CLI/Plugin, Blue Ocean (optional UI).
- QA/Security: JUnit, Warnings NG, OWASP Dependency-Check (if needed).
- Notifications: Slack/Mattermost/Email.
- Artifact/Repo: Artifactory/Nexus/Config File Provider.
- Install via UI (most common):
  1) Manage Jenkins → Plugins → Available tab → search → check plugins → Install without restart (or with).
  2) On the Updates tab, keep versions pinned; avoid “select all” upgrades on prod. Test in staging first.
- Install via CLI (good for repeatability/automation):
  - Download CLI: `wget http://<jenkins>/jnlpJars/jenkins-cli.jar`
  - Install: `java -jar jenkins-cli.jar -s http://<jenkins> -auth user:token install-plugin git docker-workflow kubernetes -deploy`
  - List/update: `java -jar jenkins-cli.jar -s http://<jenkins> -auth user:token list-plugins`
- Install headlessly for containers (Docker images or offline envs):
  - Use the Plugin Installation Manager: `jenkins-plugin-cli --plugins "git:5.2.0 docker-workflow:1.31 kubernetes:4203.v1dd44f5b_1cf9"`
  - Build-time approach: add a `plugins.txt` and run `jenkins-plugin-cli --plugin-file plugins.txt` in your Dockerfile.
- After installs: restart only if Jenkins prompts. Verify on the Installed tab and keep a copy of your plugin list under version control.

16) Step-by-Step: Creating a Pipeline Job in Jenkins UI
-------------------------------------------------------
1. New Item → name → “Pipeline” → OK.
2. (Optional) Description, disable concurrent builds if not needed.
3. Pipeline definition: “Pipeline script from SCM”.
   - SCM: Git
   - Repository URL: your repo (e.g., `https://github.com/jitenderkalra/aws_lab.git`)
   - Branches: `*/main`
   - Script Path: `Jenkinsfile` (or your custom path)
4. Triggers: enable “GitHub hook trigger for GITScm polling” if using webhooks.
5. Save → Build Now. Watch console output.

Appendix: Credential IDs used in examples
-----------------------------------------
- `aws-creds`: Username = AWS_ACCESS_KEY_ID, Password = AWS_SECRET_ACCESS_KEY (for ECR login).
- `ecr-creds`: Docker registry secret in k8s (referenced by Helm chart).

Usage note: The provided pipeline (section 9) is ready to run against the repo in this project, assuming `aws-creds` exists in Jenkins, kubeconfig is at `/var/lib/jenkins/.kube/config`, and ECR/k3s are reachable.
