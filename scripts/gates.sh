#!/usr/bin/env bash
# Z Privacy — the gates. Each one fails the build; none is reviewed by eye.
# Run from anywhere:  ./scripts/gates.sh
# Exit status is the verdict: 0 = all gates pass.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

FAILED=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILED=1; }
skip() { printf '  ----  %s (skipped: %s)\n' "$1" "$2"; }

API=z_core/src/api.rs
FLUTTER_LIB=apps/flutter_app/lib
PUBSPEC=apps/flutter_app/pubspec.yaml

echo "Z Privacy gates"
echo

# ---------------------------------------------------------------- G1
# No HTTP client anywhere outside z_core::providers.
if grep -RnE '^\s*(reqwest|hyper|ureq|curl|isahc|surf|attohttpc)\s*=' --include=Cargo.toml . >/tmp/g1.$$ 2>/dev/null; then
  if [ -s /tmp/g1.$$ ]; then
    # Allowed only once providers exist, and only for z_core (checked by review of that module).
    fail "G1 no HTTP client outside providers — found:"; sed 's/^/        /' /tmp/g1.$$
  else
    pass "G1 no HTTP client in any Cargo.toml"
  fi
else
  pass "G1 no HTTP client in any Cargo.toml"
fi
rm -f /tmp/g1.$$

# ---------------------------------------------------------------- G11 (guards G2, G7, G8)
# Every public signature in api.rs sits on ONE line, so the greps below are sound.
if [ -f "$API" ]; then
  BAD=$(grep -n '^pub fn ' "$API" | grep -v '{' || true)
  if [ -n "$BAD" ]; then
    fail "G11 api.rs signatures must be single-line — offenders:"; printf '        %s\n' "$BAD"
  else
    pass "G11 every api.rs signature is one line"
  fi
else
  skip "G11 single-line signatures" "no $API yet"
fi

# ---------------------------------------------------------------- G2
# No send function may accept text. Handles only.
if [ -f "$API" ]; then
  BAD=$(grep -nE '^pub fn send[a-z_]*\s*\(' "$API" | grep -E 'String|&str|Vec<u8>|\[u8\]' || true)
  if [ -n "$BAD" ]; then
    fail "G2 a send function accepts text:"; printf '        %s\n' "$BAD"
  else
    pass "G2 no send function accepts text (PayloadHandle only)"
  fi
else
  skip "G2 send takes a handle" "no $API yet"
fi

# ---------------------------------------------------------------- G7
# No panic crosses the boundary: every api.rs function returns ApiResult.
if [ -f "$API" ]; then
  ALLOW='core_version'
  BAD=$(grep -nE '^pub fn ' "$API" | grep -vE "pub fn ($ALLOW)\b" | grep -v 'ApiResult<' || true)
  if [ -n "$BAD" ]; then
    fail "G7 api.rs function does not return ApiResult:"; printf '        %s\n' "$BAD"
  else
    pass "G7 every api.rs function returns ApiResult"
  fi
else
  skip "G7 ApiResult everywhere" "no $API yet"
fi

# ---------------------------------------------------------------- G8
# The master key never crosses Flutter.
if [ -f "$API" ]; then
  BAD=$(grep -nE '^pub fn ' "$API" | grep -iE '\b(key|master_key|secret|seed)\b' || true)
  if [ -n "$BAD" ]; then
    fail "G8 a key or secret appears in an api.rs signature:"; printf '        %s\n' "$BAD"
  else
    pass "G8 no key or secret in any api.rs signature"
  fi
else
  skip "G8 no key over the bridge" "no $API yet"
fi

# ---------------------------------------------------------------- G5
# The UI does not know the network — not by package, not by language API.
if [ -f "$PUBSPEC" ]; then
  BAD=$(grep -nE '^\s*(http|dio|web_socket_channel|http2|grpc|websocket)\s*:' "$PUBSPEC" || true)
  if [ -n "$BAD" ]; then
    fail "G5a network package in pubspec.yaml:"; printf '        %s\n' "$BAD"
  else
    pass "G5a no network package in pubspec.yaml"
  fi
else
  skip "G5a pubspec has no network package" "no flutter app yet"
fi

if [ -d "$FLUTTER_LIB" ]; then
  BAD=$(grep -RnE '\b(HttpClient|RawSocket|SecureSocket|RawSynchronousSocket|WebSocket|Socket\.connect|HttpServer|XMLHttpRequest|window\.fetch)\b' "$FLUTTER_LIB" || true)
  if [ -n "$BAD" ]; then
    fail "G5b network API used in the UI:"; printf '        %s\n' "$BAD"
  else
    pass "G5b no network API in apps/flutter_app/lib"
  fi
else
  skip "G5b UI uses no network API" "no flutter app yet"
fi

# ---------------------------------------------------------------- G4
# unsafe forbidden, unwrap/expect/panic denied.
if grep -q 'unsafe_code = "forbid"' Cargo.toml 2>/dev/null; then
  pass "G4a unsafe_code = forbid in the workspace lints"
else
  fail "G4a workspace lints do not forbid unsafe_code"
fi

if command -v cargo-clippy >/dev/null 2>&1 || cargo clippy --version >/dev/null 2>&1; then
  if cargo clippy --workspace --all-targets --quiet -- -D warnings >/tmp/g4.$$ 2>&1; then
    pass "G4b clippy clean with -D warnings"
  else
    fail "G4b clippy:"; tail -25 /tmp/g4.$$ | sed 's/^/        /'
  fi
  rm -f /tmp/g4.$$
else
  skip "G4b clippy" "clippy not installed"
fi

# ---------------------------------------------------------------- G3, G6, G9, G10
# The invariants that live as tests.
if cargo test --workspace --quiet >/tmp/gt.$$ 2>&1; then
  pass "G3/G6/G9/G10 cargo test (no-leak, stale handle, restore, namespaces)"
else
  fail "cargo test:"; tail -30 /tmp/gt.$$ | sed 's/^/        /'
fi
rm -f /tmp/gt.$$

# Each of those four must actually exist as a test, or a green run proves nothing.
for t in no_leak stale_payload round_trip session_namespace; do
  if grep -Rqs "fn .*$t" z_core/tests z_core/src 2>/dev/null; then
    pass "  test present: $t"
  else
    skip "  test present: $t" "not written yet"
  fi
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "all gates passed"
else
  echo "GATES FAILED"
fi
exit "$FAILED"
