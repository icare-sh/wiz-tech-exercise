# CI/CD Setup Guide - Quick Reference

## Prerequisites

- ✅ AWS CLI configured (`AWS_PROFILE=wiz`)
- ✅ Terraform >= 1.5
- ✅ GitHub repository created
- ✅ GitHub Actions enabled

## Setup Steps (Execute in Order)

### 1. Setup Remote Backend (S3 + DynamoDB)

**Why**: Without remote state, each CI/CD run starts fresh and cannot track existing infrastructure.

```bash
cd /home/sabir/dev/wiz-tech-exercise
AWS_PROFILE=wiz ./scripts/setup-backend.sh
```

**What this does**:
- Creates S3 bucket for Terraform state
- Creates DynamoDB table for state locking
- Generates `backend.tf` for each module
- Migrates existing local state to S3

**Verify**:
```bash
AWS_PROFILE=wiz aws s3 ls | grep terraform-state
```

---

### 2. Update GitHub Configuration

Edit `iac/github-oidc/main.tf`:

```hcl
locals {
  github_org  = "your-github-username"
  github_repo = "wiz-tech-exercise"
}
```

---

### 3. Deploy CI/CD Infrastructure

```bash
cd iac/github-oidc
AWS_PROFILE=wiz terraform init
AWS_PROFILE=wiz terraform apply
```

**What this creates**:
- GitHub OIDC Provider (AWS ←→ GitHub authentication)
- IAM Role for GitHub Actions
- SSH Key Pair (auto-generated, stored in Secrets Manager)
- Ansible Vault Password (auto-generated, stored in Secrets Manager)

---

### 4. Retrieve Generated Secrets

#### Get Ansible Vault Password

```bash
cd iac/github-oidc

# Save to local file
AWS_PROFILE=wiz terraform output -raw ansible_vault_password > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Re-encrypt vault.yml with this password
cd ../envs/dev/ansible
ansible-vault rekey group_vars/mongo/vault.yml --vault-password-file ~/.ansible_vault_pass
```

#### Get SSH Public Key

```bash
cd ../../github-oidc
AWS_PROFILE=wiz terraform output -raw ssh_public_key
```

Copy to `iac/envs/dev/ec2/terraform.tfvars`:

```hcl
mongo_ssh_public_key = "ssh-ed25519 AAAA..."
```

#### Get IAM Role ARN

```bash
AWS_PROFILE=wiz terraform output github_actions_role_arn
```

Copy this ARN (you'll need it for GitHub).

---

### 5. Configure GitHub

#### Add Secret

1. Go to your GitHub repo
2. **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Add:
   - **Name**: `AWS_GITHUB_ACTIONS_ROLE_ARN`
   - **Value**: (ARN from step 4)

#### Create Environment

1. **Settings** → **Environments**
2. Click **New environment**
3. Name: `production`
4. (Optional) Add protection rules:
   - ✅ Required reviewers
   - ✅ Deployment branches: `main` only

---

### 6. Test CI/CD

#### Test IaC Pipeline (PR)

```bash
git checkout -b test-cicd
git add .
git commit -m "feat: CI/CD setup with remote state and OIDC"
git push origin test-cicd
```

Create PR on GitHub. The workflow will run Terraform plans.

#### Test Full Deployment (Main)

Merge the PR to `main`. The workflows will:
1. Apply EKS infrastructure
2. Apply EC2 infrastructure
3. Run Ansible configuration
4. (On app changes) Build, push, and deploy app

---

## Verification Commands

### Check Remote State

```bash
# List state files in S3
AWS_PROFILE=wiz aws s3 ls s3://wiz-tech-exercise-terraform-state-<account-id>/

# Check DynamoDB locks (should be empty if no runs active)
AWS_PROFILE=wiz aws dynamodb scan --table-name wiz-tech-exercise-terraform-locks
```

### Check Secrets Manager

```bash
# List secrets
AWS_PROFILE=wiz aws secretsmanager list-secrets | grep wiz-tech-exercise

# Test SSH key retrieval
AWS_PROFILE=wiz aws secretsmanager get-secret-value \
  --secret-id /wiz-tech-exercise/ssh-private-key \
  --query SecretString \
  --output text | head -1
```

### Check IAM OIDC Provider

```bash
AWS_PROFILE=wiz aws iam list-open-id-connect-providers
```

---

## Security Checklist

- [x] No AWS credentials in GitHub Secrets (OIDC only)
- [x] No SSH keys in repository
- [x] No Ansible Vault password in repository
- [x] Terraform state encrypted at rest (S3 AES256)
- [x] State locking enabled (DynamoDB)
- [x] Remote state backend configured for all modules
- [x] GitHub environment protection enabled
- [x] All secrets stored in AWS Secrets Manager

---

## Troubleshooting

### "Backend not initialized"

```bash
cd iac/envs/dev/eks  # or ec2, github-oidc
terraform init
```

### "State lock timeout"

A previous run was interrupted. Force unlock:

```bash
# Get lock ID
AWS_PROFILE=wiz aws dynamodb scan --table-name wiz-tech-exercise-terraform-locks

# Unlock
cd iac/envs/dev/eks
AWS_PROFILE=wiz terraform force-unlock <LOCK_ID>
```

### "Access denied to S3 bucket"

Check IAM role has correct permissions:

```bash
cd iac/github-oidc
AWS_PROFILE=wiz terraform output github_actions_role_arn

# Verify role policy includes S3/DynamoDB permissions
```

### GitHub Actions: "Unable to assume role"

1. Check secret `AWS_GITHUB_ACTIONS_ROLE_ARN` is correct
2. Verify OIDC provider exists in AWS
3. Check role trust policy includes your GitHub org/repo

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────┐
│  GitHub Actions (CI/CD Runner)                      │
│                                                     │
│  1. Authenticate via OIDC (no credentials!)        │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
         ┌─────────────────────┐
         │  AWS IAM Role       │
         │  (GitHub Actions)   │
         └──────────┬──────────┘
                    │
         ┏━━━━━━━━━━┻━━━━━━━━━━┓
         ▼                     ▼
┌─────────────────┐   ┌─────────────────┐
│  S3 Bucket      │   │ Secrets Manager │
│  (TF State)     │   │ - SSH Keys      │
│                 │   │ - Vault Pass    │
│ + DynamoDB      │   └─────────────────┘
│   (Locking)     │
└─────────────────┘
         │
         │ Terraform reads/writes state
         ▼
┌─────────────────────────────────────────┐
│  AWS Infrastructure                     │
│  - EKS Cluster                          │
│  - EC2 MongoDB VM                       │
│  - S3 Backups (public-read)             │
│  - ECR Registry                         │
│  - ALB Ingress                          │
└─────────────────────────────────────────┘
```

---

## Next Steps

After CI/CD is working:

1. **Monitor GitHub Actions**: Check workflow runs for any failures
2. **Set up Notifications**: Configure Slack/email for failed deployments
3. **Add Branch Protection**: Require PR reviews before merging to main
4. **Implement Drift Detection**: Schedule daily Terraform plan runs
5. **Add Cost Monitoring**: Set up AWS Budgets alerts

---

## Quick Commands Reference

| Task | Command |
|------|---------|
| Setup backend | `AWS_PROFILE=wiz ./scripts/setup-backend.sh` |
| Deploy OIDC + Secrets | `cd iac/github-oidc && terraform apply` |
| Get vault password | `terraform output -raw ansible_vault_password` |
| Get SSH public key | `terraform output -raw ssh_public_key` |
| Get IAM role ARN | `terraform output github_actions_role_arn` |
| Re-encrypt vault | `ansible-vault rekey group_vars/mongo/vault.yml` |
| Check S3 state | `aws s3 ls s3://wiz-tech-exercise-terraform-state-<id>/` |
| Check locks | `aws dynamodb scan --table-name wiz-tech-exercise-terraform-locks` |
| Force unlock | `terraform force-unlock <LOCK_ID>` |

---

## Support

If you encounter issues:

1. Check GitHub Actions logs
2. Verify AWS resources exist (S3 bucket, DynamoDB table, OIDC provider)
3. Confirm GitHub Secrets are set correctly
4. Review Terraform state in S3


