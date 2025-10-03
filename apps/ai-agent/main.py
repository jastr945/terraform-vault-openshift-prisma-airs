import os
import uvicorn
import google.generativeai as genai
import requests
import subprocess
import uuid

from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel


GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PRISMA_AIRS_API_KEY = os.getenv("PRISMA_AIRS_API_KEY")
PRISMA_AIRS_PROFILE = os.getenv("PRISMA_AIRS_PROFILE")
MCP_HTTP_URL = os.getenv("MCP_HTTP_URL", "http://terraform-mcp:8080")

if not GEMINI_API_KEY or not PRISMA_AIRS_API_KEY or not PRISMA_AIRS_PROFILE:
    raise EnvironmentError("GEMINI_API_KEY and PRISMA_AIRS_API_KEY and PRISMA_AIRS_PROFILE must be set.")

genai.configure(api_key=GEMINI_API_KEY)

# Initialize Gemini
model = genai.GenerativeModel("gemini-2.0-flash-001")

# FastAPI setup
app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")

class Prompt(BaseModel):
    message: str


def scan_with_prisma_airs(prompt: str) -> dict:
    """Scan input/output via Prisma AIRS"""
    url = "https://service.api.aisecurity.paloaltonetworks.com/v1/scan/sync/request"
    headers = {
        "x-pan-token": PRISMA_AIRS_API_KEY,
        "Content-Type": "application/json"
    }
    payload = {
        "metadata": {
            "ai_model": "Gemini 2.0 Flash - Terraform Helpful Infra Agent",
            "app_name": "Terraform-AIRS-Agent",
            "app_user": "InfraAgent"
        },
        "contents": [
            {"prompt": prompt}
        ],
        "ai_profile": {
            "profile_name": PRISMA_AIRS_PROFILE
        }
    }
    try:
        response = requests.post(url, headers=headers, json=payload, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        return {"error": f"Prisma AIRS scan failed: {str(e)}"}

def is_safe(scan_result: dict) -> (bool, str):
    """Checks Prisma AIRS scan result for allow/block decision"""
    try:
        action = scan_result.get("action")
        category = scan_result.get("category")

        if action == "allow" and category == "benign":
            return True, "Allowed"
        elif action == "block" and category == "malicious":
            detected = scan_result.get("prompt_detected") or scan_result.get("response_detected") or {}
            reasons = [k.replace("_", " ").title() for k, v in detected.items() if v]
            reason_text = ", ".join(reasons) if reasons else "malicious content"
            return False, f"Blocked by Prisma AIRS guardrail: {reason_text}"
        else:
            return False, f"Blocked due to unknown decision: action={action}, category={category}"
    except Exception:
        return False, "Invalid Prisma AIRS response format."


def run_terraform_mcp(question: str) -> str:
    """
    Send Terraform question to Terraform MCP server via HTTP.
    Returns MCP output.
    """
    try:
        url = f"{MCP_HTTP_URL}/mcp"
        payload = {
            "session": str(uuid.uuid4()),
            "messages": [
                {"role": "user", "content": question}
            ]
        }
        response = requests.post(url, json=payload, timeout=15)
        response.raise_for_status()
        return response.text.strip()
    except requests.exceptions.RequestException as e:
        return f"[Terraform MCP HTTP Error] {str(e)}"


@app.post("/chat")
async def chat(prompt: Prompt):
    user_input = prompt.message

    # Scan input
    input_scan = scan_with_prisma_airs(user_input)
    if "error" in input_scan:
        return {"error": input_scan["error"]}
    input_safe, input_msg = is_safe(input_scan)
    if not input_safe:
        return {"error": input_msg, "verdict": input_scan}

    # If Terraform-related → send through MCP first
    terraform_context = None
    if "terraform" in user_input.lower() or "hcl" in user_input.lower():
        terraform_context = run_terraform_mcp(user_input)

    try:
        # Construct prompt for Gemini
        system_prompt = (
            "You are a Helpful Infrastructure Agent. "
            "Answer questions about Terraform best practices, writing HCL configs, "
            "and general infrastructure-as-code advice. "
            "Always be clear, concise, and provide code snippets where useful.\n\n"
        )
        if terraform_context:
            full_prompt = system_prompt + f"User Question:\n{user_input}\n\nTerraform MCP Context:\n{terraform_context}"
        else:
            full_prompt = system_prompt + f"User Question:\n{user_input}"

        gemini_response = model.generate_content(full_prompt)
        response_text = gemini_response.text
    except Exception as e:
        return {"error": f"Gemini error: {str(e)}"}

    # Scan output
    output_scan = scan_with_prisma_airs(response_text)
    if "error" in output_scan:
        return {"error": output_scan["error"]}
    output_safe, output_msg = is_safe(output_scan)
    if not output_safe:
        return {"error": output_msg, "verdict": output_scan}

    # Return safe output
    return {
        "response": response_text,
        "terraform_context": terraform_context,
        "input_verdict": input_scan,
        "output_verdict": output_scan
    }


@app.get("/token-suffix")
def token_suffix():
    return {"suffix": GEMINI_API_KEY[-3:]}


@app.get("/healthcheck")
def healthcheck():
    return {"status": "ok"}


@app.get("/")
def root():
    return FileResponse("static/index.html")


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5001)
