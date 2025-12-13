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
    "kubernetes.io/cluster/${local.name}" = "owned"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"     = 1
    "kubernetes.io/cluster/${local.name}" = "owned"
  }

  tags = local.tags
}

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

  # Enable Access Entries for IAM authentication
  authentication_mode = "API_AND_CONFIG_MAP"
  
  # Allow the creator of the cluster (Terraform user) to be admin
  enable_cluster_creator_admin_permissions = true

  access_entries = {
    # Example to add an extra admin user if needed explicitly
    # viewer = {
    #   kubernetes_groups = []
    #   principal_arn     = "arn:aws:iam::123456789012:role/something"
    #   policy_associations = {
    #     example = {
    #       policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
    #       access_scope = {
    #         namespaces = ["default"]
    #         type       = "namespace"
    #       }
    #     }
    #   }
    # }
  }

  addons = {
    coredns = {
      most_recent = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    kube-proxy = {
      most_recent = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
    vpc-cni = {
      most_recent = true
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
    }
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
