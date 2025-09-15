# Expect the root module to configure provider credentials/kubeconfig, but allow override
provider "kubernetes" {
  host                   = var.openshift_host
  token                  = var.openshift_token
}

provider "helm" {
  kubernetes = {
    host                   = var.openshift_host
    token                  = var.openshift_token
  }
}
