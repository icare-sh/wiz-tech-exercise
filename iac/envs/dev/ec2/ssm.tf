resource "aws_ssm_parameter" "mongodb_uri" {
  name        = "/wiz-exercise/dev/mongodb-uri"
  description = "MongoDB connection URI for the application"
  type        = "SecureString"
  value       = "mongodb://${var.mongo_admin_user}:${var.mongo_admin_password}@${aws_instance.mongo.private_ip}:27017/admin"

  tags = local.tags
}

resource "aws_ssm_parameter" "mongo_admin_user" {
  name        = "/wiz-exercise/dev/mongo-admin-user"
  description = "MongoDB admin username"
  type        = "SecureString"
  value       = var.mongo_admin_user

  tags = local.tags
}

resource "aws_ssm_parameter" "mongo_admin_password" {
  name        = "/wiz-exercise/dev/mongo-admin-password"
  description = "MongoDB admin password"
  type        = "SecureString"
  value       = var.mongo_admin_password

  tags = local.tags
}

resource "aws_ssm_parameter" "secret_key" {
  name        = "/wiz-exercise/dev/secret-key"
  description = "JWT secret key for the application"
  type        = "SecureString"
  value       = var.app_secret_key

  tags = local.tags
}
