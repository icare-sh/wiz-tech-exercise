output "cloudtrail_bucket_name" {
  description = "Name of the S3 bucket used for CloudTrail and Config logs"
  value       = aws_s3_bucket.cloudtrail_logs.id
}
