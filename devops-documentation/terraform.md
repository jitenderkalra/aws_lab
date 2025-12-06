# Terraform

Use these practices for enterprise Terraform: reproducible state, reviewed changes, and least-privilege IAM.

## State and Backends
- Use remote state with locking (S3 + DynamoDB, or equivalent); enable encryption and versioning.
- Separate state per environment/workload; avoid shared workspaces for prod/non-prod.
- Keep `.terraform.lock.hcl` in VCS; run `terraform init -upgrade` only when intentionally bumping providers.

### Example backend (S3 + DynamoDB)
```hcl
terraform {
  backend "s3" {
    bucket         = "my-tf-state"
    key            = "prod/network.tfstate"
    region         = "us-east-1"
    dynamodb_table = "my-tf-locks"
    encrypt        = true
  }
}
```

## Structure and Workflow
- Organize by environment (`envs/prod`, `envs/nonprod`), reuse modules, pin versions.
- Plan on PR, apply via CI on protected branches; never apply from laptops for shared envs.
- Tag resources (owner, env, app, cost-center); document destroy policies for prod.

### Common commands
```
terraform fmt -recursive
terraform init
terraform validate
terraform plan -var-file=envs/prod.tfvars
terraform apply -var-file=envs/prod.tfvars
terraform workspace list     # use only if truly needed
```

## Security
- Use OIDC/assumed roles for CI; avoid long-lived keys. Grant least-privilege IAM.
- No secrets in code; fetch from secret managers (`data "aws_ssm_parameter"`/Vault/etc.).
- Prefer managed policies; avoid `*` in prod policies. Enable CloudTrail/S3 access logging for audit.

## Modules and Versioning
- Create opinionated modules with clear inputs/outputs; pin module and provider versions.
- Use `moved` blocks for refactors to avoid resource recreation.
- Keep a changelog for modules; version via tags.

## Drift and Imports
- Detect drift with periodic `plan`; remediate via code, not consoles.
- Bring existing resources under management with `terraform import` + code + `moved` as needed.

## CI/CD Pattern
- Pre-commit: fmt, validate, tflint, security scan (tfsec/checkov).
- PR: `terraform plan` with sanitized output; require review.
- Merge: CI runs `apply` with the same vars; state locked during apply.

## Example: Minimal module usage
```hcl
provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  name    = "prod-vpc"
  cidr    = "10.0.0.0/16"
  azs     = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.11.0/24", "10.0.12.0/24"]
  enable_nat_gateway = true
  tags = {
    env   = "prod"
    owner = "platform"
  }
}
```
