# resource "null_resource" "vso_operator" {
#   provisioner "local-exec" {
#     command = <<EOT
# helm upgrade --install vso hashicorp/vault-secrets-operator \
#   --namespace ${var.namespace} \
#   --set vault.address=${var.vault_addr} \
#   --set vault.token=${var.vault_admin_token}
#   --timeout 10m30s
# EOT
#   }
# }

resource "kubernetes_manifest" "vault_secrets_operator_subscription" {
  manifest = {
    apiVersion = "operators.coreos.com/v1alpha1"
    kind       = "Subscription"
    metadata = {
      name      = "vault-secrets-operator"
      namespace = "${var.openshift_namespace}"
    }
    spec = {
      channel             = "stable"
      name                = "vault-secrets-operator"
      source              = "certified-operators"
      sourceNamespace     = "openshift-marketplace"
      installPlanApproval = "Automatic"
    }
  }
}

resource "kubernetes_manifest" "static_vault_connection" {
  manifest = yamldecode(<<-EOF
    kind: VaultConnection
    apiVersion: secrets.hashicorp.com/v1beta1
    metadata:
      name: vault-connection
      namespace: "${var.openshift_namespace}"
    spec:
      address: "${var.vault_addr}"
    EOF
  )
}

resource "kubernetes_manifest" "vault_auth" {
  
  manifest = yamldecode(<<-EOF
    apiVersion: secrets.hashicorp.com/v1beta1
    kind: VaultAuth
    metadata:
      name: chatbot-auth
      namespace: default
    spec:
      vaultConnectionRef: "${kubernetes_manifest.static_vault_connection.object.metadata.name}"
      method: jwt
      mount: "${vault_jwt_auth_backend.demo_jwt_auth.path}"
      namespace: "${var.vault_namespace}"
      allowedNamespaces: ["${var.openshift_namespace}"]
      storageEncryption:
        keyName: "${var.vault_transit_key_name}"
        mount: "${var.vault_transit_mount_path}"
      jwt:
        audiences:
          - "${var.openshift_namespace}"
        role: "${vault_jwt_auth_backend_role.static_app_role.role_name}"
        serviceAccount: chatbot-sa
        tokenExpirationSeconds: 600
    EOF
  )

  depends_on = [kubernetes_manifest.vault_secrets_operator_subscription]
}

resource "kubernetes_manifest" "vault_secret_gemini" {
  
  manifest = yamldecode(<<-EOF
    apiVersion: secrets.hashicorp.com/v1beta1
    kind: VaultStaticSecret
    metadata:
      name: chatbot-secret-gemini
      namespace: "${var.openshift_namespace}"
    spec:
      path: /v1/admin/kv/data/chatbot
      mount: kv
      type: kv-v2
      destination:
        name: GEMINI_API_KEY
        create: false
        overwrite: true
      refreshAfter: 2s
      syncConfig:
        instantUpdates: true
      vaultAuthRef: chatbot-auth
  EOF
  )

  depends_on = [kubernetes_manifest.vault_auth]
}

resource "kubernetes_manifest" "vault_secret_airs_api_key" {
  
  manifest = yamldecode(<<-EOF
    apiVersion: secrets.hashicorp.com/v1beta1
    kind: VaultStaticSecret
    metadata:
      name: chatbot-secret-airs-api-key
      namespace: "${var.openshift_namespace}"
    spec:
      path: /v1/admin/kv/data/chatbot
      mount: kv
      type: kv-v2
      destination:
        name: PRISMA_AIRS_API_KEY
        create: false
        overwrite: true
      refreshAfter: 2s
      syncConfig:
        instantUpdates: true
      vaultAuthRef: chatbot-auth

  EOF
  )

  depends_on = [kubernetes_manifest.vault_auth]
}

resource "kubernetes_manifest" "vault_secret_airs_profile" {
  
  manifest = yamldecode(<<-EOF
    apiVersion: secrets.hashicorp.com/v1beta1
    kind: VaultStaticSecret
    metadata:
      name: chatbot-secret-airs-profile
      namespace: "${var.openshift_namespace}"
    spec:
      path: /v1/admin/kv/data/chatbot
      mount: kv
      type: kv-v2
      destination:
        name: PRISMA_AIRS_PROFILE
        create: false
        overwrite: true
      refreshAfter: 2s
      syncConfig:
        instantUpdates: true
      vaultAuthRef: chatbot-auth
  EOF
  )

  depends_on = [kubernetes_manifest.vault_auth]
}

resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = var.openshift_namespace
    labels = {
      app = var.app_name
    }
  }
  spec {
    replicas = var.replicas
    selector {
      match_labels = {
        app = var.app_name
      }
    }
    template {
      metadata {
        labels = {
          app = var.app_name
        }
      }
      spec {
        container {
          name  = var.app_name
          image = var.image
          port {
            container_port = 5000
          }
          env {
            # env vars come from the Kubernetes secret created by VSO
            name = "GEMINI_API_KEY"
            value_from {
              secret_key_ref {
                name = "chatbot-secrets"
                key  = "GEMINI_API_KEY"
              }
            }
          }
          env {
            name = "PRISMA_AIRS_API_KEY"
            value_from {
              secret_key_ref {
                name = "chatbot-secrets"
                key  = "PRISMA_AIRS_API_KEY"
              }
            }
          }
          env {
            name = "PRISMA_AIRS_PROFILE"
            value_from {
              secret_key_ref {
                name = "chatbot-secrets"
                key  = "PRISMA_AIRS_PROFILE"
              }
            }
          }
          readiness_probe {
            http_get {
              path = "/token-suffix"
              port = 5000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = var.openshift_namespace
    labels = {
      app = var.app_name
    }
  }
  spec {
    selector = {
      app = var.app_name
    }
    port {
      port        = 80
      target_port = 5000
      protocol    = "TCP"
    }
  }
  depends_on = [kubernetes_deployment.app, kubernetes_manifest.vault_secret_gemini, kubernetes_manifest.vault_secret_airs_api_key, kubernetes_manifest.vault_secret_airs_profile]
}

resource "kubernetes_manifest" "route" {
  manifest = {
    apiVersion = "route.openshift.io/v1"
    kind       = "Route"
    metadata = {
      name      = "${var.app_name}-route"
      namespace = var.openshift_namespace
    }
    spec = {
      to = {
        kind = "Service"
        name = kubernetes_service.app_svc.metadata[0].name
      }
      port = {
        targetPort = 80
      }
      tls = {
        termination                   = "edge"
        insecureEdgeTerminationPolicy = "Allow"
      }
    }
  }
  depends_on = [kubernetes_service.app_svc]
}