# tests/cycle/README

This folder contains an automated test scaffold to exercise a single end-to-end anonymization/restore cycle against three local services:

- Z (this repository) — expected to expose an `analyze` endpoint (default: http://localhost:5005/analyze) and a PDF `POST /pdf` download endpoint
- Rizzo (rizzo-pii) — expected to expose `POST /analyze` on http://localhost:5006
- Secret Guard — expected to expose a compatible endpoint on http://localhost:5007 (gateway mode)

A minimal local "capture" server (inside this folder) acts as a fake upstream provider. The tests do NOT send any data to the internet — everything runs locally.

Prerequisites
- Docker & docker-compose for the capture server (optional: you can run the capture server directly with Python).
- curl, jq, bash (for the helper scripts).
- The three services must be available locally (you can run them from their repositories):
  - Z: run your dev server so `http://localhost:5005/analyze` accepts requests.
  - Rizzo: run it locally so `http://localhost:5006/analyze` accepts requests.
  - Secret Guard: run it locally so `http://localhost:5007` is reachable.

Note: this scaffold does NOT modify application code. It only posts synthetic payloads to the services and captures what they attempt to send to the upstream provider. Configure each service (their UI or env) so their provider/upstream target is `http://capture:8081/proxy` (if using docker-compose) or `http://localhost:8081/proxy` when running capture_server locally.

Test plan

1) Prepare capture server responses: the capture server will be primed with three responses that emulate an LLM reply sequence: (A) correct restoration using the placeholders present; (B) a reply that splits/rearranges a placeholder; (C) a reply that invents unknown tokens.

2) Send synthetic inputs to each service. The input contains:
   - One person with two alternative spellings ("Alice Jensen", "Alicia Jensen") that should be recognized as the same identity if the system supports aliases.
   - A second person with the same visible name as the first ("Alice Jensen") but who should be considered a distinct identity.

3) For each service, capture what gets sent to the upstream provider (the capture server). Inspect whether the original values are present, whether placeholders traveled, and whether the mapping (if present) is sent.

4) After the first run, test session persistence for the service that supports it by: saving the mapping/local state, stopping the service process, restarting it, and attempting to restore using the saved mapping. The script `run_cycle.sh` will attempt this for Z where applicable; you may run the same steps manually for the other services.

5) Test negative case: lock the vault / disable mapping (as appropriate) and confirm the upstream does not receive real values.

What the scripts do
- `docker-compose.yml` brings up the capture server as a docker service named `capture`.
- `capture_server/` contains a small Flask app that records incoming proxied requests and returns the next response from a prepared queue.
- `run_cycle.sh` performs the steps and writes captured requests to `tests/cycle/output/`.
- `check_results.sh` summarizes the captured requests.

Running the tests

1) Start the three target services (Z, Rizzo, Secret Guard) locally on the ports above and configure their upstream provider URL to `http://localhost:8081/proxy` (or use compose and set it to `http://capture:8081/proxy`).

2) Start the capture server (docker-compose up -d) or run it locally:

   docker-compose up -d
   # or
   python3 tests/cycle/capture_server/app.py

3) Make the capture server accept the three canned responses and clear any previous log:

   curl -s -X POST http://localhost:8081/prepare -H 'Content-Type: application/json' \
     -d '{"responses": [
       {"status":200, "body": {"content":"RESTORE: placeholder -> real (A)"}},
       {"status":200, "body": {"content":"FRAGMENTED: [FULLNAME_\""}},
       {"status":200, "body": {"content":"UNKNOWN_TOKEN: <X_999>"}}
     ]}'

4) Run the test runner:

   bash tests/cycle/run_cycle.sh

5) Inspect results:

   bash tests/cycle/check_results.sh

Limitations & notes
- The scaffold only exercises the public endpoints of each service and inspects what they attempt to send out. It does not (and must not) modify applications' source code.
- You must configure each target service to use the capture server as its upstream provider.
- Some services have UI-only switches; if so, use their UI or environment variables to toggle mapping_enabled and other prefs before running the script.
- The script expects the services to behave like documented upstream clients (POST /analyze → service builds a request to the configured provider). If a service requires a different endpoint, adapt `run_cycle.sh` accordingly.

Reporting
- After the run the script will write `tests/cycle/output/` with raw request captures and a summary. Please attach or paste the summary when you want me to analyze the results.

