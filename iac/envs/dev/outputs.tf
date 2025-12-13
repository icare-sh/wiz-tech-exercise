output "region" {
    description = "AWS region used for the deployment."
    value       = local.region
  }
  
  output "vpc_id" {
    description = "VPC ID."
    value       = module.vpc.vpc_id
  }
  
  output "public_subnet_ids" {
    description = "Public subnet IDs (for public load balancers)."
    value       = module.vpc.public_subnets
  }
  
  output "private_subnet_ids" {
    description = "Private subnet IDs (for EKS nodes/workloads)."
    value       = module.vpc.private_subnets
  }
  
  output "intra_subnet_ids" {
    description = "Intra subnet IDs (used here for EKS control plane ENIs)."
    value       = module.vpc.intra_subnets
  }
  
  output "eks_cluster_name" {
    description = "EKS cluster name."
    value       = module.eks.cluster_name
  }
  
  output "eks_cluster_endpoint" {
    description = "EKS API server endpoint."
    value       = module.eks.cluster_endpoint
  }
  
  output "eks_cluster_security_group_id" {
    description = "Security group ID associated with the EKS cluster."
    value       = module.eks.cluster_security_group_id
  }
  
  output "eks_node_security_group_id" {
    description = "Security group ID shared by EKS worker nodes."
    value       = module.eks.node_security_group_id
  }
  
  output "kubectl_update_kubeconfig_command" {
    description = "Helper command to configure kubectl for this cluster."
    value       = "aws eks update-kubeconfig --region ${local.region} --name ${module.eks.cluster_name}"
  }
  