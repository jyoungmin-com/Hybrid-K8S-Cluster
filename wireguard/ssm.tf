# Store WireGuard hub keys in AWS SSM Parameter Store
resource "aws_ssm_parameter" "wireguard_hub_private_key" {
  name  = "/${var.project_name}/wireguard/hub-private-key"
  type  = "SecureString"
  value = "PLACEHOLDER_WILL_BE_UPDATED_BY_INSTANCE"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name    = "${var.project_name}-wireguard-hub-private-key"
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "wireguard_hub_public_key" {
  name  = "/${var.project_name}/wireguard/hub-public-key"
  type  = "String"
  value = "PLACEHOLDER_WILL_BE_UPDATED_BY_INSTANCE"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name    = "${var.project_name}-wireguard-hub-public-key"
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "kubernetes_bootstrap_token" {
  name  = "/${var.project_name}/kubernetes/bootstrap-token"
  type  = "String"
  value = "PLACEHOLDER_WILL_BE_UPDATED_BY_INSTANCE"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name    = "${var.project_name}-kubernetes-bootstrap-token"
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "kubernetes_ca_cert_hash" {
  name  = "/${var.project_name}/kubernetes/ca-cert-hash"
  type  = "String"
  value = "PLACEHOLDER_WILL_BE_UPDATED_BY_INSTANCE"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name    = "${var.project_name}-kubernetes-ca-cert-hash"
    Project = var.project_name
  }
}

resource "aws_ssm_parameter" "kubernetes_join_command" {
  name  = "/${var.project_name}/kubernetes/join-command"
  type  = "String"
  value = "PLACEHOLDER_WILL_BE_UPDATED_BY_INSTANCE"

  lifecycle {
    ignore_changes = [value]
  }

  tags = {
    Name    = "${var.project_name}-kubernetes-join-command"
    Project = var.project_name
  }
}