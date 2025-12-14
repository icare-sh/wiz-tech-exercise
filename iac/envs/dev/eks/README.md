# EKS Infrastructure

This directory contains the Terraform configuration for the EKS cluster.

## Components

- VPC with public, private, and intra subnets
- EKS cluster (Kubernetes 1.31)
- Managed node group (t3.medium)
- AWS Load Balancer Controller IAM role
- Core addons: CoreDNS, kube-proxy, vpc-cni

## Outputs

- VPC ID and subnet IDs
- EKS cluster endpoint and security groups
- Load Balancer Controller IAM role ARN

---

Last updated: 2025-12-14
