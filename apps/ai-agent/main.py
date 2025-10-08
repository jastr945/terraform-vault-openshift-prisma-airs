import os
import asyncio
import uvicorn
import requests
import subprocess
import uuid
import json

from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from langchain_mcp_adapters.client import MultiServerMCPClient
from langgraph.prebuilt import create_react_agent
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.callbacks.base import AsyncCallbackHandler
from langchain.callbacks.base import BaseCallbackHandler
from langchain.schema import LLMResult
from langchain.callbacks.manager import CallbackManager
from langchain.callbacks.streaming_stdout import StreamingStdOutCallbackHandler


GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
PRISMA_AIRS_API_KEY = os.getenv("PRISMA_AIRS_API_KEY")
PRISMA_AIRS_PROFILE = os.getenv("PRISMA_AIRS_PROFILE")
MCP_HTTP_URL = os.getenv("MCP_HTTP_URL", "http://terraform-mcp:8080/mcp")

if not GEMINI_API_KEY or not PRISMA_AIRS_API_KEY or not PRISMA_AIRS_PROFILE:
    raise EnvironmentError("GEMINI_API_KEY and PRISMA_AIRS_API_KEY and PRISMA_AIRS_PROFILE must be set.")

llm = ChatGoogleGenerativeAI(
    model="gemini-2.0-flash-001",
    temperature=0.2,
    max_output_tokens=8192,
    google_api_key=GEMINI_API_KEY,
)

client = MultiServerMCPClient(
    {
        "terraform": {
            "url": MCP_HTTP_URL,
            "transport": "streamable_http",
        }
    }
)

app = FastAPI()
app.mount("/static", StaticFiles(directory="static"), name="static")

class Prompt(BaseModel):
    message: str

agent = None

async def init_agent():
    global agent
    if agent is not None:
        return agent

    print("Connecting to Terraform MCP...")
    try:
        tools = await client.get_tools()
        print(f"Loaded {len(tools)} tool(s): {[t.name for t in tools]}")
        agent = create_react_agent(model=llm, tools=tools)
        return agent
    except Exception as e:
        print("Failed to initialize agent")
        import traceback; traceback.print_exc()
        raise e

@app.on_event("startup")
async def startup_event():
    await init_agent()

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
            "jsonrpc": "2.0",
            "id": str(uuid.uuid4()),
            "method": "terraform.run",  # replace with the correct MCP method
            "params": {
                "messages": [{"role": "user", "content": question}]
            }
        }
        response = requests.post(url, json=payload, timeout=15)
        response.raise_for_status()
        data = response.json()
        if "result" in data:
            return data["result"].get("output", "")
        elif "error" in data:
            return f"[MCP Error] {data['error']}"
        else:
            return "[MCP] Unexpected response format"
        return response.text.strip()
    except requests.exceptions.RequestException as e:
        return f"[Terraform MCP HTTP Error] {str(e)}"


class SSEStreamingHandler(BaseCallbackHandler):
    """Streams LLM tokens into an asyncio.Queue for SSE."""
    def __init__(self, queue: asyncio.Queue):
        self.queue = queue

    def on_llm_new_token(self, token: str, **kwargs):
        # Called for every new token from Gemini
        asyncio.create_task(self.queue.put(token))


@app.get("/chat-stream")
async def chat_stream(message: str):
    if not message.strip():
        return {"error": "Empty message"}

    async def event_generator():
        # 1️⃣ Input scan
        yield f"data:{json.dumps({'type': 'log', 'text': 'Scanning input via Prisma AIRS...'})}\n\n"
        input_scan = scan_with_prisma_airs(message)
        if "error" in input_scan:
            yield f"data:{json.dumps({'type':'error','text': input_scan['error']})}\n\n"
            return

        input_safe, input_msg = is_safe(input_scan)
        if not input_safe:
            yield f"data:{json.dumps({'type':'error','text': f'Blocked: {input_msg}', 'verdict': input_scan})}\n\n"
            return

        yield f"data:{json.dumps({'type': 'log', 'text': f'Input allowed by Prisma AIRS: {input_msg}'})}\n\n"

        # 2️⃣ Setup agent if needed
        if agent is None:
            yield f"data:{json.dumps({'type':'log','text':'Connecting to Terraform MCP...'})}\n\n"
            try:
                await init_agent()
                yield f"data:{json.dumps({'type':'log','text':'Connected to Terraform MCP and agent initialized.'})}\n\n"
            except Exception as e:
                yield f"data:{json.dumps({'type':'error','text': f'Failed to initialize agent: {str(e)}'})}\n\n"
                return

        terraform_context = None
        if "terraform" in message.lower() or "hcl" in message.lower():
            yield f"data:{json.dumps({'type':'log', 'text':'Streaming Terraform MCP response...'})}\n\n"
            terraform_q = {"messages":[{"role":"user","content":message}]}
            try:
                # ✅ invoke agent and simulate chunked streaming
                result = await agent.ainvoke(terraform_q)
                for line in str(result).splitlines():
                    yield f"data:{json.dumps({'type':'mcp','text':line})}\n\n"
                    await asyncio.sleep(0.02)
                terraform_context = "✅ MCP streaming complete"
            except Exception as e:
                yield f"data:{json.dumps({'type':'error','text': f'MCP streaming error: {str(e)}'})}\n\n"
                return

        # 3️⃣ Construct Gemini prompt
        system_prompt = (
            "You are a Helpful Infrastructure Agent. "
            "Answer Terraform questions clearly and provide examples where useful.\n\n"
        )
        if terraform_context:
            full_prompt = system_prompt + f"User Question:\n{message}\n\nTerraform MCP Context:\n{terraform_context}"
        else:
            full_prompt = system_prompt + f"User Question:\n{message}"

        yield f"data:{json.dumps({'type':'log','text':'Generating Gemini response...'})}\n\n"

        try:
            # Run Gemini in a separate thread to avoid blocking
            gemini_response = await asyncio.to_thread(llm.invoke, full_prompt)
            if callable(getattr(gemini_response, "text", None)):
                gemini_text = gemini_response.text()  # call if it's a method
            else:
                gemini_text = str(getattr(gemini_response, "text", gemini_response))

            # Yield the text in the event stream
            yield f"data:{json.dumps({'type': 'gemini', 'text': gemini_text})}\n\n"

        except Exception as e:
            # import traceback
            # traceback.print_exc()
            yield f"data:{json.dumps({'type':'error','text': f'Gemini error: {str(e)}'})}\n\n"

    return StreamingResponse(event_generator(), media_type="text/event-stream")

    
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
