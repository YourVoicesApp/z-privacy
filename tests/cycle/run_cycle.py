#!/usr/bin/env python3
"""Exercise the capture server against the real Z Privacy wire shape.

Does not start the desktop app. Does not POST to /analyze (this app has none).
Does not contact a real provider.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "output"
CAPTURE = os.environ.get("CYCLE_CAPTURE", "http://127.0.0.1:8081")
SERVER = HERE / "capture_server" / "app.py"

SYNTHETIC_RAW = (
    "Document: Alice Jensen (also seen as Alicia Jensen) met with Alice Jensen "
    "in another place. Account: IT60X0542811101000000123456"
)
SYNTHETIC_SAFE = (
    "Document: __Z_S1_PERSON_AAA1__ (also seen as __Z_S1_PERSON_AAA1__) met with "
    "__Z_S1_PERSON_BBB2__ in another place. Account: __Z_S1_IBAN_CCC3__"
)
SECRETS = ("Alice Jensen", "Alicia Jensen", "IT60X0542811101000000123456")


def http_json(method: str, url: str, payload: object | None = None, timeout: float = 5.0):
    data = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = raw
        return e.code, parsed


def wait_health(url: str, tries: int = 40) -> None:
    last = None
    for _ in range(tries):
        try:
            status, body = http_json("GET", url + "/health")
            if status == 200:
                return
            last = (status, body)
        except Exception as e:  # noqa: BLE001 — probe until up or out of tries
            last = e
        time.sleep(0.05)
    raise SystemExit(f"capture server did not become ready at {url}: {last}")


def chat(url: str, content: str, model: str = "cycle-mock", stream: bool = False):
    payload = {
        "model": model,
        "messages": [{"role": "user", "content": content}],
        "stream": stream,
    }
    if stream:
        data = json.dumps(payload).encode("utf-8")
        req = urllib.request.Request(
            url + "/v1/chat/completions",
            data=data,
            headers={"Content-Type": "application/json", "Accept": "text/event-stream"},
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5.0) as resp:
            raw = resp.read().decode("utf-8")
            ctype = resp.headers.get("Content-Type", "")
            return resp.status, raw, ctype
    return http_json("POST", url + "/v1/chat/completions", payload)


def content_of(body: object) -> str:
    if not isinstance(body, dict):
        return str(body)
    try:
        return body["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError):
        return json.dumps(body)


def write(name: str, payload: object) -> None:
    path = OUT / name
    if isinstance(payload, (dict, list)):
        path.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    else:
        path.write_text(str(payload) + "\n", encoding="utf-8")


def probe_analyze(name: str, url: str) -> str:
    """Record that a foreign HTTP analyze URL is absent. Never invent it."""
    try:
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=1.0) as resp:
            code = resp.status
    except urllib.error.HTTPError as e:
        code = e.code
    except Exception:  # noqa: BLE001
        code = 0
    if 200 <= int(code) < 300:
        write(f"{name}.status", str(code))
        return "PRESENT"
    write(f"{name}.status", "SKIPPED")
    write(
        f"{name}.skip_reason",
        f"{url} did not answer 2xx (code={code}). This Z Privacy build is a "
        "desktop FFI app; it has no /analyze HTTP API. Marked SKIPPED.",
    )
    return "SKIPPED"


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    (HERE / "sandbox").mkdir(parents=True, exist_ok=True)

    proc = subprocess.Popen(
        [sys.executable, str(SERVER)],
        cwd=str(HERE / "capture_server"),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    failures: list[str] = []
    try:
        wait_health(CAPTURE)
        http_json(
            "POST",
            CAPTURE + "/prepare",
            {
                "responses": [
                    {"status": 200, "body": {"content": "RESTORE_OK: {{ph}}"}},
                    {"status": 200, "body": {"content": "RESTORE_OK: {{ph}}"}},
                ]
            },
        )

        # Case 1: a leaky body, as if the product had failed to protect.
        st, leaky_body = chat(CAPTURE, SYNTHETIC_RAW)
        leaky_text = content_of(leaky_body)
        write("leaky.response.json", leaky_body)
        write("leaky.status", str(st))
        if st != 200:
            failures.append(f"leaky request status {st}")
        for secret in SECRETS:
            if secret in leaky_text:
                failures.append(f"capture echoed secret in leaky reply: {secret}")

        # Case 2: the shape Z actually puts on the wire (tokens, no raw values).
        st, safe_body = chat(CAPTURE, SYNTHETIC_SAFE)
        safe_text = content_of(safe_body)
        write("safe.response.json", safe_body)
        write("safe.status", str(st))
        if st != 200:
            failures.append(f"safe request status {st}")
        if "__Z_S1_PERSON_AAA1__" not in safe_text:
            failures.append(f"safe reply did not carry the confirmed token: {safe_text!r}")
        for secret in SECRETS:
            if secret in safe_text:
                failures.append(f"capture put a raw secret into a tokenized reply: {secret}")

        # Z currently sends stream:false. Prove the mock still answers stream:true
        # with SSE chunks, not a JSON body the streaming client could not parse.
        st, sse_raw, sse_type = chat(CAPTURE, SYNTHETIC_SAFE, stream=True)
        write("stream.response.txt", sse_raw)
        write("stream.status", str(st))
        if st != 200:
            failures.append(f"stream request status {st}")
        if "text/event-stream" not in sse_type:
            failures.append(f"stream Content-Type was {sse_type!r}")
        if "data: " not in sse_raw or "[DONE]" not in sse_raw:
            failures.append("stream body was not SSE")
        if "__Z_S1_PERSON_AAA1__" not in sse_raw:
            failures.append("stream reply did not carry the confirmed token")
        for secret in SECRETS:
            if secret in sse_raw:
                failures.append(f"stream reply contained a raw secret: {secret}")

        # Optional foreign HTTP services from the older scaffold: probe only.
        z_http = probe_analyze("Z", os.environ.get("Z_ENDPOINT", "http://127.0.0.1:5005/analyze"))
        rizzo = probe_analyze("RIZZO", os.environ.get("RIZZO_ENDPOINT", "http://127.0.0.1:5006/analyze"))
        sg = probe_analyze("SG", os.environ.get("SG_ENDPOINT", "http://127.0.0.1:5007/analyze"))

        _, captured = http_json("GET", CAPTURE + "/requests")
        write("captured_requests.json", captured)

        if not isinstance(captured, list) or len(captured) < 3:
            failures.append(f"expected three captured upstream posts, got {captured!r}")
        else:
            leak_flags = captured[0].get("leak_detected") or {}
            if not leak_flags.get("ibans") or not leak_flags.get("names"):
                failures.append(f"leaky capture did not flag raw values: {leak_flags}")
            safe_flags = captured[1].get("leak_detected") or {}
            if SYNTHETIC_RAW.split("Account: ")[-1] in json.dumps(safe_flags):
                failures.append("tokenized capture still listed the raw IBAN as a leak")
            if captured[1].get("placeholder") != "__Z_S1_PERSON_AAA1__":
                failures.append(f"token not extracted: {captured[1].get('placeholder')}")
            if captured[2].get("stream") is not True:
                failures.append("third capture was not marked stream=true")

        summary = {
            "capture": "PASS" if not failures else "FAIL",
            "failures": failures,
            "z_http_analyze": z_http,
            "rizzo_http_analyze": rizzo,
            "secret_guard_http_analyze": sg,
            "wire": "POST /v1/chat/completions",
            "app_started": False,
            "notes": [
                "Z Privacy is a Flutter desktop app talking to z_core over FFI.",
                "Its provider wire is OpenAI-compatible POST /v1/chat/completions.",
                "Tokens look like __Z_<namespace>_<KIND>_<tail>__, not [FULLNAME_1].",
                "Driving Import → Protect → Connect → Send in the UI is manual.",
            ],
        }
        write("summary.json", summary)
        write("payload_raw.txt", SYNTHETIC_RAW)
        write("payload_safe.txt", SYNTHETIC_SAFE)
        print(json.dumps(summary, indent=2, ensure_ascii=False))
        return 1 if failures else 0
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait(timeout=3)
        log = OUT / "capture_server.log"
        if proc.stdout is not None:
            log.write_text(proc.stdout.read() or "", encoding="utf-8")


if __name__ == "__main__":
    sys.exit(main())
