# Terraform Backend (S3 + DynamoDB)

This directory creates the S3 bucket and DynamoDB table required for remote Terraform state storage.

## Why This is Needed

Without a remote backend:
- Each CI/CD run starts with an empty state
- Cannot track existing infrastructure
- Cannot destroy or update resources
- State conflicts between team members

With S3 backend:
- ✅ State persisted across CI/CD runs
- ✅ State locking prevents concurrent modifications
- ✅ State versioning for rollback
- ✅ Encrypted at rest

## Bootstrap Process (One-Time Setup)

### 1. Deploy Backend Infrastructure

```bash
cd iac/terraform-backend
AWS_PROFILE=wiz terraform init
AWS_PROFILE=wiz terraform apply
```

**Outputs**:
- `s3_bucket_name`: Bucket for state storage
- `dynamodb_table_name`: Table for state locking

### 2. Get Backend Configuration

```bash
AWS_PROFILE=wiz terraform output
```

Example output:
```
s3_bucket_name = "wiz-tech-exercise-terraform-state-324037288864"
dynamodb_table_name = "wiz-tech-exercise-terraform-locks"
```

### 3. Migrate Existing State to S3

For each module (EKS, EC2, GitHub OIDC), create a `backend.tf` file.

#### Example: EKS Module

Create `iac/envs/dev/eks/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "wiz-tech-exercise-terraform-state-324037288864"
    key            = "dev/eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "wiz-tech-exercise-terraform-locks"
    encrypt        = true
  }
}
```

Then migrate:

```bash
cd iac/envs/dev/eks
AWS_PROFILE=wiz terraform init -migrate-state
```

Terraform will ask: **"Do you want to copy existing state to the new backend?"** → Answer **yes**

Repeat for:
- `iac/envs/dev/ec2/backend.tf`
- `iac/github-oidc/backend.tf`

## Backend Configuration Files

### EKS (`iac/envs/dev/eks/backend.tf`)

```hcl
terraform {
  backend "s3" {
    bucket         = "wiz-tech-exercise-terraform-state-324037288864"
    key            = "dev/eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "wiz-tech-exercise-terraform-locks"
    encrypt        = true
  }
}
```

### EC2 (`iac/envs/dev/ec2/backend.tf`)

```hcl
terraform {
  backend "s3" {
    bucket         = "wiz-tech-exercise-terraform-state-324037288864"
    key            = "dev/ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "wiz-tech-exercise-terraform-locks"
    encrypt        = true
  }
}
```

### GitHub OIDC (`iac/github-oidc/backend.tf`)

```hcl
terraform {
  backend "s3" {
    bucket         = "wiz-tech-exercise-terraform-state-324037288864"
    key            = "cicd/github-oidc/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "wiz-tech-exercise-terraform-locks"
    encrypt        = true
  }
}
```

## Security Features

- **Versioning**: Enabled on S3 bucket (rollback capability)
- **Encryption**: AES256 encryption at rest
- **Public Access**: Blocked at bucket level
- **State Locking**: DynamoDB prevents concurrent modifications
- **IAM Permissions**: GitHub Actions role has access to bucket

## CI/CD Integration

GitHub Actions workflows automatically use the S3 backend:

```yaml
- name: Terraform Init
  working-directory: iac/envs/dev/eks
  run: terraform init  # Automatically uses S3 backend
```

No additional configuration needed in workflows!

## Troubleshooting

### State Lock Stuck

If a CI/CD run is canceled mid-apply, the state may remain locked.

```bash
# List locks
AWS_PROFILE=wiz aws dynamodb scan --table-name wiz-tech-exercise-terraform-locks

# Force unlock (use LockID from above)
cd iac/envs/dev/eks
AWS_PROFILE=wiz terraform force-unlock <LOCK_ID>
```

### Migrate Existing Local State

If you already deployed infrastructure locally:

1. Create `backend.tf` in the module directory
2. Run `terraform init -migrate-state`
3. Confirm "yes" to copy state to S3
4. Delete local `terraform.tfstate` files (now in S3)

### View State in S3

```bash
AWS_PROFILE=wiz aws s3 ls s3://wiz-tech-exercise-terraform-state-324037288864/
```

## Cost

- **S3**: ~$0.023/GB/month (negligible for state files)
- **DynamoDB**: Pay-per-request (very low cost for locking)
- **Estimated**: <$1/month

## Cleanup

⚠️ **DO NOT** delete the backend bucket/table while infrastructure exists!

To destroy everything (including backend):

1. Destroy all infrastructure first:
   ```bash
   make clean-all
   ```

2. Then destroy backend:
   ```bash
   cd iac/terraform-backend
   terraform destroy
   ```


