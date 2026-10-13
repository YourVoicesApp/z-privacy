#!/usr/bin/env bash
# Summarise tests/cycle/output after run_cycle.sh.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/output"
SUM="$OUT/summary.json"
CAP="$OUT/captured_requests.json"

if [[ ! -f "$SUM" ]]; then
  echo "No summary.json. Run bash tests/cycle/run_cycle.sh first." >&2
  exit 1
fi

python3 - "$SUM" "$CAP" <<'PY'
import json, sys
summary = json.loads(open(sys.argv[1], encoding="utf-8").read())
print(f"capture self-test: {summary.get('capture')}")
print(f"wire: {summary.get('wire')}")
print(f"app_started: {summary.get('app_started')}")
print(f"Z /analyze: {summary.get('z_http_analyze')}")
print(f"Rizzo /analyze: {summary.get('rizzo_http_analyze')}")
print(f"Secret Guard /analyze: {summary.get('secret_guard_http_analyze')}")
fails = summary.get("failures") or []
if fails:
    print("failures:")
    for f in fails:
        print(f"  - {f}")
else:
    print("failures: none")
print("notes:")
for n in summary.get("notes") or []:
    print(f"  - {n}")

path = sys.argv[2]
if not path:
    sys.exit(0)
try:
    captured = json.loads(open(path, encoding="utf-8").read())
except FileNotFoundError:
    print("no captured_requests.json")
    sys.exit(0)
print(f"captured upstream posts: {len(captured)}")
for i, rec in enumerate(captured, 1):
    leaks = rec.get("leak_detected") or {}
    print(
        f"  {i}. path={rec.get('path')} placeholder={rec.get('placeholder')!r} "
        f"ibans={len(leaks.get('ibans') or [])} names={len(leaks.get('names') or [])}"
    )
PY
