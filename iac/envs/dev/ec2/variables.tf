variable "mongo_source_node_sg_id" {
  description = "Override for Mongo allowed source security group (defaults to EKS nodes SG)"
  type        = string
  default     = null
}

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


