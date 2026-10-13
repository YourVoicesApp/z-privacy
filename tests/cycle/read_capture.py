#!/usr/bin/env python3
"""Print tokens in the captured Z request vs tokens the mock actually echoed.

Restore evidence uses the echoed set. Leftover clear values are listed
separately; they are not a protection failure unless the user chose them.
"""
from __future__ import annotations

import json
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent / "capture_server"))
from app import TOKEN_RE, default_reply_content  # noqa: E402

SECRETS = ("Alice Jensen", "Alicia Jensen", "IT60X0542811101000000123456")
CAP = "http://127.0.0.1:8081/requests"


def main() -> int:
    raw = urllib.request.urlopen(CAP, timeout=5).read().decode("utf-8")
    recs = json.loads(raw)
    if not recs:
        print("no captured requests")
        return 1
    rec = recs[-1]
    body = rec.get("body") or {}
    messages = body.get("messages") if isinstance(body, dict) else None
    asked = ""
    if isinstance(messages, list) and messages:
        last = messages[-1]
        if isinstance(last, dict) and isinstance(last.get("content"), str):
            asked = last["content"]
    blob = json.dumps(body, ensure_ascii=False)
    req_tokens = TOKEN_RE.findall(blob)
    print(f"path={rec.get('path')} stream={rec.get('stream')}")
    ua = (rec.get("headers") or {}).get("user-agent") or (rec.get("headers") or {}).get("User-Agent")
    print(f"user-agent={ua!r}")
    leaks = rec.get("leak_detected") or {}
    leftovers = rec.get("leftover_clear") or []
    print(f"leaks names={leaks.get('names')} ibans={leaks.get('ibans')}")
    print("leftover clear (recorded, not a mock FAIL):")
    if leftovers:
        for v in leftovers:
            print(f"  {v}")
    else:
        print("  (none)")
    print("request tokens:")
    for t in req_tokens:
        print(f"  {t}")
    reply = default_reply_content(asked, rec.get("placeholder"), list(leftovers))
    policy = "echo all tokens in last user message; strip leftover clear"
    echoed = TOKEN_RE.findall(reply)
    print(f"reply policy: {policy}")
    print("echoed tokens (restore these, and only these):")
    for t in echoed:
        print(f"  {t}")
    missing = [t for t in req_tokens if t not in echoed]
    if missing:
        print("in request, not echoed:")
        for t in missing:
            print(f"  {t}")
    for s in SECRETS:
        if s in blob:
            print(f"RAW IN REQUEST: {s}")
        if s in reply:
            print(f"RAW IN REPLY: {s}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
