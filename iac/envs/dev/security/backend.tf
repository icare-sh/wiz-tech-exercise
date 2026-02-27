terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "wiz-tech-exercise-terraform-state-324037288864"
    key            = "dev/security/terraform.tfstate"
    region         = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "dev"
      Project     = "wiz-tech-exercise"
      Team        = "SecOps"
      ManagedBy   = "Terraform"
    }
  }
}
