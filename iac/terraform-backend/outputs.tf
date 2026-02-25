output "s3_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "backend_config" {
  description = "Backend configuration for Terraform modules (S3 native locking, no DynamoDB)"
  value = {
    bucket       = aws_s3_bucket.terraform_state.id
    region       = var.aws_region
    use_lockfile = true
    encrypt      = true
  }
}
