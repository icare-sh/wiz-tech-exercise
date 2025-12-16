data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = "wiz-tech-exercise-terraform-state-180294187104"
    key    = "dev/eks/terraform.tfstate"
    region = "us-east-1"
  }
}
