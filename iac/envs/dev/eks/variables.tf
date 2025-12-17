variable "is_ci" {
  description = "Indicates if the deployment is running in CI (GitHub Actions)"
  type        = bool
  default     = false
}

variable "admin_user_arn" {
  description = "ARN of the admin user to grant access to (required if is_ci is true, to ensure local access)"
  type        = string
  default     = "arn:aws:iam::180294187104:user/odl_user_2001862"
}
