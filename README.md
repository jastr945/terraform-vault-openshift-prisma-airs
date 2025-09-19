# terraform-vault-openshift-prisma-airs
A secure, Terraform-deployed chatbot on OpenShift, with secrets managed via HCP Vault Dedicated and delivered using Vault Secrets Operator. Security guardrails provided by Prisma AIRS. 

## What is deployed in this repo

| Component                        | Purpose                            |
| -------------------------------- | ---------------------------------- |
| **Python app (FastAPI)**           | Gemini-based chatbot             |
| **OpenShift Deployment**         | Runs your app as a pod             |
| **HCP Vault Dedicated**          | Stores secrets in `kv-v2`          |
| **Vault Secrets Operator (VSO)** | Pulls secrets into OpenShift       |
| **Terraform**                    | Automates Vault + Kubernetes setup |


Authenticate with HCP https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/guides/auth 

Try Red Hat OpenShift https://www.redhat.com/en/technologies/cloud-computing/openshift/try-it

You'll need cluster admin permissions, so you can use https://console.redhat.com/openshift/create/local to create an OpenShift sandbox cluster on your local machine. It's the easiest way to experience Openshift if you don't have a production environment and are working on a POC like the one provided in this repo.