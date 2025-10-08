# Run Locally

Easily test the AI Agent app and its integration with Terraform MCP using Docker.

---

## 1. Clone and Build Terraform MCP Server

```sh
git clone https://github.com/hashicorp/terraform-mcp-server.git
cd terraform-mcp-server
make docker-build
```

---

## 2. Create a Docker Network

```sh
docker network create infra-agent-net
```

---

## 3. Start Terraform MCP Server

```sh
docker run --name terraform-mcp \
  --network infra-agent-net \
  -p 8080:8080 \
  -e TRANSPORT_MODE=streamable-http \
  -e TRANSPORT_HOST=0.0.0.0 \
  -e TRANSPORT_PORT=8080 \
  -e MCP_SESSION_MODE=stateless \
  terraform-mcp-server:dev
```

---

## 4. Build and Run the AI Agent App

Open a **separate terminal** and navigate to the app directory:

```sh
cd app/ai-agent
```

Set your environment variables:

```sh
export GEMINI_API_KEY="your_gemini_api_key"
export PRISMA_AIRS_API_KEY="your_prisma_airs_api_key"
export PRISMA_AIRS_PROFILE="your_prisma_airs_profile"
```

Build the Docker image:

```sh
docker build -t ai-agent .
```

Run the container:

```sh
docker run --network infra-agent-net \
  -p 5001:5001 \
  -e GEMINI_API_KEY=$GEMINI_API_KEY \
  -e PRISMA_AIRS_API_KEY=$PRISMA_AIRS_API_KEY \
  -e PRISMA_AIRS_PROFILE=$PRISMA_AIRS_PROFILE \
  ai-agent
```

---

## 5. Access the App

Once the container is running, open your browser and go to:

```
http://localhost:5001
```

---

**Tip:**  
Make sure both containers are running and connected to the `infra-agent-net` Docker network for proper communication.