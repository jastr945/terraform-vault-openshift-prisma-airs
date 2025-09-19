# Expect the root module to configure provider credentials/kubeconfig, but allow override
provider "kubernetes" {
  host                   = var.openshift_host
  token                  = var.openshift_token
  cluster_ca_certificate = file("${path.module}/ca.crt")
}

provider "helm" {
  kubernetes = {
    host                   = var.openshift_host
    token                  = var.openshift_token
  }
}
