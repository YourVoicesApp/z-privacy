#!/usr/bin/env bash
# Z Privacy — the gates. Each one fails the build; none is reviewed by eye.
# Run from anywhere:  ./scripts/gates.sh
# Exit status is the verdict: 0 = all gates pass.
#
# What each gate defends is written in docs/SECURITY_INVARIANTS.md.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

FAILED=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILED=1; }
skip() { printf '  ----  %s (skipped: %s)\n' "$1" "$2"; }

# The two surfaces the UI can reach: the core contract and its bridge wrapper.
API_FILES="z_core/src/api.rs bridges/native/z_bridge/src/api/core.rs"
# Functions allowed not to return ApiResult, because they cannot fail:
ALLOW_PLAIN="core_version|init_app"
FLUTTER_LIB=apps/flutter_app/lib
PUBSPEC=apps/flutter_app/pubspec.yaml

echo "Z Privacy gates"
echo

# ---------------------------------------------------------------- G1
# No HTTP client anywhere outside z_core::providers (which does not exist yet).
HITS=$(grep -RnE '^\s*(reqwest|hyper|ureq|curl|isahc|surf|attohttpc)\s*=' --include=Cargo.toml . || true)
if [ -n "$HITS" ]; then
  fail "G1 HTTP client in a Cargo.toml:"; printf '        %s\n' "$HITS"
else
  pass "G1 no HTTP client in any Cargo.toml"
fi

# ---------------------------------------------------------------- G11, G2, G7, G8
for API in $API_FILES; do
  if [ ! -f "$API" ]; then
    skip "G11/G2/G7/G8 on $API" "file not there yet"
    continue
  fi
  SIGS=$(grep -n '^pub fn ' "$API")

  # G11 (guards the three below): every public signature sits on ONE line.
  BAD=$(printf '%s\n' "$SIGS" | grep -v '{' || true)
  if [ -n "$BAD" ]; then
    fail "G11 $API: signature spans lines:"; printf '        %s\n' "$BAD"
  else
    pass "G11 $API: every signature is one line"
  fi

  # G2: no send function accepts text.
  BAD=$(printf '%s\n' "$SIGS" | grep -E 'pub fn send[a-z_]*[[:space:]]*\(' | grep -E 'String|&str|Vec<u8>|\[u8\]' || true)
  if [ -n "$BAD" ]; then
    fail "G2 $API: a send function accepts text:"; printf '        %s\n' "$BAD"
  else
    pass "G2 $API: send takes a handle, never text"
  fi

  # G7: no panic crosses the boundary — everything returns ApiResult.
  BAD=$(printf '%s\n' "$SIGS" | grep -vE "pub fn ($ALLOW_PLAIN)\b" | grep -v 'ApiResult<' || true)
  if [ -n "$BAD" ]; then
    fail "G7 $API: function does not return ApiResult:"; printf '        %s\n' "$BAD"
  else
    pass "G7 $API: every function returns ApiResult"
  fi

  # G8: no key, secret or seed in any signature.
  BAD=$(printf '%s\n' "$SIGS" | grep -iE '\b(key|master_key|secret|seed)\b' || true)
  if [ -n "$BAD" ]; then
    fail "G8 $API: a key or secret in a signature:"; printf '        %s\n' "$BAD"
  else
    pass "G8 $API: no key or secret in any signature"
  fi
done


# ---------------------------------------------------------------- G12
# The bridge mirrors are generated from the contract. If they drift, Dart gets a
# class with a missing field and nobody notices until the UI misbehaves.
if [ -f scripts/gen_mirrors.py ]; then
  if python3 scripts/gen_mirrors.py --check >/tmp/g12.$$ 2>&1; then
    pass "G12 bridge mirrors match the contract"
  else
    fail "G12 mirrors are stale:"; sed 's/^/        /' /tmp/g12.$$
  fi
  rm -f /tmp/g12.$$
else
  skip "G12 mirrors match the contract" "no generator yet"
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
  BAD=$(grep -RnE '\b(HttpClient|RawSocket|SecureSocket|RawSynchronousSocket|WebSocket|Socket\.connect|HttpServer|XMLHttpRequest)\b' "$FLUTTER_LIB" || true)
  if [ -n "$BAD" ]; then
    fail "G5b network API used in the UI:"; printf '        %s\n' "$BAD"
  else
    pass "G5b no network API in apps/flutter_app/lib"
  fi
else
  skip "G5b UI uses no network API" "no flutter app yet"
fi

# ---------------------------------------------------------------- G4
if grep -q 'unsafe_code = "forbid"' Cargo.toml 2>/dev/null; then
  pass "G4a unsafe_code = forbid in the workspace lints"
else
  fail "G4a workspace lints do not forbid unsafe_code"
fi

if cargo clippy --version >/dev/null 2>&1; then
  if cargo clippy -p z_core --all-targets --quiet -- -D warnings >/tmp/g4.$$ 2>&1; then
    pass "G4b clippy clean on z_core with -D warnings"
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
  pass "G3/G6/G9/G10 cargo test"
else
  fail "cargo test:"; tail -30 /tmp/gt.$$ | sed 's/^/        /'
fi
rm -f /tmp/gt.$$


# ---------------------------------------------------------------- G7 (from Dart)
# The claim "no panic crosses the boundary" is only proven from the other side:
# call the whole contract from Dart and see typed errors come back.
LIB=apps/flutter_app/build/linux/x64/debug/bundle/lib
if [ -f "$LIB/libz_bridge.so" ] && command -v flutter >/dev/null 2>&1; then
  if (cd apps/flutter_app && LD_LIBRARY_PATH="$PWD/build/linux/x64/debug/bundle/lib" flutter test --reporter compact >/tmp/gd.$$ 2>&1); then
    pass "G7-dart the whole contract answers from Dart without a panic"
  else
    fail "G7-dart flutter test:"; tail -20 /tmp/gd.$$ | sed 's/^/        /'
  fi
  rm -f /tmp/gd.$$
else
  skip "G7-dart contract callable from Dart" "run: cd apps/flutter_app && flutter build linux --debug"
fi

# A green run proves nothing unless the four invariant tests actually exist.
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
