#!/usr/bin/env python3
# Test using OpenAI ollama request. Request formed based on `ollama-buddy--send-payload` in `ollama-buddy.el`
# references:
# - https://developers.openai.com/api/docs/guides/migrate-to-responses?lang=python&update-generation-endpoints=responses

import os
import re
import time

import requests

json_payload={
    "model":"qwen3:8b",
    "messages":[
        {
            "role": "system",
            "content": "Respond like smart caveman. Cut all filler, keep technical substance."
        },
        {
            "role":"user",
            "content":"hello"
        },
        {
            "role":"assistant",
            "content":"What you need?"
        },
        {
            "role":"user",
            "content":"hello"
        }
    ],
    "stream": True,
    "think": True,
    "system": "Respond like smart caveman. Cut all filler, keep technical substance."
}

r_headers = {
    "Content-Type": "application/json",
    "Content-Length": f"{len(json_payload)}",
}

# works!!
r = requests.post(
    "http://armadillo12:11434/api/chat",
    headers=r_headers,
    json=json_payload,
)
r.raise_for_status()

# handle reply
# reply_json = r.json()

# # text reply is deep in the structure, multiple 'items' could be returned by the model:
# reply_json.get("output")[0]["content"][0]["text"]

# # NOTE: for more complex interactions, namely reasoning, tools, multimodal output (image,text,audio,video), an
# # iteration over the response.output array is required
