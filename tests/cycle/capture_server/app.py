#!/usr/bin/env python3
"""Local fake upstream for the comparison cycle.

Speaks the wire Z Privacy actually uses: POST /v1/chat/completions
(OpenAI-compatible JSON). There is no /analyze here, because this app
does not expose one.

Safety: replies never reuse raw names, emails, or IBANs found in the
request. Default replies echo every __Z_<ns>_<KIND>_<tail>__ token in the
last user message, even when leftover clear values remain. Those leftovers
are recorded on the request as leftover_clear and stripped from the reply.
Only confirmed Z tokens are substituted into {{ph}}.
"""
from __future__ import annotations

import json
import re
import threading
from collections import deque
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse

HOST = "127.0.0.1"
PORT = 8081

IBAN_RE = re.compile(r"\b[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}\b")
# Z Privacy tokens, see z_core/src/tokens.rs.
TOKEN_RE = re.compile(r"__Z_[A-Za-z0-9]+_[A-Z]+_[0-9A-Fa-f]+__")
# Two capitalised words, but not a token fragment.
NAME_RE = re.compile(r"\b([A-Z][a-z]+ [A-Z][a-z]+)\b")
EMAIL_RE = re.compile(r"\b[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}\b")
LEFT_CLEAR = "<LEFT_CLEAR>"

lock = threading.Lock()
REQUESTS: list[dict[str, Any]] = []
RESPONSES: deque[dict[str, Any]] = deque()


def detect_leaks(text: str) -> dict[str, list[str]]:
    ibans = IBAN_RE.findall(text)
    names = [m for m in NAME_RE.findall(text) if not m.startswith("__Z_")]
    return {"ibans": ibans, "names": names}


def extract_token(text: str) -> str | None:
    m = TOKEN_RE.search(text)
    return m.group(0) if m else None


def extract_tokens(text: str) -> list[str]:
    return TOKEN_RE.findall(text)


def leftover_clear_values(text: str, leaks: dict[str, list[str]]) -> list[str]:
    """Clear values still in the request. Recorded separately; not a mock FAIL."""
    found: list[str] = []
    for group in (leaks.get("names") or [], leaks.get("ibans") or [], EMAIL_RE.findall(text)):
        for item in group:
            if item and item not in found:
                found.append(item)
    return found


def redact_originals(text: str, originals: list[str]) -> str:
    out = text
    for orig in sorted({o for o in originals if o}, key=len, reverse=True):
        out = out.replace(orig, LEFT_CLEAR)
    return out


def default_reply_content(asked: str, token: str | None, leftovers: list[str]) -> str:
    """Echo every actual __Z_…__ token in the last user message, unchanged.

    Leftover clear values stay recorded on the request and are stripped from
    the reply. They are not treated as a protection failure here.
    """
    if asked:
        return f"RESTORE_OK: {redact_originals(asked, leftovers)}"
    return f"RESTORE_OK: {token or '<UNKNOWN_TOKEN>'}"


def user_content(payload: Any) -> str:
    if not isinstance(payload, dict):
        return ""
    messages = payload.get("messages")
    if not isinstance(messages, list) or not messages:
        return ""
    last = messages[-1]
    if isinstance(last, dict) and isinstance(last.get("content"), str):
        return last["content"]
    return ""


def wants_stream(payload: Any) -> bool:
    return isinstance(payload, dict) and payload.get("stream") is True


def render_template(body: Any, token: str | None) -> Any:
    tok = token if token else "<UNKNOWN_TOKEN>"
    if isinstance(body, dict):
        return {k: render_template(v, token) for k, v in body.items()}
    if isinstance(body, list):
        return [render_template(v, token) for v in body]
    if not isinstance(body, str):
        return body
    return (
        body.replace("{{ph}}", tok)
        .replace("{{iban}}", "<REDACTED_IBAN>")
        .replace("{{name}}", "<REDACTED_NAME>")
        .replace("{{raw}}", "")
    )


def openai_wrap(content: str, model: str) -> dict[str, Any]:
    return {
        "id": "chatcmpl-cycle-local",
        "object": "chat.completion",
        "model": model,
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": content},
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }


def body_text(payload: Any) -> str:
    if isinstance(payload, (dict, list)):
        return json.dumps(payload, ensure_ascii=False)
    return str(payload)


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, fmt: str, *args: Any) -> None:
        # Keep the mock quiet; the cycle scripts write their own log.
        return

    def _read_json(self) -> Any:
        length = int(self.headers.get("Content-Length") or "0")
        raw = self.rfile.read(length) if length else b""
        if not raw:
            return None
        try:
            return json.loads(raw.decode("utf-8"))
        except json.JSONDecodeError:
            return raw.decode("utf-8", errors="replace")

    def _send(self, status: int, payload: Any, headers: dict[str, str] | None = None) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.end_headers()
        self.wfile.write(body)

    def _send_sse(self, content: str, model: str) -> None:
        """OpenAI-style chat.completion.chunk stream. Z currently sends stream:false
        and parses a full JSON body; this path exists so a stream:true request is
        not answered with a shape the client cannot read.
        """
        chunks = [
            {
                "id": "chatcmpl-cycle-local",
                "object": "chat.completion.chunk",
                "model": model,
                "choices": [
                    {
                        "index": 0,
                        "delta": {"role": "assistant", "content": content},
                        "finish_reason": None,
                    }
                ],
            },
            {
                "id": "chatcmpl-cycle-local",
                "object": "chat.completion.chunk",
                "model": model,
                "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
            },
        ]
        parts = [f"data: {json.dumps(c, ensure_ascii=False)}\n\n".encode("utf-8") for c in chunks]
        parts.append(b"data: [DONE]\n\n")
        body = b"".join(parts)
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path in ("/health", "/"):
            self._send(200, {"ok": True, "service": "cycle-capture", "wire": "/v1/chat/completions"})
            return
        if path == "/requests":
            with lock:
                self._send(200, list(REQUESTS))
            return
        self._send(404, {"error": "not found", "path": path})

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        payload = self._read_json()
        if path == "/prepare":
            queued = 0
            with lock:
                RESPONSES.clear()
                REQUESTS.clear()
                items = []
                if isinstance(payload, dict):
                    items = payload.get("responses") or []
                for item in items:
                    if isinstance(item, dict):
                        RESPONSES.append(item)
                        queued += 1
            self._send(200, {"ok": True, "queued": queued})
            return
        if path == "/reset":
            with lock:
                REQUESTS.clear()
                RESPONSES.clear()
            self._send(200, {"ok": True})
            return
        if path in ("/v1/chat/completions", "/proxy", "/chat/completions"):
            self._handle_upstream(path, payload)
            return
        self._send(404, {"error": "not found", "path": path})

    def _reply(self, content: str, model: str, stream: bool) -> None:
        if stream:
            self._send_sse(content, model)
        else:
            self._send(200, openai_wrap(content, model))

    def _handle_upstream(self, path: str, payload: Any) -> None:
        raw = body_text(payload)
        leaks = detect_leaks(raw)
        token = extract_token(raw)
        tokens = extract_tokens(raw)
        asked = user_content(payload)
        stream = wants_stream(payload)
        leftovers = leftover_clear_values(asked or raw, leaks)
        rec = {
            "method": "POST",
            "path": path,
            "headers": {k: v for k, v in self.headers.items()},
            "body": payload,
            "leak_detected": leaks,
            "leftover_clear": leftovers,
            "placeholder": token,
            "placeholders": tokens,
            "stream": stream,
        }
        model = "cycle-mock"
        if isinstance(payload, dict) and isinstance(payload.get("model"), str):
            model = payload["model"]

        with lock:
            REQUESTS.append(rec)
            prepared = RESPONSES.popleft() if RESPONSES else None

        if prepared is None:
            # Return every token in the last user message, even if names or
            # IBANs remain in the clear. Never copy those original values.
            content = default_reply_content(asked, token, leftovers)
            self._reply(content, model, stream)
            return

        status = int(prepared.get("status", 200))
        body = prepared.get("body", {})
        rendered = render_template(body, token)
        extra_headers = prepared.get("headers") if isinstance(prepared.get("headers"), dict) else None

        if stream:
            if isinstance(rendered, dict) and isinstance(rendered.get("content"), str):
                self._send_sse(rendered["content"], model)
            elif isinstance(rendered, str):
                self._send_sse(rendered, model)
            else:
                self._send_sse(token or "<UNKNOWN_TOKEN>", model)
            return

        if isinstance(rendered, dict) and "choices" in rendered:
            self._send(status, rendered, extra_headers)
            return
        if isinstance(rendered, dict) and "content" in rendered:
            content = rendered["content"]
            if not isinstance(content, str):
                content = json.dumps(content)
            self._send(status, openai_wrap(content, model), extra_headers)
            return
        if isinstance(rendered, str):
            self._send(status, openai_wrap(rendered, model), extra_headers)
            return
        self._send(status, openai_wrap("<UNKNOWN_TOKEN>", model), extra_headers)


def serve(host: str = HOST, port: int = PORT) -> ThreadingHTTPServer:
    httpd = ThreadingHTTPServer((host, port), Handler)
    return httpd


def main() -> None:
    httpd = serve()
    print(f"cycle-capture listening on http://{HOST}:{PORT}/v1/chat/completions", flush=True)
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
