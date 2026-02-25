resource "aws_ssm_parameter" "mongodb_uri" {
  name        = "/wiz-exercise/dev/mongodb-uri"
  description = "MongoDB connection URI for the application"
  type        = "SecureString"
  value       = "mongodb://${var.mongo_admin_user}:${var.mongo_admin_password}@${aws_instance.mongo.private_ip}:27017/admin"

  tags = local.tags
}

resource "aws_ssm_parameter" "secret_key" {
  name        = "/wiz-exercise/dev/secret-key"
  description = "JWT secret key for the application"
  type        = "SecureString"
  value       = var.app_secret_key

  tags = local.tags
}
