resource "kubernetes_deployment" "app" {
  metadata {
    name      = var.app_name
    namespace = "pjastr-dev"
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

# Service
resource "kubernetes_service" "app_svc" {
  metadata {
    name      = "${var.app_name}-svc"
    namespace = "pjastr-dev"
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
  depends_on = [kubernetes_deployment.app]
}

# Apply OpenShift Route via oc CLI to avoid CRD permission issues
resource "null_resource" "route" {
  provisioner "local-exec" {
    command = <<EOT
oc apply -f ${path.root}/k8s/route.yaml -n pjastr-dev
EOT
  }

  depends_on = [kubernetes_service.app_svc]
}