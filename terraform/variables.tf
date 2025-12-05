variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "devops-free-tier"
}

variable "allowed_cidr" {
  description = "CIDR allowed to access SSH, Jenkins, and app NodePort"
  type        = string
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name in the chosen region"
  type        = string
  default     = "devops-jenkins"
}

variable "instance_type" {
  description = "EC2 instance type (must be free-tier eligible)"
  type        = string
  default     = "t3.micro"
}
