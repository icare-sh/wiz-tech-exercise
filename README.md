# 🚀 Wiz Tech Exercise - SecOps Deployment

Ce projet déploie une application Go ("Wiz Exercise App") connectée à MongoDB sur AWS EKS, avec une pipeline CI/CD DevSecOps complète.

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir installé :

*   **Infrastructure as Code** : Terraform (>= 1.5)
*   **Conteneurs & K8s** : Docker, Helm, kubectl
*   **Cloud** : AWS CLI (configuré avec vos credentials)
*   **Automation** : Make

---

## 💻 Déploiement Local (Développement)

Pour tester et développer en local sans passer par la CI.

### 1. Déployer l'Infrastructure
Déployez les ressources dans cet ordre (Network/EKS d'abord, puis EC2/Mongo + Security).

```bash
# 1. Sécurité (CloudTrail, Config, GuardDuty)
cd iac/envs/dev/security
terraform init && terraform apply -auto-approve

# 2. Cluster EKS
cd ../eks
terraform init && terraform apply -auto-approve

# 3. Base de données (EC2 Mongo + ECR)
cd ../ec2
terraform init && terraform apply -auto-approve
```

### 2. Configurer les Secrets (.gitignored)
Créez un fichier `iac/kubernetes/app/values-override.yaml` pour surcharger les secrets sans les commiter :

```yaml
mongodb:
  password: "SuperSecretPassword123!" # Doit matcher le vault.yml Ansible
secrets:
  secretKey: "votre-cle-secrete-app"
```

### 3. Build & Déploiement
Récupérez d'abord les informations nécessaires depuis Terraform, puis utilisez le Makefile simplifié.

```bash
# 1. Récupérer les Outputs Terraform
cd iac/envs/dev/ec2
export ECR_URL=$(terraform output -raw ecr_repository_url)
export MONGO_IP=$(terraform output -raw mongo_private_ip)
cd ../../../..

# 2. Build & Push (Passer l'URL ECR)
make build
make push ECR_URL=$ECR_URL

# 3. Déployer (Passer les infos nécessaires)
make deploy ECR_URL=$ECR_URL MONGO_IP=$MONGO_IP
```

---

## 🔄 Déploiement CI/CD (Automatisé)

Le projet utilise GitHub Actions avec une approche **DevSecOps**.

### ⚙️ Configuration GitHub Actions
Ajoutez les secrets suivants dans votre repo GitHub :

| Secret | Description |
| :--- | :--- |
| `AWS_GITHUB_ACTIONS_ROLE_ARN` | ARN du rôle IAM pour l'OIDC |
| `MONGO_SSH_PRIVATE_KEY` | Clé privée SSH pour configurer Mongo (Ansible) |
| `MONGO_SSH_PUBLIC_KEY` | Clé publique SSH |
| `ANSIBLE_VAULT_PASSWORD` | Mot de passe pour décrypter les secrets Ansible |
| `MONGO_PASSWORD` | Mot de passe MongoDB (App) |
| `APP_SECRET_KEY` | Clé secrète de l'application |

### 🚀 Workflows

#### 1. Pull Request (`ci-pr.yml`)
*   **Déclencheur** : Push sur `dev` ou PR vers `main`.
*   **Actions** : Scans de Sécurité (Trivy Filesystem, IaC, Secrets) + Validation Terraform.
*   **But** : Vérifier la qualité et la sécurité avant merge.

#### 2. Release (`cd-release.yml`)
*   **Déclencheur** : Push d'un tag Git (ex: `v1.0.0`).
*   **Actions** :
    1.  **Infra** : Terraform Apply (EKS, EC2, Security).
    2.  **Config** : Ansible Playbook (sur EC2 Mongo).
    3.  **Build** : Docker Build & Push (Tag image = Tag Git).
    4.  **Deploy** : Helm Upgrade sur EKS.
*   **Comment lancer** :
    ```bash
    git checkout dev
    git tag v1.0.0
    git push origin v1.0.0
    ```


