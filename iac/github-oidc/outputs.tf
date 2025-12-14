output "github_actions_role_arn" {
  description = "ARN of the IAM role for GitHub Actions"
  value       = aws_iam_role.github_actions.arn
}

output "ssh_private_key_secret_arn" {
  description = "ARN of the SSH private key secret"
  value       = aws_secretsmanager_secret.ssh_private_key.arn
}

output "ssh_public_key_secret_arn" {
  description = "ARN of the SSH public key secret"
  value       = aws_secretsmanager_secret.ssh_public_key.arn
}

output "ssh_public_key" {
  description = "SSH public key to use in Terraform EC2 module"
  value       = tls_private_key.ssh.public_key_openssh
  sensitive   = true
}

output "ansible_vault_password_secret_arn" {
  description = "ARN of the Ansible Vault password secret"
  value       = aws_secretsmanager_secret.ansible_vault_password.arn
}

output "ansible_vault_password" {
  description = "Generated Ansible Vault password (use to re-encrypt vault.yml)"
  value       = random_password.ansible_vault.result
  sensitive   = true
}

