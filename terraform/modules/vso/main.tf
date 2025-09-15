resource "null_resource" "vso_operator" {
  provisioner "local-exec" {
    command = <<EOT
helm upgrade --install vso hashicorp/vault-secrets-operator \
  --namespace ${var.namespace} \
  --create-namespace \
  --set vault.address=${var.vault_addr} \
  --set vault.token=${var.vault_admin_token}
EOT
  }
}

# Apply VaultAuth resource
resource "null_resource" "vault_auth" {
  provisioner "local-exec" {
    command = "oc apply -f ${path.module}/vault_auth.yaml -n ${var.namespace}"
  }

  depends_on = [null_resource.vso_operator]
}

# Apply VaultSecret resource (for chatbot secrets)
resource "null_resource" "vault_secret" {
  provisioner "local-exec" {
    command = "oc apply -f ${path.module}/vault_secret.yaml -n ${var.namespace}"
  }

  depends_on = [null_resource.vault_auth]
}