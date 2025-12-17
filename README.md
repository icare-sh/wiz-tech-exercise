# Wiz Tech Exercise - SecOps Deployment

This project deploys a Go application ("Wiz Exercise App") connected to MongoDB on AWS EKS, with a complete DevSecOps CI/CD pipeline.

## Prerequisites

Before starting, ensure you have installed:

*   **Infrastructure as Code**: Terraform (>= 1.5)
*   **Containers & K8s**: Docker, Helm, kubectl
*   **Cloud**: AWS CLI (configured with your credentials)
*   **Automation**: Make

---

## Local Deployment (Development)

To test and develop locally without using CI.

### 1. Deploy Infrastructure
Deploy resources in this order (Network/EKS first, then EC2/Mongo + Security).

```bash
# 1. Security (CloudTrail, Config, GuardDuty)
cd iac/envs/dev/security
terraform init && terraform apply -auto-approve

# 2. EKS Cluster
cd ../eks
terraform init && terraform apply -auto-approve

# 3. Database (EC2 Mongo + ECR)
cd ../ec2
terraform init && terraform apply -auto-approve
```

### 2. Configure Secrets (.gitignored)
Create a file `iac/kubernetes/app/values-override.yaml` to override secrets without committing them:

```yaml
mongodb:
  password: "SuperSecretPassword123!" # Must match Ansible vault.yml
secrets:
  secretKey: "your-app-secret-key"
```

### 3. Build & Deploy
First retrieve necessary information from Terraform, then use the simplified Makefile.

```bash
# 1. Retrieve Terraform Outputs
cd iac/envs/dev/ec2
export ECR_URL=$(terraform output -raw ecr_repository_url)
export MONGO_IP=$(terraform output -raw mongo_private_ip)
cd ../../../..

# 2. Build & Push (Pass ECR URL)
make build
make push ECR_URL=$ECR_URL

# 3. Deploy (Pass necessary info)
make deploy ECR_URL=$ECR_URL MONGO_IP=$MONGO_IP
```

---

## CI/CD Deployment (Automated)

The project uses GitHub Actions with a **DevSecOps** approach.

### GitHub Actions Configuration
Add the following secrets to your GitHub repo:

| Secret | Description |
| :--- | :--- |
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | IAM Role ARN for OIDC |
| `MONGO_SSH_PRIVATE_KEY` | SSH Private Key to configure Mongo (Ansible) |
| `MONGO_SSH_PUBLIC_KEY` | SSH Public Key |
| `ANSIBLE_VAULT_PASSWORD` | Password to decrypt Ansible secrets |
| `MONGO_PASSWORD` | MongoDB Password (App) |
| `APP_SECRET_KEY` | Application Secret Key |

### Workflows

#### 1. Pull Request (`ci-pr.yml`)
*   **Trigger**: Push to `dev` or PR to `main`.
*   **Actions**: Security Scans (Trivy Filesystem, IaC, Secrets) + Terraform Validation.
*   **Goal**: Verify quality and security before merge.

#### 2. Release (`cd-release.yml`)
*   **Trigger**: Push of a Git tag (e.g., `v1.0.0`).
*   **Actions**:
    1.  **Infra**: Terraform Apply (EKS, EC2, Security).
    2.  **Config**: Ansible Playbook (on EC2 Mongo).
    3.  **Build**: Docker Build & Push (Image Tag = Git Tag or Commit SHA).
    4.  **Deploy**: Helm Upgrade on EKS.
*   **How to run**:
    ```bash
    git checkout dev
    git tag v1.0.0
    git push origin v1.0.0
    ```

---

## Security & Vulnerabilities (Milestones 2 & 4)

The exercise includes specific security configurations and intentional vulnerabilities for demonstration purposes.

*   **Cloud Native Security**: CloudTrail, AWS Config, GuardDuty are managed in `iac/envs/dev/security`.
*   **Admin Vulnerability**: The pod runs with `cluster-admin` (Proof: `kubectl auth can-i '*' '*'`).
*   **Network Vulnerability**: Port 22 open on Mongo (Detected by AWS Config).

*Refer to `RECAP_AND_TESTING.md` for detailed testing procedures.*
