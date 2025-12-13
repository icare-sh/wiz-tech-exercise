# Wiz Tech Exercise

Implementation of an intentionally exposed AWS cloud environment to demonstrate Cloud Native Security and DevSecOps best practices.

## Prerequisites

- AWS CLI configured with SSO profile `wiz`
- Terraform >= 1.5
- Ansible >= 2.15
- Docker
- kubectl
- Helm 3
- Trivy (for security scanning)
- SSH key pair (`~/.ssh/id_ed25519`)

## Quick Start

### Full Deployment (One Command)

```bash
AWS_PROFILE=wiz make deploy-all
```

**Duration**: ~20-25 minutes

**Steps executed**:
1. Deploy EKS cluster (VPC, subnets, node groups, addons)
2. Deploy EC2 MongoDB instance (outdated Ubuntu 20.04, weak security)
3. Configure Ansible inventory dynamically
4. Install MongoDB 4.4 via Ansible (with authentication + daily S3 backups)
5. Build and push Docker image to ECR
6. Deploy AWS Load Balancer Controller via Helm
7. Deploy application via Helm (with Ingress + ALB)

### Manual Step-by-Step Deployment

#### 1. Infrastructure Setup

```bash
AWS_PROFILE=wiz make eks-apply
AWS_PROFILE=wiz make ec2-apply
```

**Wait**: ~12-15 minutes for EKS cluster readiness.

#### 2. MongoDB Configuration

```bash
AWS_PROFILE=wiz make ansible-setup
AWS_PROFILE=wiz make ansible-run
```

**Vault Password**: Provide Ansible Vault password when prompted.

#### 3. Application Deployment

```bash
AWS_PROFILE=wiz make app-build
AWS_PROFILE=wiz make app-push
AWS_PROFILE=wiz make helm-setup
AWS_PROFILE=wiz make helm-deploy
```

#### 4. Verify Deployment

```bash
AWS_PROFILE=wiz make helm-status
```

**Access the application**: Use the ALB hostname from `helm-status` output.

## Configuration Files

### Terraform Variables

Create `iac/envs/dev/ec2/terraform.tfvars`:

```hcl
mongo_ssh_public_key = "ssh-ed25519 AAAA... your-user@host"
```

### Ansible Vault

Secrets are stored in `iac/envs/dev/ansible/group_vars/mongo/vault.yml` (encrypted).

To edit:

```bash
ansible-vault edit iac/envs/dev/ansible/group_vars/mongo/vault.yml
```

## Makefile Targets

### Infrastructure

- `make eks-apply`: Deploy EKS cluster
- `make ec2-apply`: Deploy EC2 MongoDB instance
- `make eks-destroy`: Destroy EKS cluster
- `make ec2-destroy`: Destroy EC2 instance

### Application

- `make app-build`: Build Docker image locally
- `make app-push`: Push image to ECR
- `make app-scan`: Run Trivy security scan

### Ansible

- `make ansible-setup`: Update inventory with Terraform outputs
- `make ansible-run`: Execute MongoDB installation playbook

### Kubernetes

- `make helm-setup`: Add Helm repos and configure kubectl
- `make helm-deploy`: Deploy ALB Controller + Application
- `make helm-status`: Show pods, services, ingress, and ALB URL

### Utilities

- `make deploy-all`: Full automated deployment
- `make clean-all`: Destroy all infrastructure

## Architecture

### Network

- **VPC**: 10.123.0.0/16
- **Public Subnets**: 3 AZs (ALB, NAT Gateways)
- **Private Subnets**: 3 AZs (EKS worker nodes)
- **Intra Subnets**: 3 AZs (EKS control plane)

### Security (Intentional Weaknesses)

- **EC2 MongoDB**:
  - SSH open to `0.0.0.0/0`
  - IAM role with `AdministratorAccess`
  - Outdated Ubuntu 20.04
  - Outdated MongoDB 4.4
  - S3 backups publicly readable
- **Kubernetes**:
  - Application ServiceAccount has `cluster-admin` role
  - Ingress exposed via public ALB

### Components

- **EKS Cluster**: Kubernetes 1.31
- **MongoDB**: 4.4 on EC2 (t3.micro)
- **Application**: Go web app in private subnet
- **Load Balancer**: AWS ALB via Ingress Controller
- **Container Registry**: AWS ECR
- **Backups**: Daily MongoDB dumps to S3 (public-read)

## CI/CD

GitHub Actions workflow (`.github/workflows/pr-app.yml`) runs on PRs:
- Docker build
- Trivy security scan

## Troubleshooting

### EKS Cluster Access

```bash
AWS_PROFILE=wiz aws eks update-kubeconfig --region us-east-1 --name wiz_cluster_eks
```

### Ansible Connection Issues

Verify EC2 instance is running and SSH key is correct:

```bash
AWS_PROFILE=wiz terraform -chdir=iac/envs/dev/ec2 output mongo_public_ip
ssh -i ~/.ssh/id_ed25519 ubuntu@<IP>
```

### ALB Not Provisioning

Check ALB Controller logs:

```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

Verify IAM role has correct permissions and IRSA is configured.

### MongoDB Connection

Test from EKS pod:

```bash
kubectl run -it --rm mongo-test --image=mongo:4.4 --restart=Never -- \
  mongosh "mongodb://admin:SuperSecretPassword123!@<MONGO_PRIVATE_IP>:27017"
```

## Project Structure

```
.
├── app/                          # Go web application
├── iac/
│   ├── envs/dev/
│   │   ├── eks/                  # EKS Terraform module
│   │   ├── ec2/                  # EC2 + ECR Terraform module
│   │   └── ansible/              # MongoDB configuration
│   └── kubernetes/
│       └── app/                  # Helm chart for application
├── .github/workflows/            # CI/CD pipelines
└── Makefile                      # Automation commands
```

## License

This project is for educational purposes only. Do not use in production.
