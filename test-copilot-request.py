import os
import re
import time

import requests

# understand proper model API slug
# TODO: send proper request to known to work model (kimi-k2.7-code) based on
# `ollama-buddy-copilot--send-with-token` function defined in
# /home/sfavazza/git/external/ollama-buddy/ollama-buddy-copilot.el.


oauth_key = os.getenv("COPILOT_OAUTH_KEY")
if not oauth_key:
    raise RuntimeError("environment does not feature COPILOT_OAUTH_KEY, aborting...")

token = None
token_expire = None

def request_token(token, token_expire):

    if not token or int(token_expire) <= int(time.clock_gettime(time.CLOCK_REALTIME)):
        # request a token WARNING: it feature an expiration time, no need to request it on every request
        t_headers = {
            "Authorization": f"token {oauth_key}",
            "Accept": "application/json",
            "Editor-Version": "Emacs/29.0",
            "Editor-Plugin-Version": "ollama-buddy/1.0.0",
            "User-Agent": "ollama-buddy",
        }
        t = requests.get(
            "https://api.github.com/copilot_internal/v2/token",
            headers=t_headers,
        )
        t.raise_for_status()

        token = t.json()["token"]
        token_expire = re.search(r"exp=(?P<expires>\d+)", t.json()["token"]).groupdict()["expires"]

    return token, token_expire


token, token_expire = request_token(token, token_expire)
r_headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {token}",
    "Editor-Version": "vscode/1.85.0",
    "Editor-Plugin-Version": "copilot-chat/0.12.0",
    "Openai-Organization": "github-copilot",
    "Openai-Intent": "conversation-panel",
    "User-Agent": "GitHubCopilotChat/0.12.0",
    # extra in other values
    "Charset": "utf-8",
    "Accept": "application/json"
}

json_payload={
    # "model":"kimi-k2.7-code",
    # "model":"kimi-k3",
    # "model":"claude-sonnet-5",
    # "model":"claude-opus-5",
    # "model":"gemini-3.8-flash",
    "model":"gemini-3.7-flash",
    # DONT: not working
    # "model":"mai-code-1-flash",
    # "model":"gpt-5.6-terra",
    # "model":"gpt-5.6-sol",
    # "model":"gpt-5.3-codex",
    # "model":"mai-code-1.1-flash",
    "messages": [
        {
            "role":"system",
            "content": "Format responses in plain prose. Never use markdown tables. Use clear paragraphs and bullet points for structured information.\n\nRespond like smart caveman. Cut all filler, keep technical substance.\n- Drop articles (a, an, the), filler (just, really, basically, actually).\n- Drop pleasantries (sure, certainly, happy to).\n- No hedging. Fragments fine. Short synonyms. Short sentences.\n- Technical terms stay exact. Code blocks unchanged.\n- Pattern: thing -> action -> reason -> next step.\n- Reply only with requested info, straight to the point, no topic introduction.\n- Do not propose additional topics/alternative interpretations.\n- Do not repeat prompt.\n- When a prompt is ambiguous:\n - do not assume, ask!\n  - ask until mutual understanding about what to do"
        },
        {
            "role":"user",
            "content":"hello"
        }
    ],
    # "temperature":0.7,
    # "max_completion_tokens": 4096,
}
r = requests.post(
    "https://api.githubcopilot.com/chat/completions",
    headers=r_headers,
    json=json_payload,
)
r.raise_for_status()
