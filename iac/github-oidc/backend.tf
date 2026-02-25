terraform {
  backend "s3" {
    bucket       = "wiz-tech-exercise-terraform-state-324037288864"
    key          = "cicd/github-oidc/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
