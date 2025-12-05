terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.40"
    }
  }

  backend "s3" {
    bucket         = "tf-state-devops-620356661348-ue1-20251205b"
    key            = "devops-free-tier/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-lock-devops-ue1-20251205b"
    encrypt        = true
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  subnet_id      = tolist(data.aws_subnets.default.ids)[0]
  ecr_repo_name  = "hello-devops"
  instance_name  = "devops-jenkins-k3s"
}

resource "aws_security_group" "devops" {
  name        = "devops-jenkins-k3s-sg"
  description = "Allow SSH, Jenkins, and app NodePort"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  ingress {
    description = "App NodePort"
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.instance_name
  }
}

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name               = "devops-jenkins-k3s-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "devops-jenkins-k3s-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_ecr_repository" "app" {
  name                 = local.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "aws_instance" "devops" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [aws_security_group.devops.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2.name
  user_data = <<-EOF
              #!/bin/bash
              set -e
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              systemctl enable ssh
              systemctl restart ssh
              systemctl enable snap.amazon-ssm-agent.service || true
              systemctl start snap.amazon-ssm-agent.service || true
              systemctl enable amazon-ssm-agent || true
              systemctl start amazon-ssm-agent || true
              # ensure 2G swap for low-memory instances
              if [ ! -f /swapfile ]; then
                fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi
            EOF

  tags = {
    Name = local.instance_name
  }
}

resource "aws_eip" "devops" {
  domain = "vpc"
  tags = {
    Name = "${local.instance_name}-eip"
  }
}

resource "aws_eip_association" "devops" {
  instance_id   = aws_instance.devops.id
  allocation_id = aws_eip.devops.id
}

output "public_ip" {
  description = "Public IP of the Jenkins/k3s host"
  value       = aws_eip.devops.public_ip
}

output "ecr_repository_url" {
  description = "ECR URL for the app image"
  value       = aws_ecr_repository.app.repository_url
}
