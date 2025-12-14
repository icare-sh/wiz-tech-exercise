terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  github_org  = "icare-sh"
  github_repo = "wiz-tech-exercise"
}

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = {
    Name        = "GitHub OIDC Provider"
    Environment = "ci-cd"
  }
}

resource "aws_iam_role" "github_actions" {
  name = "github-actions-wiz-tech-exercise"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${local.github_org}/${local.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "GitHub Actions Role"
    Environment = "ci-cd"
  }
}

resource "aws_iam_policy" "github_actions" {
  name        = "github-actions-wiz-tech-exercise"
  description = "Permissions for GitHub Actions CI/CD"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::wiz-tech-exercise-terraform-state-*",
          "arn:aws:s3:::wiz-tech-exercise-terraform-state-*/*"
        ]
      },
      {
        Sid    = "TerraformStateLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/wiz-tech-exercise-terraform-locks"
      },
      {
        Sid    = "InfrastructureManagement"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "iam:*",
          "s3:*",
          "ecr:*",
          "secretsmanager:*",
          "kms:*",
          "sts:GetCallerIdentity",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "logs:*",
          "ssm:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    Name        = "GitHub Actions Policy"
    Environment = "ci-cd"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "aws_secretsmanager_secret" "ssh_private_key" {
  name                    = "/wiz-tech-exercise/ssh-private-key"
  description             = "SSH private key for MongoDB EC2 access"
  recovery_window_in_days = 0

  tags = {
    Name        = "MongoDB SSH Private Key"
    Environment = "ci-cd"
  }
}

resource "aws_secretsmanager_secret_version" "ssh_private_key" {
  secret_id     = aws_secretsmanager_secret.ssh_private_key.id
  secret_string = tls_private_key.ssh.private_key_openssh
}

resource "aws_secretsmanager_secret" "ssh_public_key" {
  name                    = "/wiz-tech-exercise/ssh-public-key"
  description             = "SSH public key for MongoDB EC2 access"
  recovery_window_in_days = 0

  tags = {
    Name        = "MongoDB SSH Public Key"
    Environment = "ci-cd"
  }
}

resource "aws_secretsmanager_secret_version" "ssh_public_key" {
  secret_id     = aws_secretsmanager_secret.ssh_public_key.id
  secret_string = tls_private_key.ssh.public_key_openssh
}

resource "random_password" "ansible_vault" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "ansible_vault_password" {
  name                    = "/wiz-tech-exercise/ansible-vault-password"
  description             = "Ansible Vault password for MongoDB secrets"
  recovery_window_in_days = 0

  tags = {
    Name        = "Ansible Vault Password"
    Environment = "ci-cd"
  }
}

resource "aws_secretsmanager_secret_version" "ansible_vault_password" {
  secret_id     = aws_secretsmanager_secret.ansible_vault_password.id
  secret_string = random_password.ansible_vault.result
}

