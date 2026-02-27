variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket for CloudTrail logs"
  type        = string
  default     = "wiz-securelabs-cloudtrail-logs-324037288864"
}

variable "email_address" {
  description = "Email address for security alerts"
  type        = string
  default     = "admin@example.com" # Placeholder, user should update via tfvars
}
