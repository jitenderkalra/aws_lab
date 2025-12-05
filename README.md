DevOps free-tier stack on AWS: Terraform provisions a single t2.micro with k3s, Docker, and Jenkins. Ansible configures the host. A tiny Go web app is built into a Docker image, deployed to k3s via Jenkins, with state stored in S3/DynamoDB and images in ECR.

## Prereqs
- AWS CLI configured with profile `devops-free-tier` (region `us-east-1` if using t2.micro free tier).
- S3 bucket `tf-state-devops-620356661348-ue1-20251205b` and DynamoDB table `tf-lock-devops-ue1-20251205b` (see `scripts/bootstrap-state.sh`).
- EC2 key pair `devops-jenkins` in the chosen region.
- Your public IP/CIDR to allow SSH/Jenkins/app access.

## Quick start
1) Bootstrap state (one-time):
   - `chmod +x scripts/bootstrap-state.sh`
   - `PROFILE=devops-free-tier REGION=us-east-1 ./scripts/bootstrap-state.sh`
2) Terraform:
   - `cd terraform`
   - `terraform init -reconfigure`
   - `terraform apply -var allowed_cidr=YOUR_PUBLIC_IP/32`
   - Note outputs: `public_ip`, `ecr_repository_url`.
3) Ansible:
   - Edit `ansible/inventory.ini`, replace `JENKINS_HOST` with the Terraform `public_ip`. Adjust `ansible_ssh_private_key_file` if your key is elsewhere.
   - Run `ANSIBLE_HOST_KEY_CHECKING=false ansible-playbook -i ansible/inventory.ini ansible/site.yml`
4) Jenkins initial setup (via `http://<public_ip>:8080`):
   - Retrieve admin password: `sudo cat /var/lib/jenkins/secrets/initialAdminPassword` (SSH to the host).
   - Create admin user; install suggested plugins.
   - Create credentials:
     - `aws-creds`: type “Username with password” → username=`AWS_ACCESS_KEY_ID`, password=`AWS_SECRET_ACCESS_KEY`.
   - Create a pipeline job pointing to this repo and use the provided `Jenkinsfile`.
5) Pipeline run:
   - The job will: run Go unit tests in Docker, build the image, login to ECR, push, render `k8s/deployment.yaml` with the pushed image, and apply Deployment + Service to k3s.
   - KUBECONFIG is set for Jenkins by Ansible at `/var/lib/jenkins/.kube/config`.
6) Access the app:
   - URL: `http://<public_ip>:30080/` → should return `Hello from DevOps stack!`
   - Jenkins UI: `http://<public_ip>:8080/`

## Paths
- Terraform: `terraform/main.tf`, variables in `terraform/variables.tf`.
- Ansible: `ansible/site.yml`, inventory at `ansible/inventory.ini`.
- App: `app/` (Go HTTP server), Dockerfile at `app/Dockerfile`.
- K8s: Helm chart at `charts/hello-devops` (NodePort 30080) deployed to namespace `devops`.
- CI: `Jenkinsfile` (expects Jenkins credentials `aws-creds`), uses Helm upgrade/install.

## Notes
- Instance: `t2.micro` in default VPC/subnet (free tier in us-east-1); SG opens 22/8080/30080 to `allowed_cidr`.
- IAM: instance profile includes ECR + SSM; ECR repo `hello-devops` is created by Terraform.
- State: stored in S3 bucket `tf-state-devops-620356661348-ue1-20251205b`, lock in DynamoDB `tf-lock-devops-ue1-20251205b`.
- Namespace: Helm creates/uses the `devops` namespace via `--namespace devops --create-namespace`.
