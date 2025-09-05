# terraform-vault-openshift-prisma-airs
A secure, Terraform-deployed chatbot on OpenShift, with secrets managed via HCP Vault Dedicated and delivered using Vault Secrets Operator. Security guardrails provided by Prisma AIRS. 

## What is deployed in this repo

| Component                        | Purpose                            |
| -------------------------------- | ---------------------------------- |
| **Python app (Flask)**           | Gemini-based chatbot               |
| **OpenShift Deployment**         | Runs your app as a pod             |
| **HCP Vault Dedicated**          | Stores secrets in `kv-v2`          |
| **Vault Secrets Operator (VSO)** | Pulls secrets into OpenShift       |
| **Terraform**                    | Automates Vault + Kubernetes setup |
