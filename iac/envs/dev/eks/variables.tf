variable "is_ci" {
  description = "Indicates if the deployment is running in CI (GitHub Actions)"
  type        = bool
  default     = false
}

variable "admin_user_arn" {
  description = "ARN of the admin user to grant access to (required if is_ci is true, to ensure local access)"
  type        = string
  default     = "arn:aws:iam::324037288864:user/odl_user_2094111"
}

variable "falco_alert_email" {
  description = "Email address to receive Falco runtime security alerts"
  type        = string
  default     = "sabir.mba@protonmail.com"
}

variable "ses_sender_email" {
  description = "SES verified sender email for Falco alerts"
  type        = string
  default     = "falco-alerts@wiz-exercise.dev"
}
