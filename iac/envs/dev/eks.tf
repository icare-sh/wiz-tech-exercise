locals {
  name   = "wiz_cluster_eks"
  region = "us-east-1"

  vpc_cidr = "10.123.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["10.123.1.0/24", "10.123.2.0/24"]
  private_subnets = ["10.123.3.0/24", "10.123.4.0/24"]
  intra_subnets   = ["10.123.5.0/24", "10.123.6.0/24"]

  tags = {
    Example   = local.name
    ManagedBy = "Terraform"
  }
}

#checkov:skip=CKV_TF_1: "Module pinned via Terraform Registry version (accepted risk)"
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.5.1"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway = true
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"              = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"     = 1
    "kubernetes.io/cluster/${local.name}" = "shared"
  }

  tags = local.tags
}

#checkov:skip=CKV_TF_1: "Module pinned via Terraform Registry version (accepted risk)"
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.8.0"

  name               = local.name
  kubernetes_version = "1.34"

  endpoint_public_access  = true
  endpoint_private_access = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  enable_irsa = true

  cluster_addons = {
    coredns    = { most_recent = true }
    kube-proxy = { most_recent = true }
    vpc-cni    = { most_recent = true }
  }

  eks_managed_node_groups = {
    default = {
      name = "${local.name}-mng"

      ami_type = "AL2023_x86_64_STANDARD"

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      desired_size = 1
      min_size     = 1
      max_size     = 2

      disk_size  = 20
      subnet_ids = module.vpc.private_subnets

      tags = merge(local.tags, {
        ExtraTag = "Eks Cluster devsecops"
      })
    }
  }

  tags = local.tags
}
