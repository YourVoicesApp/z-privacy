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
  - Secret Guard: run it locally so `http://localhost:5007/analyze` accepts requests.

Note: this scaffold does NOT modify application code. It only posts synthetic payloads to the services and captures what they attempt to send to the upstream provider. Configure each service (their UI or env) so their provider/upstream target is `http://capture:8081/proxy` (if using docker-compose) or `http://localhost:8081/proxy` when running capture_server locally.

Test plan (revised)

1) Prepare capture server responses: the capture server will be primed with templated responses that may include markers ({{ph}}). The capture server will replace those markers at request time using tokens it extracts from the incoming request body — this avoids assuming a fixed placeholder syntax like [FULLNAME_1].

2) Send synthetic inputs to each service. The input contains:
   - One person with two alternative spellings ("Alice Jensen", "Alicia Jensen") that should be recognized as the same identity if the system supports aliases.
   - A second person with the same visible name as the first ("Alice Jensen") but who should be considered a distinct identity.

3) For each service, capture what gets sent to the upstream provider (the capture server). Inspect whether the original values are present (these are logged as leaks), whether placeholders traveled, and whether the mapping (if present) is sent.

4) Session persistence for Z (best-effort): the runner will try to detect a doc download URL or doc_id in Z's machine-readable response and download the anonymized PDF. If the service exposes export/import mapping endpoints, the runner will try to use them. If not present, the README documents the manual steps to perform the session persistence test.

5) Negative case: disable mapping or lock the vault (as appropriate) and confirm the upstream does not receive real values.

Important safety rule (implemented in capture server)
- The capture server will NOT construct reply bodies from raw detected IBANs or plain names. It will only substitute confirmed placeholder tokens present in the incoming request (e.g. [FULLNAME_1]) into templated replies. If only raw values are present they will be logged as leaks and the capture server will reply with <UNKNOWN_TOKEN> or the placeholder if available.

Wrong-session test (manual)
- The runner will NOT invent export/import endpoints or perform actions that are not documented by the services. To test wrong-session behavior you must create a second independent vault/session within your application and attempt to open the anonymized PDF produced by the first session without importing the mapping or keys. The expected result is a refusal to restore values or an indication that the session does not have the right mapping.

Implementation notes
- The runner will probe each service's analyze endpoint for 2xx before sending the test payload; if the probe fails the test is skipped for automation and marked as SKIPPED.
- The capture server records any raw-looking IBANs or capitalized two-word sequences as leaks (logged as `leak_detected` in the captured request), but it will not reuse them when rendering responses.
- The runner records raw HTTP responses and status codes in tests/cycle/output/ for later inspection.
- The runner does not invent or modify application interfaces; if the application does not expose a programmatic export/import for sessions the persistence test is marked as manual.

Running the tests

1) Start the three target services (Z, Rizzo, Secret Guard) locally on the ports above and configure their upstream provider URL to `http://localhost:8081/proxy` (or `http://capture:8081/proxy` inside compose).

2) Start the capture server (docker-compose up -d) or run it locally:

   docker-compose up -d
   # or
   python3 tests/cycle/capture_server/app.py

3) Run the test runner:

   bash tests/cycle/run_cycle.sh

4) Inspect results:

   bash tests/cycle/check_results.sh

Limitations & notes
- The scaffold only exercises the documented public endpoints of each service and inspects what they attempt to send out. It does not (and must not) modify applications' source code.
- Some services expose UI-only controls for mapping export/import; the runner will report these as manual steps when programmatic endpoints are not found.
- The runner uses lightweight heuristics to detect raw values; if your service encodes placeholders differently, provide a brief note in the README and the capture server can be adapted.

Reporting
- After the run the script will write `tests/cycle/output/` with raw request captures and a summary. Please attach or paste the summary when you want me to analyze the results.

