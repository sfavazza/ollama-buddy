#!/usr/bin/env python3

# references:
# - https://developers.openai.com/api/docs/guides/migrate-to-responses?lang=python&update-generation-endpoints=responses

import os
import re
import time

import requests

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
    "model": "gpt-5.6-luna",
    # it represents the 'system' input (equivalent to a input message item with role: 'system')
    "instructions": "Be concise and direct. Give short, focused answers without unnecessary elaboration.",
    "input": "alive?",
}

# works!!
r = requests.post(
    "https://api.githubcopilot.com/responses",
    headers=r_headers,
    json=json_payload,
)
r.raise_for_status()

# handle reply
reply_json = r.json()

# text reply is deep in the structure, multiple 'items' could be returned by the model:
reply_json.get("output")[0]["content"][0]["text"]

# NOTE: for more complex interactions, namely reasoning, tools, multimodal output (image,text,audio,video), an
# iteration over the response.output array is required
