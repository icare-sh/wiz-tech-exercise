output "mongo_private_ip" {
  value = aws_instance.mongo.private_ip
}

output "mongo_public_ip" {
  description = "Public IP address of the Mongo instance"
  value       = aws_instance.mongo.public_ip
}

output "mongo_ssh_user" {
  description = "SSH username for the Mongo instance"
  value       = "ubuntu"
}

output "mongo_sg_id" {
  value = aws_security_group.mongo.id
}

output "backup_bucket_name" {
  description = "Name of the S3 bucket for Mongo backups"
  value       = aws_s3_bucket.backups.id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the application"
  value       = aws_ecr_repository.app.repository_url
}

