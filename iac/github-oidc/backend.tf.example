terraform {
  backend "s3" {
    bucket         = "wiz-tech-exercise-terraform-state-180294187104"
    key            = "cicd/github-oidc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "wiz-tech-exercise-terraform-locks"
    encrypt        = true
  }
}
