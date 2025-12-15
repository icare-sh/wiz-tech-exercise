variable "vpc_id" {
  description = "VPC ID from EKS deployment"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for EC2 instance"
  type        = string
}

variable "mongo_source_node_sg_id" {
  description = "EKS nodes security group ID for MongoDB access"
  type        = string
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


