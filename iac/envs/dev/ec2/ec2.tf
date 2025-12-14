/*
 * Retrieves outputs (VPC ID, Subnets, Security Groups) from the previously applied EKS layer.
 * Allows this module to deploy the EC2 instance into the existing network infrastructure.
 */
data "terraform_remote_state" "eks" {
  backend = "local"

  config = {
    path = "../eks/terraform.tfstate"
  }
}

data "aws_ami" "ubuntu_2004" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  mongo_node_sg_id = coalesce(var.mongo_source_node_sg_id, data.terraform_remote_state.eks.outputs.eks_node_security_group_id)
}

resource "aws_security_group" "mongo" {
  name        = "${local.name}-mongo-sg"
  description = "Mongo weak-by-design: SSH public, Mongo restricted to EKS nodes"
  vpc_id      = data.terraform_remote_state.eks.outputs.vpc_id

  tags = merge(local.tags, {
    Name = "${local.name}-mongo-sg"
  })
}

resource "aws_security_group_rule" "mongo_ssh_internet" {
  type              = "ingress"
  security_group_id = aws_security_group.mongo.id
  description       = "Weak control: SSH exposed to internet"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.mongo_ssh_cidr_blocks
}

resource "aws_security_group_rule" "mongo_from_eks_nodes" {
  type                     = "ingress"
  security_group_id        = aws_security_group.mongo.id
  description              = "Mongo allowed only from EKS node security group"
  from_port                = 27017
  to_port                  = 27017
  protocol                 = "tcp"
  source_security_group_id = local.mongo_node_sg_id
}

resource "aws_security_group_rule" "mongo_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.mongo.id
  description       = "Allow all egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

data "aws_iam_policy" "admin" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_iam_role" "mongo" {
  name = "${local.name}-mongo-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "mongo_admin" {
  role       = aws_iam_role.mongo.name
  policy_arn = data.aws_iam_policy.admin.arn
}

resource "aws_iam_instance_profile" "mongo" {
  name = "${local.name}-mongo-profile"
  role = aws_iam_role.mongo.name
}

locals {
  mongo_user_data = <<-EOF
	#!/bin/bash
	set -euo pipefail
	export DEBIAN_FRONTEND=noninteractive
	apt-get update -y
	apt-get install -y python3 python3-pip
  EOF
}

resource "aws_key_pair" "mongo" {
  key_name   = var.mongo_key_pair_name
  public_key = var.mongo_ssh_public_key
  tags       = local.tags
}

resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.ubuntu_2004.id
  instance_type               = var.mongo_instance_type
  subnet_id                   = data.terraform_remote_state.eks.outputs.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.mongo.id]
  key_name                    = aws_key_pair.mongo.key_name
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.mongo.name

  user_data = local.mongo_user_data

  root_block_device {
    volume_size = var.mongo_disk_size_gb
    volume_type = "gp3"
  }

  tags = merge(local.tags, {
    Name = "${local.name}-mongo"
  })
}

