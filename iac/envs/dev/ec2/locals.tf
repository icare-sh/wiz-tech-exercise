locals {
  name   = "wiz_mongo_ec2"
  region = "us-east-1"

  tags = {
    Example   = local.name
    ManagedBy = "Terraform"
  }
}





