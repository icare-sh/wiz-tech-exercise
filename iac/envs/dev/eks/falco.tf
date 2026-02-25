# --- Falco: Kubernetes Runtime Security ---

resource "helm_release" "falco" {
  name             = "falco"
  repository       = "https://falcosecurity.github.io/charts"
  chart            = "falco"
  namespace        = "falco"
  create_namespace = true

  set {
    name  = "driver.kind"
    value = "modern_ebpf"
  }

  set {
    name  = "tty"
    value = "true"
  }

  set {
    name  = "falcosidekick.enabled"
    value = "true"
  }

  set {
    name  = "falcosidekick.config.smtp.hostport"
    value = "email-smtp.${local.region}.amazonaws.com:587"
  }

  set {
    name  = "falcosidekick.config.smtp.from"
    value = var.ses_sender_email
  }

  set {
    name  = "falcosidekick.config.smtp.to"
    value = var.falco_alert_email
  }

  set {
    name  = "falcosidekick.config.smtp.user"
    value = aws_iam_access_key.ses_smtp.id
  }

  set_sensitive {
    name  = "falcosidekick.config.smtp.password"
    value = aws_iam_access_key.ses_smtp.ses_smtp_password_v4
  }

  set {
    name  = "falcosidekick.config.smtp.minimumpriority"
    value = "warning"
  }

  depends_on = [
    module.eks,
    aws_ses_email_identity.alert_recipient,
  ]
}

# --- AWS SES for Falco email alerts ---

resource "aws_ses_email_identity" "alert_recipient" {
  email = var.falco_alert_email
}

resource "aws_ses_email_identity" "sender" {
  email = var.ses_sender_email
}

resource "aws_iam_user" "ses_smtp" {
  name = "${local.name}-ses-smtp"
  tags = local.tags
}

resource "aws_iam_user_policy" "ses_smtp" {
  name = "ses-send-email"
  user = aws_iam_user.ses_smtp.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ses:SendRawEmail"
      Resource = "*"
    }]
  })
}

resource "aws_iam_access_key" "ses_smtp" {
  user = aws_iam_user.ses_smtp.name
}
