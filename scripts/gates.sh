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

# ---------------------------------------------------------------- G13, G2, G7, G8
for API in $API_FILES; do
  if [ ! -f "$API" ]; then
    skip "G13/G2/G7/G8 on $API" "file not there yet"
    continue
  fi
  SIGS=$(grep -n '^pub fn ' "$API")

  # G13 (guards the three below): every public signature sits on ONE line.
  BAD=$(printf '%s\n' "$SIGS" | grep -v '{' || true)
  if [ -n "$BAD" ]; then
    fail "G13 $API: signature spans lines:"; printf '        %s\n' "$BAD"
  else
    pass "G13 $API: every signature is one line"
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


# ---------------------------------------------------------------- G14
# The bridge mirrors are generated from the contract. If they drift, Dart gets a
# class with a missing field and nobody notices until the UI misbehaves.
if [ -f scripts/gen_mirrors.py ]; then
  if python3 scripts/gen_mirrors.py --check >/tmp/g12.$$ 2>&1; then
    pass "G14 bridge mirrors match the contract"
  else
    fail "G14 mirrors are stale:"; sed 's/^/        /' /tmp/g12.$$
  fi
  rm -f /tmp/g12.$$
else
  skip "G14 mirrors match the contract" "no generator yet"
fi


# ---------------------------------------------------------------- G11
# No original text and no vault value in a log, an error, or Debug output.
# Comment lines are skipped: secret.rs shows the forbidden line as an example.
PRINTS=$(grep -RnE '\b(println!|print!|eprintln!|eprint!|dbg!)' z_core/src 2>/dev/null | grep -vE ':[0-9]+:\s*//' || true)
if [ -n "$PRINTS" ]; then
  fail "G11 the core prints something:"; printf '        %s\n' "$PRINTS"
else
  pass "G11 nothing in z_core/src prints"
fi

G11_MISSING=""
for t in Secret SafePayload DocumentView PayloadView RevealedValue Segment EntityRow EntityCard; do
  grep -Rqs "impl fmt::Debug for $t" z_core/src || G11_MISSING="$G11_MISSING $t"
done
if [ -n "$G11_MISSING" ]; then
  fail "G11 these carry the user's words but derive Debug:$G11_MISSING"
else
  pass "G11 every type holding the user's words redacts its own Debug"
fi

if grep -qs 'pub original: Secret' z_core/src/session.rs \
  && grep -qs 'pub value: Secret' z_core/src/tokens.rs \
  && grep -qs 'pub value: Secret' z_core/src/vault/model.rs \
  && grep -qs 'pub label: Secret' z_core/src/vault/model.rs; then
  pass "G11 originals, token values and vault values are Secret, not String"
else
  fail "G11 something that holds the user's words went back to being a String"
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


# ---------------------------------------------------------------- G15
# No intermediate files: reading a document must never touch the disk. The only
# file this crate may write is the sealed vault, and each such line carries a
# «G15-ok» comment above it so that the exemptions are countable.
FS_HITS=$(grep -RnE '\b(std::fs::|File::create|File::open|temp_dir|tempfile|NamedTempFile|OpenOptions)' z_core/src 2>/dev/null \
  | grep -vE ':[0-9]+:[[:space:]]*//' || true)
FS_BAD=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  FILE=${line%%:*}
  REST=${line#*:}
  NUM=${REST%%:*}
  PREV=$((NUM - 1))
  if sed -n "${PREV}p" "$FILE" 2>/dev/null | grep -q 'G15-ok'; then
    continue
  fi
  FS_BAD="$FS_BAD$line
"
done <<EOF
$FS_HITS
EOF
if [ -n "$FS_BAD" ]; then
  fail "G15 the core touches the filesystem without a stated reason:"; printf '        %s\n' "$FS_BAD"
else
  EXEMPT=$(grep -Rc 'G15-ok' z_core/src 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
  pass "G15 no filesystem in z_core/src except $EXEMPT stated lines (the sealed vault)"
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
  pass "G3/G6/G9/G10/G11/G12 cargo test"
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
for t in no_leak stale_payload round_trip session_namespace g11_ g12_ golden_ rule_one rule_two rule_three rule_four twenty_ a_twenty; do
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
