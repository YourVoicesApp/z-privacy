#!/usr/bin/env python3
# tests/cycle/capture_server/app.py
# Minimal capture server used as a fake upstream provider during tests.

from flask import Flask, request, jsonify
from collections import deque
import threading
import json
import re

app = Flask(__name__)
lock = threading.Lock()
# stored requests
REQUESTS = []
# queue of prepared responses (list used as FIFO)
RESPONSES = deque()

IBAN_RE = re.compile(r"\b[A-Z]{2}[0-9A-Z]{13,30}\b", re.IGNORECASE)
PLACEHOLDER_RE = re.compile(r"\[([A-Z0-9_]+_\d+)\]")
NAME_RE = re.compile(r"\b([A-Z][a-z]+\s+[A-Z][a-z]+)\b")

@app.route('/prepare', methods=['POST'])
def prepare():
    """POST JSON { "responses": [ {"status":200, "body": {...}}, ... ] }

    Backwards compatible. Also accepts per-service list (ignored by proxy if not
    applicable)."""
    data = request.get_json(force=True)
    with lock:
        RESPONSES.clear()
        for r in data.get('responses', []):
            RESPONSES.append(r)
        REQUESTS.clear()
    return jsonify({"ok": True, "queued": len(RESPONSES)})


def detect_leaks(text):
    """Return detected raw values that look like sensitive content (IBANs, simple Name heuristics).
    We will log them as leaks but crucially we will NOT reuse them in synthesized replies.
    """
    leaks = {"ibans": [], "names": []}
    if not isinstance(text, str):
        text = str(text)
    for m in IBAN_RE.finditer(text):
        leaks['ibans'].append(m.group(0))
    for m in NAME_RE.finditer(text):
        # Avoid treating placeholders like [FULLNAME_1] as names; NAME_RE is naive
        leaks['names'].append(m.group(1))
    return leaks


def extract_placeholder(text):
    m = PLACEHOLDER_RE.search(text)
    if m:
        return '[' + m.group(1) + ']'
    return None


def render_template(body_template, placeholder):
    """Replace only the {{ph}} marker in the prepared response body with the
    confirmed placeholder token. Do NOT substitute names or IBANs into replies.
    If no placeholder is available, we emit a generic marker <UNKNOWN_TOKEN>.
    """
    if isinstance(body_template, dict):
        out = {}
        for k, v in body_template.items():
            if isinstance(v, str):
                out[k] = render_template(v, placeholder)
            else:
                out[k] = v
        return out
    if not isinstance(body_template, str):
        return body_template
    s = body_template
    tok = placeholder if placeholder else '<UNKNOWN_TOKEN>'
    return s.replace('{{ph}}', tok).replace('{{iban}}', '<REDACTED_IBAN>').replace('{{name}}', '<REDACTED_NAME>').replace('{{raw}}', '')

@app.route('/proxy', methods=['POST', 'GET', 'PUT', 'PATCH', 'DELETE'])
def proxy():
    rec = {
        'method': request.method,
        'path': request.path,
        'headers': {k: v for k, v in request.headers.items()},
        'args': request.args.to_dict(flat=True),
        'body': None,
        'leak_detected': {
            'ibans': [],
            'names': []
        }
    }
    try:
        rec['body'] = request.get_json(force=False)
    except Exception:
        rec['body'] = request.get_data(as_text=True)

    # Detect leaks but do NOT use them in replies
    raw_text = ''
    if isinstance(rec['body'], dict):
        try:
            raw_text = json.dumps(rec['body'])
        except Exception:
            raw_text = str(rec['body'])
    else:
        raw_text = str(rec['body'])

    leaks = detect_leaks(raw_text)
    rec['leak_detected']['ibans'] = leaks['ibans']
    rec['leak_detected']['names'] = leaks['names']

    # extract only confirmed placeholder tokens for reply substitution
    placeholder = extract_placeholder(raw_text)

    with lock:
        REQUESTS.append(rec)
        # choose next response in queue
        if RESPONSES:
            r = RESPONSES.popleft()
            status = r.get('status', 200)
            body = r.get('body', {})
            # only substitute confirmed placeholders; do not reinsert leaked raw values
            rendered = render_template(body, placeholder)
            headers = r.get('headers', {})
            return (jsonify(rendered), status, headers)
        else:
            # default safe reply: do not echo any sensitive content
            return (jsonify({"echo": True, "received": {"leak_detected": rec['leak_detected']}}), 200)

@app.route('/requests', methods=['GET'])
def get_requests():
    with lock:
        return jsonify(REQUESTS)

@app.route('/reset', methods=['POST'])
def reset():
    with lock:
        REQUESTS.clear()
        RESPONSES.clear()
    return jsonify({"ok": True})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8081)
