

variable "mongo_ssh_public_key" {
  description = "SSH public key (OpenSSH) for Mongo EC2 access"
  type        = string
}

variable "mongo_instance_type" {
  description = "EC2 instance type for Mongo"
  type        = string
  default     = "t3.micro"
}

variable "mongo_disk_size_gb" {
  description = "Root volume size in GB"
  type        = number
  default     = 20
}

variable "mongo_key_pair_name" {
  description = "Existing EC2 key pair name to attach"
  type        = string
  default     = "vm-mongo.key"
}

variable "mongo_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "mongo_admin_user" {
  description = "MongoDB admin username"
  type        = string
  default     = "admin"
}

variable "mongo_admin_password" {
  description = "MongoDB admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "app_secret_key" {
  description = "JWT secret key for the application"
  type        = string
  sensitive   = true
  default     = ""
}


