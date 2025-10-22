# terraform-vault-openshift-prisma-airs
Secure, Terraform-deployed AI workloads on Openshift, with secrets managed via HCP Vault Dedicated and delivered using Vault Secrets Operator. Security guardrails provided by Prisma AIRS.

## Why This Matters

In today’s fast-paced AI landscape, securely deploying and managing AI workloads is a critical challenge. Organizations need a solution that not only scales effortlessly but also ensures that sensitive data - like API keys and model secrets - is protected at every layer. This repository addresses that challenge by combining best-in-class tools for infrastructure automation, secrets management, and runtime security.

By leveraging **Terraform**, this solution automates the provisioning of the **HashiCorp Vault Dedicated** cluster, drastically reducing the time and complexity of setup. The **Vault Secrets Operator (VSO)** ensures that secrets are dynamically injected into the AI workload, eliminating manual handling of sensitive information and reducing operational risk.

**Prisma AIRS AI Runtime Security** - API Intercept by **Palo Alto Networks** provides proactive AI guardrails, monitoring the behavior of the FastAPI chatbot in real-time. This means your AI workloads are not only secure from a secrets perspective but also protected from unintended or unsafe outputs, helping organizations meet compliance requirements and maintain trust with end users.

With this deployment pattern, teams gain a fully automated, secure, and scalable AI environment that can be easily replicated across projects or accounts, allowing developers to focus on building the internal logic of AI applications rather than managing infrastructure or worrying about security gaps. It’s the intersection of speed, safety, and operational efficiency - exactly what modern AI teams need to accelerate innovation responsibly.

## What is deployed in this repo

| Component                        | Purpose                            |
| -------------------------------- | ---------------------------------- |
| **Use case #1: AI Chatbot (FastAPI)**         | Gemini-based chatbot with built-in guardrails by Palo Alto Networks Prisma AIRS|
| **Use case #2: AI Agent (FastAPI) on LangGraph, LangChain** | Gemini-based agent (helpful infrastructure assistant) leveraging Terraform MCP with built-in guardrails Prisma AIRS|
| **Openshift**                    | Runs your apps as a pods             |
| **HCP Vault Dedicated**          | Stores secrets in `kv-v2`, generates **dynamic** database credentials          |
| **Vault Secrets Operator (VSO)** | Pulls static and dynamic secrets into Openshift|
| **Terraform**                    | Automates HCP Vault setup |

## Prerequisites

- HCP account and Vault CLI access
- Openshift cluster and CLI access (`oc` command line tool)
- Docker
- Terraform v1.13.3 or later
- Helm
- Prisma AIRS API access + key (from Palo Alto Networks)
- Gemini API key
- psql (terminal-based front-end to PostgreSQL)

## Local Setup

## Provision HCP Vault infrastructure

To stand up the basic infrastructure, a few credentials must be configured:  

1. Copy `secrets.auto.tfvars.sample` and rename it to `secrets.auto.tfvars`.
 ```bash
    cd terraform
    cp secrets.auto.tfvars.sample secrets.auto.tfvars
   ```

1. Create an HCP account and follow the [authentication guide](https://registry.terraform.io/providers/hashicorp/hcp/latest/docs/guides/auth) to set up and retrieve your project ID and client secret.  

13. Fill in all required credentials. Prisma AIRS requires API access; make sure you have a valid key. Refer to the [official Prisma AIRS documentation](https://docs.paloaltonetworks.com/ai-runtime-security/activation-and-onboarding/activate-your-ai-runtime-security-license/create-an-ai-instance-deployment-profile-in-csp) for setup details.  
 
1. Deploy with Terraform:  
   ```bash
   terraform init
   terraform plan
   ```
1. Review the plan, then apply:
    ```bash
   terraform apply --auto-approve
   ```
At the end of this setup, Terraform provisions the core infrastructure:
- HCP Vault Dedicated cluster, roles, mounts, and secrets;
- AWS RDS database storing fake Terraform backend data (state files).

## Openshift setup

Cluster requirements:

- At least 3 worker nodes, each with 2 vCPUs and 8 GB RAM.
- Outbound connectivity enabled, since the apps running on OpenShift will need to send requests to Palo Prisma AIRS.
- Cluster admin permissions to install CRDs.
- The cluster must be running on Linux nodes (RHCOS or RHEL) since VSO images are published for Linux (amd64/arm64) only.
- The environment cannot run in nested virtualization, as that causes compatibility issues.

**Note:** Provision your cluster before continuing.

Log into the cluster via CLI using the `oc` tool.

Create a new project for our app:

```sh
oc new-project ai-chatbot
```

## Dockerize the app

Build a Docker image and push it to the OpenShift Integrated Image Registry:

```sh
# Navigate to the app directory
cd ../apps/ai-chatbot

# Check if the registry route exists
oc get route -n openshift-image-registry

# If empty, create the route (requires cluster-admin)
oc create route reencrypt default-route --service=image-registry -n openshift-image-registry

# Get the route hostname
oc get route default-route -n openshift-image-registry -o jsonpath='{.spec.host}'

# Login from Docker
docker login -u $(oc whoami) -p $(oc whoami -t) <route-hostname>

# Build the Docker image for amd64 architecture
docker buildx build --platform linux/amd64 -t ai-chatbot-openshift:latest .

# Tag & push your image
docker tag ai-chatbot-openshift:latest <route-hostname>/ai-chatbot/ai-chatbot-openshift:latest
docker push <route-hostname>/ai-chatbot/ai-chatbot-openshift:latest
```

For the second agent app,

```sh
# Navigate to the app directory
cd ../ai-agent

# Build the Docker image for amd64 architecture
docker buildx build --platform linux/amd64 -t ai-agent-openshift:latest .

# Tag & push your image
docker tag ai-agent-openshift:latest <route-hostname>/ai-chatbot/ai-agent-openshift:latest
docker push <route-hostname>/ai-chatbot/ai-agent-openshift:latest
```

Note: The Docker build uses buildx only for Apple Silicon (M1/M2) Macs to enable multi-platform builds. On other architectures, buildx is not required.

## Install Vault Secrets Operator (VSO)

You can install VSO on OpenShift using either the Red Hat OperatorHub or a helm chart. The [official installation guide](https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso/openshift) supports and documents both options. 

Below is the Helm chart installation example.

```sh
cd ../../k8s-manifests

oc create namespace vault-secrets-operator-system
```

Create a Vault CA certificate secret:

```sh
openssl s_client -showcerts -connect vault.example.com:8200 </dev/null 2>/dev/null | openssl x509 -outform PEM > vault-ca.pem

oc create secret generic vault-cacert \
  --namespace=vault-secrets-operator-system \
  --from-file=ca.crt=vault-ca.pem
```
Verify the secret:

```sh
oc get secret vault-cacert -n vault-secrets-operator-system
oc get secret vault-cacert -n vault-secrets-operator-system -o yaml
```

Copy `vault-operator-values-sample.yaml` and rename it to `vault-operator-values.yaml`.
 ```sh
cp secrets.auto.tfvars.sample secrets.auto.tfvars

```
Fill out the Vault url and domain in `vault-operator-values.yaml` and install VSO:

```sh
helm template vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator-system \
  --create-namespace \
  --values vault-operator-values.yaml | oc apply -f -
```

Check installation:

```sh
oc get crds | grep vault
oc get pods -n vault-secrets-operator-system
oc describe vaultconnection default -n vault-secrets-operator-system
```

## Apply Kubernetes Manifests

This manifest configures Kubernetes resources that allow the AI Chatbot to securely authenticate with HashiCorp Vault and retrieve secrets. It creates service accounts, RBAC permissions, and Vault custom resources to sync secrets from Vault into Kubernetes, with automatic updates and deployment restarts when secrets change.

```sh
oc apply -f vault_auth.yaml
```

## Configure Vault Openshift Auth

Export required values as environment variables:

```sh
export SA_TOKEN=$(oc get secret vault-auth-secret -n ai-chatbot \
  -o jsonpath="{.data.token}" | base64 --decode)

export KUBERNETES_CA=$(oc get secret vault-auth-secret -n ai-chatbot \
  -o jsonpath="{.data['ca\.crt']}" | base64 --decode)

export KUBERNETES_URL=$(oc config view --minify \
  -o jsonpath='{.clusters[0].cluster.server}')
```

## Authenticate with Vault and configure Kubernetes Auth Method

- Go to the [HCP Console](https://portal.cloud.hashicorp.com).
- Navigate to **Vault Dedicated** > your cluster.
- Click **Generate Token** and copy it.

```sh
export VAULT_ADDR="<vault cluster url>"
vault login
```
Paste your token when prompted.

```sh
vault write -namespace="admin" auth/kubernetes/config \
  use_annotations_as_alias_metadata=true \
  token_reviewer_jwt="${SA_TOKEN}" \
  kubernetes_host="${KUBERNETES_URL}" \
  kubernetes_ca_cert="${KUBERNETES_CA}"
```

By authenticating Kubernetes Service Accounts to Vault, we establish a trusted identity that Vault can use to map to specific roles and policies. Once this setup is done, applications in Kubernetes will be able to authenticate to Vault transparently, without needing admin privileges themselves.

---

## RBAC for Vault Service Account

This manifest grants the `vault-sa` service account in the `ai-chatbot` namespace read-only permissions on Kubernetes ServiceAccounts. It defines a `ClusterRole` with `get` and `list` verbs for ServiceAccounts and binds it to `vault-sa` through a `ClusterRoleBinding`.

```sh
oc apply -f vault-sa-rbac.yaml
```

---

## Test Vault Access

```sh
export APP_TOKEN=$(vault write -namespace="admin" -field="token" \
  auth/kubernetes/login \
  role=ai-chatbot-role \
  jwt=$(oc create token -n ai-chatbot chatbot))

VAULT_TOKEN=$APP_TOKEN vault kv get \
  -namespace="admin" \
  -mount=kv chatbot
```

You should see the secrets stored in Vault for the chatbot app.

Now test if the role also correctly generates dynamic database credentials:

```sh

VAULT_TOKEN=$APP_TOKEN vault read \
  -namespace="admin" \
  postgres/creds/ai-agent-app
```


## Deploy the Apps

```sh
oc apply -f deployment.yaml
```

This deployment should deploy use case #1 (chatbot), use case #2 (agent - helpful infrastructure assistant), and the Terraform MCP server used by app #2.

Check if pods are running:

```sh
oc get pods -n ai-chatbot
```

## Access the App

Use case #1 (chatbot)
Check the route hostname for ai-chatbot :

```sh
oc get route ai-chatbot -n ai-chatbot
```

Open the `HOST/PORT` in your browser. Use case #1 Chatbot runs on /ai-chatbot.

Use case #2 

```sh
oc get route ai-agent -n ai-chatbot
```

The second app runs on /ai-agent.

## Troubleshooting

### Verifying VSO

Check if secret was synced:

```sh
oc get secret chatbotkv -n ai-chatbot
```

```sh
oc get secret agentkv -n ai-chatbot
```

Check deployment logs for VSO:

```sh
oc logs deployment/vault-secrets-operator-controller-manager -n vault-secrets-operator-system
```
### Verifying the Database

If you encounter any database-related issues, you can check whether the fake data was successfully loaded into PostgreSQL.

Connect to your RDS PostgreSQL instance using `psql`:

```bash
psql "host=your_rds_hostname port=5432 dbname=aiagentdb user=aiagent password=your_password sslmode=require"
```
Once connected, run 
```bash
 SELECT * FROM terraform_remote_state.states;
 ```
This will display all rows and help confirm that the fake data has been properly populated.

## Cleanup

Destroy all infra by running:

```sh
oc delete namespace ai-chatbot
```

```sh
terraform destroy
```