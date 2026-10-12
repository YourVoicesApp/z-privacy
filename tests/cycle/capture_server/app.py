#!/usr/bin/env python3
# tests/cycle/capture_server/app.py
# Minimal capture server used as a fake upstream provider during tests.

from flask import Flask, request, jsonify
from collections import deque
import threading
import json

app = Flask(__name__)
lock = threading.Lock()
# stored requests
REQUESTS = []
# queue of prepared responses
RESPONSES = deque()

@app.route('/prepare', methods=['POST'])
def prepare():
    """POST JSON { "responses": [ {"status":200, "body": {...}}, ... ] }"""
    data = request.get_json(force=True)
    with lock:
        RESPONSES.clear()
        for r in data.get('responses', []):
            RESPONSES.append(r)
        REQUESTS.clear()
    return jsonify({"ok": True, "queued": len(RESPONSES)})

@app.route('/proxy', methods=['POST', 'GET', 'PUT', 'PATCH', 'DELETE'])
def proxy():
    rec = {
        'method': request.method,
        'path': request.path,
        'headers': {k: v for k, v in request.headers.items()},
        'args': request.args.to_dict(flat=True),
        'body': None,
    }
    try:
        rec['body'] = request.get_json(force=False)
    except Exception:
        rec['body'] = request.get_data(as_text=True)
    with lock:
        REQUESTS.append(rec)
        if RESPONSES:
            r = RESPONSES.popleft()
            status = r.get('status', 200)
            body = r.get('body', {})
            headers = r.get('headers', {})
            return (jsonify(body), status, headers)
        else:
            # default echo
            return (jsonify({"echo": True, "received": rec}), 200)

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
