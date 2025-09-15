provider "kubernetes" {
  host                   = var.openshift_host
  token                  = var.openshift_token
}
