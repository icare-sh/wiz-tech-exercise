# Wiz Tech Exercise - Cloud Security Assessment

Infrastructure intentionally vulnerable for security assessment and DevSecOps demonstration.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub Actions (CI/CD)                                     │
│  ├─ IaC Pipeline: Terraform + Ansible                       │
│  └─ App Pipeline: Docker Build + ECR + Helm Deploy          │
└──────────────────┬──────────────────────────────────────────┘
                   │ (OIDC - No AWS Credentials)
                   ▼
┌─────────────────────────────────────────────────────────────┐
│  AWS Account                                                │
│                                                             │
│  ┌─────────────────┐  ┌────────────────────────────────┐  │
│  │  Remote State   │  │  Secrets Manager               │  │
│  │  ├─ S3 Bucket   │  │  ├─ SSH Private Key            │  │
│  │  └─ DynamoDB    │  │  └─ Ansible Vault Password     │  │
│  └─────────────────┘  └────────────────────────────────┘  │
│                                                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │  VPC (10.123.0.0/16)                                  │ │
│  │                                                       │ │
│  │  ┌──────────────┐         ┌────────────────────────┐ │ │
│  │  │ Public       │         │ Private Subnets        │ │ │
│  │  │ Subnet       │         │                        │ │ │
│  │  │              │         │  ┌──────────────────┐  │ │ │
│  │  │ ┌──────────┐ │         │  │ EKS Cluster 1.31 │  │ │ │
│  │  │ │ MongoDB  │ │         │  │                  │  │ │ │
│  │  │ │ EC2      │◄┼─────────┼──┤ ├─ Worker Nodes  │  │ │ │
│  │  │ │ Ubuntu   │ │ Port    │  │ ├─ Go Web App    │  │ │ │
│  │  │ │ 20.04    │ │ 27017   │  │ └─ ALB Ingress   │  │ │ │
│  │  │ └──────────┘ │         │  └──────────────────┘  │ │ │
│  │  │      │       │         │           │            │ │ │
│  │  │      │       │         └───────────┼────────────┘ │ │
│  │  └──────┼───────┘                     │              │ │
│  │         │                             │              │ │
│  └─────────┼─────────────────────────────┼──────────────┘ │
│            │                             │                │
│            ▼                             ▼                │
│  ┌─────────────────┐         ┌─────────────────────────┐ │
│  │ S3 Bucket       │         │ ALB (Public)            │ │
│  │ (Backups)       │         │ http://alb-xyz.aws.com  │ │
│  │ PUBLIC READ     │         └─────────────────────────┘ │
│  └─────────────────┘                                      │
│                                                           │
│  ┌─────────────────┐                                     │
│  │ ECR             │                                     │
│  │ (Docker Images) │                                     │
│  └─────────────────┘                                     │
└───────────────────────────────────────────────────────────┘
```

### Intentional Vulnerabilities ("Weak by Design")

- **MongoDB VM**: SSH open to `0.0.0.0/0`, IAM `AdministratorAccess`, outdated OS/DB
- **S3 Backups**: Public read + public listing
- **Kubernetes**: App ServiceAccount has `cluster-admin` role
- **Ingress**: Public ALB exposure

---

## Prerequisites

### For Local Deployment

```bash
# Required tools
- AWS CLI configured (profile: wiz)
- Terraform >= 1.5
- Ansible >= 2.15
- Docker
- kubectl
- Helm 3
- SSH key pair (~/.ssh/id_ed25519)
```

### For CI/CD Deployment

```bash
# Required
- GitHub repository with Actions enabled
- AWS account with admin access
- Git CLI
```

---

## Option 1: Local Deployment

### Step 1: Setup Remote Backend

**Why**: Persist Terraform state for future updates/destroys.

```bash
cd /home/sabir/dev/wiz-tech-exercise
AWS_PROFILE=wiz ./scripts/setup-backend.sh
```

### Step 2: Deploy Infrastructure

```bash
# Deploy EKS + EC2 + MongoDB + App
AWS_PROFILE=wiz make deploy-all
```

**Duration**: ~20-25 minutes

**What happens**:
1. ✅ EKS cluster (VPC, subnets, nodes, ALB Controller)
2. ✅ EC2 MongoDB VM (Ubuntu 20.04, MongoDB 4.4)
3. ✅ Ansible configures MongoDB (auth, backups to S3)
4. ✅ Docker build + push to ECR
5. ✅ Helm deploys app to Kubernetes (see detailed secure step below)
6. ✅ ALB Ingress exposes app publicly

### Step 2b: Secure Helm Deployment (Manual)

Instead of the generic `make helm-deploy`, use a secret override file to avoid shell history issues with passwords:

1. Create `iac/kubernetes/app/values-override.yaml`:
   ```yaml
   image:
     repository: 180294187104.dkr.ecr.us-east-1.amazonaws.com/wiz-securelabs-app
     tag: "YOUR_IMAGE_TAG" # e.g., 20251216...
   
   service:
     targetPort: 8080 # Go App port
   
   mongodb:
     host: "10.123.1.208" # MongoDB Private IP
     password: "SuperSecretPassword123!"
   
   secrets:
     secretKey: "dev-secret-key-2024"
   ```

2. Deploy securely:
   ```bash
   cd iac/kubernetes/app
   helm upgrade --install wiz-app . \
     -f values-dev.yaml \
     -f values-override.yaml \
     --wait
   ```

### Step 3: Get Application URL

```bash
AWS_PROFILE=wiz make helm-status
```

Look for the ALB hostname (e.g., `http://k8s-default-abc123.us-east-1.elb.amazonaws.com`)

### Step 4: Destroy Everything

```bash
AWS_PROFILE=wiz make clean-all
```

---

## Option 2: CI/CD Deployment (GitHub Actions)

### Step 1: Setup Remote Backend

**Same as local - run this once**:

```bash
AWS_PROFILE=wiz ./scripts/setup-backend.sh
```

### Step 2: Configure GitHub Repository

Edit `iac/github-oidc/main.tf`:

```hcl
locals {
  github_org  = "your-github-username"    # ← Change this
  github_repo = "wiz-tech-exercise"        # ← Change if different
}
```

### Step 3: Deploy CI/CD Infrastructure

```bash
cd iac/github-oidc
AWS_PROFILE=wiz terraform init
AWS_PROFILE=wiz terraform apply
```

**What this creates**:
- GitHub OIDC Provider (no AWS credentials needed in GitHub)
- IAM Role for GitHub Actions
- SSH Key (auto-generated, stored in Secrets Manager)
- Ansible Vault Password (auto-generated, stored in Secrets Manager)

### Step 4: Configure Secrets

#### 4a. Re-encrypt Ansible Vault

```bash
# Get auto-generated vault password
AWS_PROFILE=wiz terraform output -raw ansible_vault_password > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Re-encrypt vault with this password
cd ../envs/dev/ansible
ansible-vault rekey group_vars/mongo/vault.yml --vault-password-file ~/.ansible_vault_pass
```

#### 4b. Update EC2 Terraform Configs

```bash
cd ../../github-oidc

# Get SSH public key
AWS_PROFILE=wiz terraform output -raw ssh_public_key
```

Copy output and add to `iac/envs/dev/ec2/terraform.tfvars`:

```hcl
mongo_ssh_public_key = "ssh-ed25519 AAAA... (paste here)"
```

#### 4c. Add GitHub Secret

```bash
# Get IAM Role ARN
AWS_PROFILE=wiz terraform output github_actions_role_arn
```

1. Go to GitHub repo → **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add:
   - **Name**: `AWS_GITHUB_ACTIONS_ROLE_ARN`
   - **Value**: (paste ARN from above)

### Step 5: Create GitHub Environment

1. Go to **Settings** → **Environments**
2. Click **New environment**
3. Name: `production`
4. Click **Configure environment**
5. (Optional) Enable protections:
   - ✅ Required reviewers: 1
   - ✅ Deployment branches: `main` only

### Step 6: Push and Deploy

```bash
git add .
git commit -m "feat: CI/CD setup complete"
git push origin main
```

**What happens automatically**:
1. ✅ GitHub Actions triggers
2. ✅ Authenticates via OIDC (no credentials!)
3. ✅ Deploys EKS infrastructure
4. ✅ Deploys EC2 + MongoDB
5. ✅ Runs Ansible configuration
6. ✅ Builds and pushes Docker image
7. ✅ Deploys app via Helm
8. ✅ Creates ALB Ingress

### Step 7: Get Application URL

Go to GitHub Actions → Latest workflow run → `deploy-helm` job → Logs

Look for: `Application URL: http://k8s-default-xyz.elb.amazonaws.com`

---

## Testing Changes

### Test Infrastructure Changes (PR)

```bash
git checkout -b test-infra
# Make changes to iac/envs/dev/eks/* or iac/envs/dev/ec2/*
git add .
git commit -m "test: infrastructure change"
git push origin test-infra
```

Create PR on GitHub → Terraform plan will run automatically

### Test App Changes (Main)

```bash
# Make changes to app/*
git add .
git commit -m "feat: new feature"
git push origin main
```

App will be built, scanned, and deployed automatically

---

##  Verify Deployment

### Check Infrastructure

```bash
# EKS Cluster
AWS_PROFILE=wiz aws eks list-clusters

# EC2 Instance
AWS_PROFILE=wiz aws ec2 describe-instances --filters "Name=tag:Name,Values=*mongo*"

# S3 Backup Bucket
AWS_PROFILE=wiz aws s3 ls | grep mongo-backups
```

### Check Kubernetes

```bash
# Update kubeconfig
AWS_PROFILE=wiz aws eks update-kubeconfig --region us-east-1 --name wiz_cluster_eks

# Check pods
kubectl get pods

# Check ingress
kubectl get ingress

# Get ALB URL
kubectl get ingress -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}'
```

### SSH into MongoDB VM

```bash
# Get VM IP
cd iac/envs/dev/ec2
AWS_PROFILE=wiz terraform output mongo_public_ip

# SSH (using your local key)
ssh -i ~/.ssh/id_ed25519 ubuntu@<MONGO_IP>

# Or using CI/CD generated key
AWS_PROFILE=wiz aws secretsmanager get-secret-value \
  --secret-id /wiz-tech-exercise/ssh-private-key \
  --query SecretString --output text > /tmp/mongo-key
chmod 600 /tmp/mongo-key
ssh -i /tmp/mongo-key ubuntu@<MONGO_IP>
```

---

##  Cleanup

### Destroy All Infrastructure

**Local**:
```bash
AWS_PROFILE=wiz make clean-all
```

**CI/CD**: 
1. Manually run destroy via Terraform locally (GitHub Actions doesn't have destroy workflow)
2. Or add a manual workflow trigger for destroy

### Remove Backend Infrastructure (Optional)

⚠️ Only do this if you want to completely remove the project:

```bash
cd iac/terraform-backend
AWS_PROFILE=wiz terraform destroy
```

---

## 🔧 Troubleshooting

### "Backend not initialized"

```bash
cd iac/envs/dev/eks  # or ec2
terraform init
```

### "State lock timeout"

```bash
# Find lock ID
AWS_PROFILE=wiz aws dynamodb scan --table-name wiz-tech-exercise-terraform-locks

# Force unlock
cd iac/envs/dev/eks
AWS_PROFILE=wiz terraform force-unlock <LOCK_ID>
```

### Terraform State Issues

**State corruption (checksum mismatch)**:
```bash
# Error: "state data in S3 does not have the expected content"
# This happens when S3 and DynamoDB checksums are out of sync

# Fix automatically
AWS_PROFILE=wiz make fix-state-corruption

# Or manually
AWS_PROFILE=wiz aws dynamodb delete-item \
  --table-name wiz-tech-exercise-terraform-locks \
  --key '{"LockID":{"S":"wiz-tech-exercise-terraform-state-180294187104/dev/eks/terraform.tfstate-md5"}}'
```

**Verify state is in S3**:
```bash
# Check all states
AWS_PROFILE=wiz make verify-states

# Manually verify
AWS_PROFILE=wiz aws s3 ls s3://wiz-tech-exercise-terraform-state-180294187104/ --recursive

# Pull latest state
cd iac/envs/dev/eks && terraform init -reconfigure
cd iac/envs/dev/ec2 && terraform init -reconfigure
```

**Check state contents**:
```bash
# List resources in state
terraform -chdir=iac/envs/dev/eks state list
terraform -chdir=iac/envs/dev/ec2 state list

# View specific resource
terraform -chdir=iac/envs/dev/eks state show module.eks.aws_eks_cluster.this[0]
```

**Important State Management Rules**:
- ✅ Always use `-reconfigure` with `terraform init` to pull latest S3 state
- ✅ CI/CD automatically verifies state after apply
- ❌ Never commit local `terraform.tfstate` files
- ❌ Never manually edit S3 state files

### GitHub Actions: "Unable to assume role"

1. Verify secret `AWS_GITHUB_ACTIONS_ROLE_ARN` exists in GitHub
2. Check OIDC provider exists:
   ```bash
   AWS_PROFILE=wiz aws iam list-open-id-connect-providers
   ```
3. Verify role trust policy includes your GitHub repo

### ALB not provisioning

```bash
# Check ALB Controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Check pods are running
kubectl get pods -n kube-system | grep aws-load-balancer
```

### MongoDB connection issues

```bash
# Test from Kubernetes pod
kubectl run -it --rm mongo-test --image=mongo:4.4 --restart=Never -- \
  mongosh "mongodb://admin:SuperSecretPassword123!@<MONGO_PRIVATE_IP>:27017"
```

---

## Project Structure

```
.
├── .github/workflows/       # CI/CD pipelines
│   ├── iac-cicd.yml        # Infrastructure deployment
│   └── app-cicd.yml        # Application deployment
├── app/                     # Go web application
├── iac/
│   ├── terraform-backend/   # S3 + DynamoDB for remote state
│   ├── github-oidc/        # OIDC provider + IAM + secrets
│   ├── envs/dev/
│   │   ├── eks/            # EKS cluster
│   │   ├── ec2/            # MongoDB VM + ECR + S3
│   │   └── ansible/        # MongoDB configuration
│   └── kubernetes/app/     # Helm chart
├── scripts/
│   └── setup-backend.sh    # Automated backend setup
├── docs/
│   └── CICD_SETUP.md       # Detailed CI/CD guide
└── Makefile                # Automation commands
```

---

## Milestones Completed

- [x] **Milestone 1**: EKS Cluster (VPC, subnets, nodes)
- [x] **Milestone 2**: MongoDB VM (weak by design) + Ansible config
- [x] **Milestone 3**: Daily backups to public S3
- [x] **Milestone 4**: App containerization + Helm + ALB Ingress
- [x] **Milestone 5**: CI/CD (IaC + App) with OIDC + Remote State

---

## Additional Documentation

- **[CI/CD Setup Guide](docs/CICD_SETUP.md)**: Detailed CI/CD configuration
- **[Backend README](iac/terraform-backend/README.md)**: Remote state setup

---

## Security Note

This infrastructure is intentionally vulnerable for educational purposes. **DO NOT use in production**.
