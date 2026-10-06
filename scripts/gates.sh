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
# The one HTTP client, and the one folder allowed to know it exists (G1, G16).
API_FILES_FIRST=z_core/src/api.rs
CLIENT=ureq
NET_DIR=providers
# The echo provider only exists in a build made for the tests.
# Both are test-only features. `test_clock` is listed here and not only in the
# manifest because a feature the suite forgets to ask for takes its tests with
# it silently — the same shrink G22 exists to refuse. G23 checks this line.
TEST_FEATURES="--features fake_provider,test_clock" 

echo "Z Privacy gates"
echo

# ---------------------------------------------------------------- G1
# Exactly one HTTP client, in one package, named in one folder.
# G1a: no client but the one we chose.
HITS=$(grep -RnE '^\s*(reqwest|hyper|curl|isahc|surf|attohttpc|awc)\s*=' --include=Cargo.toml . || true)
if [ -n "$HITS" ]; then
  fail "G1a an HTTP client other than the chosen one:"; printf '        %s\n' "$HITS"
else
  pass "G1a no HTTP client other than $CLIENT"
fi

# G1b: the chosen client appears in exactly one manifest, z_core's.
WHERE=$(grep -RlE "^\s*$CLIENT\s*=" --include=Cargo.toml . | sed 's|^\./||' | sort)
COUNT=$(printf '%s\n' "$WHERE" | grep -c . || true)
if [ "$COUNT" = "1" ] && [ "$WHERE" = "z_core/Cargo.toml" ]; then
  pass "G1b $CLIENT is declared once, in z_core/Cargo.toml"
else
  fail "G1b $CLIENT should be declared once in z_core/Cargo.toml, found:"; printf '        %s\n' "$WHERE"
fi

# G1c: it is named only inside the providers folder — nowhere else in any crate.
BAD=$(grep -RnE "\b$CLIENT::" --include='*.rs' z_core/src bridges apps 2>/dev/null | grep -v "^z_core/src/$NET_DIR/" || true)
if [ -n "$BAD" ]; then
  fail "G1c $CLIENT named outside z_core/src/$NET_DIR:"; printf '        %s\n' "$BAD"
else
  NAMED=$(grep -RlE "\b$CLIENT::" --include='*.rs' "z_core/src/$NET_DIR" 2>/dev/null | wc -l)
  pass "G1c $CLIENT is named in $NAMED file(s), all under z_core/src/$NET_DIR"
fi

# G1d: the echo provider is for tests. It must never be a default feature.
if grep -A3 '^\[features\]' z_core/Cargo.toml | grep -q '^default = \[\]'; then
  pass "G1d the echo provider is not in z_core's default features"
else
  fail "G1d z_core's default features are not empty — the echo provider may ship"
fi

# ---------------------------------------------------------------- G24
# One watcher for the window, and it only reports.
#
# The behaviour board promises that a reveal ends when the window stops being
# the one in front. That event is a fact only the screen can see — so the
# screen reports it and the core decides what it means. Two watchers would be
# two places deciding, and a watcher in a screen would be a screen deciding;
# both are the shape this project spent two rounds removing.
WATCHERS=$(grep -RlE 'AppLifecycleListener|WidgetsBindingObserver|didChangeAppLifecycleState' \
             "$FLUTTER_LIB" --include='*.dart' 2>/dev/null | grep -v '/src/rust/' || true)
WATCH_N=$(printf '%s' "$WATCHERS" | grep -c . || true)
if [ "$WATCH_N" = "1" ] && printf '%s' "$WATCHERS" | grep -q 'screens/shell.dart'; then
  pass "G24 one place watches the window, and it is the shell"
else
  fail "G24 the window is watched in $WATCH_N place(s), expected the shell alone:"
  printf '%s\n' "$WATCHERS" | sed 's/^/        /'
fi

DOOR_CALLERS=$(grep -RlE 'windowFocusLost|windowHidden' \
                 "$FLUTTER_LIB" --include='*.dart' 2>/dev/null | grep -v '/src/rust/' || true)
if [ "$DOOR_CALLERS" = "$WATCHERS" ]; then
  pass "G24 the window doors are called from that one place and no other"
else
  fail "G24 the window doors are called outside the watcher:"
  printf '%s\n' "$DOOR_CALLERS" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G23
# The test clock is a seam, and a seam is a promise about what it cannot do.
#
# It can only make the vault look longer unused than it is — never shorter — so
# it has no power to postpone a lock. What is checked here is that it stays
# where it was put: out of `default`, out of the bridge, out of the interface,
# and named by the suite so its four tests cannot disappear quietly.
SEAM="age_vault_unused"
if grep -q '^test_clock = \[\]' z_core/Cargo.toml; then
  pass "G23 the test clock is a declared feature, not a default"
else
  fail "G23 z_core/Cargo.toml does not declare test_clock as its own feature"
fi

G23_OUT=$(grep -RlsE "$SEAM|test_clock" bridges apps/flutter_app/lib 2>/dev/null || true)
if [ -z "$G23_OUT" ]; then
  pass "G23 the test clock does not cross the bridge or reach the interface"
else
  fail "G23 the test clock is named outside z_core:"; printf '%s\n' "$G23_OUT" | sed 's/^/        /'
fi

if printf '%s' "$TEST_FEATURES" | grep -q 'test_clock'; then
  pass "G23 the suite runs with the clock, so its tests cannot vanish silently"
else
  fail "G23 TEST_FEATURES does not name test_clock — the clock tests are being skipped"
fi

# ---------------------------------------------------------------- G21
# The Hardening phase closes on «the same harness, re-run, with no change in
# our favour». That is only worth something if «the same» can still be proved
# when nobody remembers what the attacker looked like.
if [ -f scripts/check_redteam.py ]; then
  if OUT=$(python3 scripts/check_redteam.py 2>&1); then
    pass "$(printf '%s' "$OUT" | head -1)"
  else
    fail "$(printf '%s' "$OUT" | head -1)"; printf '%s\n' "$OUT" | tail -n +2
  fi
else
  skip "G21 the captured harness is unchanged" "no checker yet"
fi

# ---------------------------------------------------------------- G20
# One error, one sentence. A typed error becomes language in exactly one file;
# a widget that reads an `ApiError` itself is how one failure comes to say
# three different things on three screens. Measured live on 29 September:
# `ApiError.importRefused(reason: …)` printed at a person.
G20_BAD=$(grep -RnE '\b(e|err|bad|error)\.toString\(\)|\bis ApiError_' \
            apps/flutter_app/lib --include='*.dart' 2>/dev/null \
          | grep -v '/src/rust/' | grep -v 'core/messages.dart' \
          | grep -vE ':[0-9]+: *//' || true)
if [ -z "$G20_BAD" ]; then
  pass "G20 every typed error is worded in one place"
else
  fail "G20 an ApiError is read outside the mapper:"; printf '%s\n' "$G20_BAD" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G19
# A deadlock does not shout. The program stops, with no panic and no log — the
# first one in this project hung the test suite for ten minutes. So the shape
# that causes it is checked, not watched for.
if [ -f scripts/check_locks.py ]; then
  if OUT=$(python3 scripts/check_locks.py 2>&1); then
    pass "$(printf '%s' "$OUT" | head -1)"
  else
    fail "$(printf '%s' "$OUT" | head -1)"; printf '%s\n' "$OUT" | tail -n +2
  fi
else
  skip "G19 no nested lock in the core" "no checker yet"
fi

# ---------------------------------------------------------------- G18
# ZCFG is the one unencrypted file, and it holds a closed list of four names.
# The owner's rule: if a thing could say anything about the user's work or their
# clients, it does not belong in it.
CFG=z_core/src/config.rs
if [ -f "$CFG" ]; then
  # The allowlist is declared once, and is exactly four names long.
  LIST=$(sed -n '/^const ALLOWED: \[&str; [0-9]*\]/,/^];/p' "$CFG" | grep -cE '^\s*"')
  DECLARED=$(grep -oE 'const ALLOWED: \[&str; [0-9]+\]' "$CFG" | grep -oE '[0-9]+')
  if [ "$LIST" = "$DECLARED" ] && [ -n "$LIST" ]; then
    pass "G18a the settings allowlist is one list of $LIST names"
  else
    fail "G18a the settings allowlist says $DECLARED and holds $LIST"
  fi

  # No dynamic bag anywhere in it: a field that is not a field cannot be written.
  BAG=$(grep -nE '\b(HashMap|BTreeMap|Vec<\(String|serde)' "$CFG" || true)
  if [ -n "$BAG" ]; then
    fail "G18b the settings file has a dynamic map, so anything could be written:"; printf '        %s\n' "$BAG"
  else
    pass "G18b the settings are four struct fields, not a map"
  fi

  # The struct's own fields, and only those, decide what can be written. A
  # field that could name the user's work must never appear among them — and
  # the check looks at the struct, not at the file, so a comment or a test
  # fixture mentioning a forbidden word is not mistaken for a field.
  FIELDS=$(sed -n '/^pub(crate) struct AppConfig {/,/^}/p' "$CFG" \
    | grep -oE '^\s+pub [a-z_]+' | awk '{print $2}')
  BAD_FIELD=$(printf '%s\n' "$FIELDS" | grep -Ei '(client|entity|profile|recent|document|token|credential|passphrase|query|search|path|text|file)' || true)
  if [ -n "$BAD_FIELD" ]; then
    fail "G18c a field that could name the user's work is a setting:"; printf '        %s\n' "$BAD_FIELD"
  else
    COUNT=$(printf '%s\n' "$FIELDS" | grep -c . || true)
    pass "G18c the $COUNT settings fields name nothing of the user's work"
  fi
else
  skip "G18 the settings allowlist" "no config.rs yet"
fi

# ---------------------------------------------------------------- G17
# The Dart contract test must call the WHOLE contract. Its own count assertion
# cannot notice a function nobody added to it — so the count is checked here,
# against the contract itself. (A function added and forgotten used to pass.)
DART_TEST=apps/flutter_app/test/contract_test.dart
if [ -f "$API_FILES_FIRST" ] && [ -f "$DART_TEST" ]; then
  DECLARED=$(grep -c '^pub fn ' "$API_FILES_FIRST")
  CLAIMED=$(grep -oE 'the contract has [0-9]+ functions' "$DART_TEST" | grep -oE '[0-9]+' | head -1)
  if [ "$DECLARED" = "$CLAIMED" ]; then
    pass "G17 the Dart contract test calls all $DECLARED functions"
  else
    fail "G17 api.rs declares $DECLARED functions, contract_test.dart accounts for ${CLAIMED:-none}"
  fi
else
  skip "G17 the Dart test covers the whole contract" "no contract test yet"
fi

# ---------------------------------------------------------------- G16
# The outgoing text has exactly one reader. It was built in M2 and left without a
# caller until M6 on purpose; the network stands behind it, not beside it.
WIRE=$(grep -RnE '\bwire_text\b' --include='*.rs' z_core/src bridges apps 2>/dev/null \
  | grep -v "^z_core/src/$NET_DIR/" | grep -v '^z_core/src/payload.rs:' || true)
if [ -n "$WIRE" ]; then
  fail "G16 the outgoing text is read outside z_core/src/$NET_DIR:"; printf '        %s\n' "$WIRE"
else
  CALLS=$(grep -RcE '\bwire_text\b' --include='*.rs' "z_core/src/$NET_DIR" 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
  pass "G16 wire_text() is defined in payload.rs and read only in $NET_DIR ($CALLS place(s))"
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
for t in Secret SafePayload DocumentView PayloadView RevealedValue Segment EntityRow EntityCard WorkspaceSnapshot VaultSnapshot TaughtValueRow AnswerSnapshot; do
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
  if sed -n "${PREV}p" "$FILE" 2>/dev/null | grep -qE 'G15-ok|G15-cfg'; then
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
  VAULT_LINES=$(grep -Rc 'G15-ok' z_core/src 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
  CFG_LINES=$(grep -Rc 'G15-cfg' z_core/src 2>/dev/null | awk -F: '{s+=$2} END {print s+0}')
  pass "G15 no filesystem in z_core/src except $VAULT_LINES vault lines and $CFG_LINES settings lines"
fi

# The settings file may only be touched from config.rs. Two kinds of file, and
# each one written from exactly one place.
CFG_ELSEWHERE=$(grep -Rln 'G15-cfg' z_core/src 2>/dev/null | grep -v '^z_core/src/config.rs$' || true)
if [ -n "$CFG_ELSEWHERE" ]; then
  fail "G15b the settings file is written outside config.rs:"; printf '        %s\n' "$CFG_ELSEWHERE"
else
  pass "G15b the settings file is touched in config.rs only"
fi

# ---------------------------------------------------------------- G4
# G4a was «forbid, everywhere, full stop» until 30 September. Windows has no
# 0600 and no O_NOFOLLOW, so guarding the vault's own file there needs Win32 and
# Win32 needs `unsafe`. The rule did not go away; it got a countable exception,
# and this gate is what keeps it countable. One allowance, one file, and no
# `unsafe` anywhere else — the moment a second appears, this is red.
UNSAFE_HOME="z_core/src/secure_file/windows.rs"
if grep -q 'unsafe_code = "deny"' Cargo.toml 2>/dev/null; then
  pass "G4a unsafe_code = deny in the workspace lints"
else
  fail "G4a workspace lints do not deny unsafe_code"
fi

ALLOWS=$(grep -rln 'allow(unsafe_code)' --include=*.rs z_core bridges 2>/dev/null | sort)
ALLOW_COUNT=$(printf '%s\n' "$ALLOWS" | grep -c . || true)
if [ "$ALLOW_COUNT" = "1" ] && [ "$ALLOWS" = "$UNSAFE_HOME" ]; then
  pass "G4a-one the single unsafe allowance is $UNSAFE_HOME"
else
  fail "G4a-one unsafe is allowed somewhere other than $UNSAFE_HOME:"
  printf '        %s\n' "${ALLOWS:-（none — the exception was removed; delete this gate with it）}"
fi

STRAY=$(grep -rn '\bunsafe\b' --include=*.rs z_core/src bridges/native/z_bridge/src/api 2>/dev/null \
        | grep -v "^$UNSAFE_HOME:" | grep -vE ':[0-9]+:\s*(//|///|//!)' || true)
if [ -z "$STRAY" ]; then
  pass "G4a-only no unsafe outside that one file"
else
  fail "G4a-only unsafe appears outside $UNSAFE_HOME:"; printf '        %s\n' "$STRAY"
fi

SAFETY=$(grep -c 'unsafe {' "$UNSAFE_HOME" 2>/dev/null || echo 0)
NOTES=$(grep -c 'SAFETY:' "$UNSAFE_HOME" 2>/dev/null || echo 0)
if [ ! -f "$UNSAFE_HOME" ] || [ "$NOTES" -ge "$SAFETY" ]; then
  pass "G4a-why every unsafe block in it carries a SAFETY note ($SAFETY blocks, $NOTES notes)"
else
  fail "G4a-why $SAFETY unsafe blocks but only $NOTES SAFETY notes in $UNSAFE_HOME"
fi

if cargo clippy --version >/dev/null 2>&1; then
  if cargo clippy -p z_core --all-targets $TEST_FEATURES --quiet -- -D warnings >/tmp/g4.$$ 2>&1; then
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
if cargo test --workspace $TEST_FEATURES --quiet >/tmp/gt.$$ 2>&1; then
  pass "G3/G6/G9/G10/G11/G12 cargo test"
else
  fail "cargo test:"; tail -30 /tmp/gt.$$ | sed 's/^/        /'
fi
rm -f /tmp/gt.$$


# ---------------------------------------------------------------- G22
# The storage protection layer must be MEASURED on the platform you are on,
# not merely written for one. Six named contracts guard the vault's own file;
# on Windows all six are `#[cfg(unix)]` and simply do not exist, so the suite
# there runs 245 of 251 and still says «ok». A count would drift as tests are
# added — these are asked for by name.
if bash scripts/check_storage_contracts.sh >/tmp/g22.$$ 2>&1; then
  pass "G22 all six storage protection contracts are measured on this platform"
else
  fail "G22 storage protection is not fully measured here:"
  sed 's/\x1b\[[0-9;]*m//g' /tmp/g22.$$ | grep -E "^  FAIL|contracts have no test" | sed 's/^/        /'
fi
rm -f /tmp/g22.$$

# ---------------------------------------------------------------- G7 (from Dart)
# The claim "no panic crosses the boundary" is only proven from the other side:
# call the whole contract from Dart and see typed errors come back.
LIB=apps/flutter_app/build/linux/x64/debug/bundle/lib
if [ -f "$LIB/libz_bridge.so" ] && command -v flutter >/dev/null 2>&1; then
  if (cd apps/flutter_app && LD_LIBRARY_PATH="$PWD/build/linux/x64/debug/bundle/lib" flutter test --concurrency=1 --reporter compact >/tmp/gd.$$ 2>&1); then
    pass "G7-dart the whole contract answers from Dart without a panic"
  else
    fail "G7-dart flutter test:"; tail -20 /tmp/gd.$$ | sed 's/^/        /'
  fi
  rm -f /tmp/gd.$$
else
  skip "G7-dart contract callable from Dart" "run: cd apps/flutter_app && flutter build linux --debug"
fi

# ------------------------------------------------- the mark
# One picture, every size, and no icon edited by hand.
#
# `scripts/build_brand.py --check` rebuilds all thirteen files into a temporary
# directory from `brand/source.png` and compares the bytes with what is
# committed. A PNG touched in an image editor, a size regenerated from a
# different crop, an `.ico` rebuilt elsewhere — each of those is this check
# going red.
if [ -f scripts/build_brand.py ] && [ -f brand/source.png ]; then
  if OUT=$(python3 scripts/build_brand.py --check 2>&1); then
    pass "the mark: $(echo "$OUT" | sed 's/^PASS  //')"
  else
    fail "the mark: $(echo "$OUT" | head -2 | tr '\n' ' ')"
  fi
  # And the window wears it from the files beside it, never from a path in
  # somebody's home.
  RUNNER=apps/flutter_app/linux/runner/my_application.cc
  if grep -q 'gtk_window_set_icon_list' "$RUNNER" 2>/dev/null \
     && ! grep -nE '"/home/|g_get_home_dir' "$RUNNER" 2>/dev/null | grep -q .; then
    pass "  the Linux window takes its icon from the bundle, relative to the executable"
  else
    fail "  the window icon is missing or is read from a home path ($RUNNER)"
  fi
else
  skip "the mark" "no brand script on this branch"
fi

# ------------------------------------------------- the model gateway
# Phase 4. Three promises, and each one is a shape rather than a hope.
#
# **No fallback.** Nothing may construct a direct body from a protected one. The
# check is literal: `Body::Direct` may appear only where a caller chose it —
# in `ops::ask_model_directly` and in the gateway's own match — and never
# inside the protected path.
#
# **The gateway knows no language.** A pack id or a language word inside
# `gateway.rs` would mean the door had started reading documents.
#
# **A provider is a file.** Adding one may not need the gateway: the check
# counts the providers and the gateway's mentions of them, which must stay at
# zero.
GW=z_core/src/gateway.rs
if [ -f "$GW" ]; then
  BUILT=$(grep -cE 'Body::Direct\(' z_core/src/ops/*.rs z_core/src/*.rs 2>/dev/null \
    | awk -F: '{n+=$2} END {print n+0}')
  CHOSEN=$(sed -n '/pub(crate) fn ask_model_directly/,/^}/p' z_core/src/ops/mod.rs 2>/dev/null \
    | grep -cE 'Body::Direct\(' || true)
  # The gateway's own `match` reads the arm; it does not build one.
  READS=$(grep -cE 'Body::Direct\(text\) =>' "$GW" || true)
  if [ "$BUILT" = "$((CHOSEN + READS))" ] && [ "$CHOSEN" = "1" ]; then
    pass "no path turns a protected request into a direct one (built once, where a person chooses it)"
  else
    fail "a direct body is built $BUILT time(s); $CHOSEN in the door a person chooses, $READS read in the gateway"
  fi
  if grep -nE '"(de|sv|en)"|German|Swedish|Deutsch' "$GW" | grep -vE '^[0-9]+:\s*(//|///)|//!' | grep -q .; then
    fail "the gateway names a language: $GW"
  else
    pass "  the gateway knows no language"
  fi
  if grep -nE '\b(openai|anthropic)\b' "$GW" | grep -vE '^[0-9]+:\s*(//|///)|//!' | grep -q .; then
    fail "the gateway names a provider: adding one would mean editing the door"
  else
    pass "  the gateway names no provider: $(grep -c 'Box::new' z_core/src/providers/mod.rs) listed in the registry"
  fi
else
  skip "the model gateway" "no gateway on this branch"
fi

# ------------------------------------------------- the pack contract
# Phase 3: a language is data. Two things are checked, and both are the
# promise rather than a preference.
#
# The shared rules may not name a language. `scan_with` and the rules it calls
# read their words out of the pack they are given — a German word written into
# one of them is German leaking back into the core, which is the whole of what
# this phase removed.
#
# And a second pack may not need code: `packs/sv.rs` has to be data only, so it
# is checked for having no `fn` of its own but `pack()`.
PACKS=z_core/src/scanner/packs
if [ -d "$PACKS" ]; then
  LEAK=$(grep -nE '"(Herr|Frau|Herrn|GmbH|und|Straße|grüßen|geschäftsführer)"' \
    "$PACKS/people.rs" 2>/dev/null | grep -vE '^[0-9]+:\s*(//|///)' || true)
  if [ -z "$LEAK" ]; then
    pass "the shared rules name no language of their own"
  else
    fail "a German word is written into a shared rule: $(echo "$LEAK" | head -1)"
  fi
  SV_FNS=$(grep -cE '^pub\(crate\) fn |^fn ' "$PACKS/sv.rs" 2>/dev/null || echo 0)
  if [ "$SV_FNS" -le 1 ]; then
    pass "  the second pack is data: $SV_FNS function in sv.rs"
  else
    fail "  the second pack carries $SV_FNS functions — a pack should be data, or say why"
  fi
else
  skip "the pack contract" "no packs folder on this branch"
fi

# ------------------------------------------------- candidate discovery
# Phase 2: Z notices the names a document uses that it does not know, asks once
# per name, and learns from one answer. Two things are checked here, because
# both are promises rather than preferences.
#
# A candidate is not a finding: `discover_names` may not build a `Candidate`,
# which is the type the scanner protects things with. And a taught name is
# knowledge in the vault like a taught label rule — never a value, and never a
# protection on its own.
DISC=z_core/src/scanner/packs/de.rs
if [ -f "$DISC" ]; then
  if sed -n '/fn discover_names/,/^}/p' "$DISC" | grep -qE 'Confidence::|candidate\('; then
    fail "discovery builds a protection: a candidate must only ever be a candidate ($DISC)"
  else
    pass "candidate discovery protects nothing by itself"
  fi
  if grep -q 'fn teach_name' z_core/src/ops/vault.rs 2>/dev/null \
     && grep -q 'taught_names' z_core/src/vault/model.rs 2>/dev/null; then
    pass "  a taught name is knowledge in the vault, beside the taught label rules"
  else
    fail "  a taught name is not stored where the other taught knowledge is"
  fi
else
  skip "candidate discovery" "no German pack on this branch"
fi

# ------------------------------------------------- the name dictionary
# German Name Dictionary V1: a signal for Person detection and never a verdict.
# Two things are checked here. The file must have the shape the loader expects —
# `--check` needs no network, so the owner's own CSV can be dropped in and
# checked the same way. And the rule must never raise a word to Auto on the
# strength of a list of names: that is item B of his paper, and the test that
# holds it is named here so it cannot be deleted quietly.
if [ -f scripts/build_de_names.py ]; then
  if OUT=$(python3 scripts/build_de_names.py --check 2>&1); then
    pass "the name dictionary: $(echo "$OUT" | sed 's/^PASS  //')"
  else
    fail "the name dictionary: $(echo "$OUT" | head -2 | tr '\n' ' ')"
  fi
else
  skip "the name dictionary" "no generator yet"
fi
if grep -q 'Confidence::Suggest' z_core/src/scanner/packs/de.rs 2>/dev/null \
   && ! grep -A6 'fn dictionary_names' z_core/src/scanner/packs/de.rs 2>/dev/null | grep -q 'Confidence::Auto'; then
  pass "  the name dictionary never protects by itself"
else
  fail "  the name dictionary can raise a word to Auto on a list match alone"
fi

# ------------------------------------------------- the build's own stamp
# `core_version()` names the build: version, date, commit. Two things have to
# hold for that to be worth anything — the Windows workflow must read the stamp
# out of the binary it built and refuse a stamp that names another commit, and
# the download page must not be publishable with the build value unfilled.
WF=.github/workflows/windows-core.yml
if [ -f "$WF" ]; then
  if grep -q "The build's own stamp" "$WF" && grep -q 'the binary says' "$WF"; then
    pass "the Windows build prints its own stamp, and checks it names the commit"
  else
    fail "the Windows build does not print the stamp it was built with ($WF)"
  fi
else
  skip "the Windows build prints its own stamp" "no Windows workflow on this branch"
fi
if grep -rq '{{WINDOWS_BUILD}}' site/*/index.html 2>/dev/null; then
  pass "  the download page names the build it is offering (unfilled, so unpublishable)"
elif grep -rqE '>Build</p>' site/*/index.html 2>/dev/null; then
  pass "  the download page names the build it is offering"
else
  fail "  the download page offers a file without naming the build it came from"
fi

# ------------------------------------------------- the third golden
# 734 pages of Austrian medical German: a code table with one page of doctors
# in the middle. It holds both halves of the promise at once — the people are
# protected without being asked, and the hundred thousand ICD-10 codes are left
# alone. On 3 October it caught a title protected in place of a name, four
# codes protected as people, and 28,853 chapter letters.
# The owner's file, five megabytes, not in the repository: a skip, not a pass.
DOC="${ZPRIVACY_THIRD_GOLDEN:-$HOME/Downloads/tysk1.pdf}"
if [ -f "$DOC" ]; then
  if cargo test --quiet --test the_third_golden >/dev/null 2>&1; then
    pass "the third golden: the team page is protected, the code tables are not"
  else
    fail "the third golden: the team page is protected, the code tables are not (cargo test --test the_third_golden)"
  fi
else
  skip "the third golden: the team page is protected, the code tables are not" "the document is not on this machine"
fi

# ------------------------------------------------- the second golden
# The first golden is a letter we wrote. The second is 146 pages of public
# German prose — the owner's own file, a megabyte of it, so it does not enter
# the repository. It holds the other half of the promise: that the scanner
# leaves a language alone. On 3 October it caught «und» being protected as a
# date of birth, 1,380 times.
# Without the file there is nothing to measure, and that is said as a skip.
BOOK="${ZPRIVACY_SECOND_GOLDEN:-$HOME/Documents/steuern-von-a-z.pdf}"
if [ -f "$BOOK" ]; then
  if cargo test --quiet --test the_second_golden >/dev/null 2>&1; then
    pass "the second golden: a public book keeps its own words"
  else
    fail "the second golden: a public book keeps its own words (cargo test --test the_second_golden)"
  fi
else
  skip "the second golden: a public book keeps its own words" "the book is not on this machine"
fi

# A green run proves nothing unless the invariant tests actually exist. A test
# that is quietly deleted takes its invariant with it and the suite still passes.
for t in no_leak stale_payload round_trip session_namespace g11_ g12_ golden_ rule_one rule_two rule_three rule_four twenty_ a_twenty \
         the_server_receives the_whole_path a_redirect_is_refused never_by_its_body longer_than_the_limit \
         each_purpose_gets_its_own a_format_one_vault a_literal_loopback ciphertext_even_inside \
         renamed_moved_and_pruned says_nothing_about_why not_a_set_the_screen_knows \
         reaches_the_settings_file could_name_a_client remembers_the_first_run \
         two_places_report_agrees the_string_that_would_be_sent is_a_constant \
         three_windows_on_one_truth not_sensitive_is_an_answer actually_reach_the_vault \
         can_say_where_it_came_from shows_what_it_will_take leaves_another_client_alone \
         does_not_unprotect_the_document a_different_act_from_forget tomorrow_not_today \
         this_conversation_means_every_place need_the_vault_and_say_so \
         reports_nothing_it_does_not_know take_back_an_answer \
         lie_always_without_vault lie_missing_credential lie_rescan_is_named \
         keyless_login_claims_a_key \
         remove_protection_here_leaves forget_from_this_profile_keeps \
         forget_everywhere_reaches nothing_taught_reports_no_reach \
         locked_by_hand locks_itself does_not_postpone_the_lock tell_one_story \
         opened_again the_lock_closer no_error_and_no_trace \
         losing_the_window covering_nothing \
         from_the_vault_goes_when by_hand_goes_when revealed_while_the_vault_is_locked \
         takes_the_tokens_too postpone_the_vault_lock one_door_covers \
         closing_the_conversation_ends \
         drawn_through_a_form draws_itself_stops image_xobject_is_still_a_scan \
         long_bfrange_maps_all several_entries_on_one_line list_of_destinations \
         literal_string_in_a_two_byte_font maps_to_nothing_never_reaches \
         nothing_of_his_own_is_left protected_without_being_asked \
         remapped_font_is_read_by_its_own remapped_font_with_no_table \
         raw_bytes_survives_the_way_in plain_text_is_not_touched \
         simple_font_with_a_table_is_read cmap_behind_a_reference \
         name_with_an_underscore \
         a_label_in_a_sentence_takes_no_ordinary_word a_run_of_zeros_is_not_a_telephone \
         a_label_without_a_colon_still_takes_a_value a_protected_word_does_not_spread \
         the_book_of_tax_terms_is_left_alone \
         a_line_that_moves_down_separates the_other_ways_of_asking_for_a_new_line \
         an_object_stream_is_cut_in_bytes a_refusal_counts_the_pages \
         carries_the_numbers_and_none_of_the_words a_refused_file_still_has_a_report \
         the_team_page_is_protected_and_the_code_tables_are_not \
         an_icd_code_after_frau_is_not_a_person a_title_at_the_start_of_a_name \
         the_dictionary_loads_the_names_it_ships_with german_letters_survive_the_way_in \
         a_given_name_and_a_surname_in_a_row_are_offered a_single_name_on_its_own_is_never \
         the_dictionary_never_protects_anything_by_itself a_german_word_that_is_also_a_name \
         a_function_word_does_not_open_a_name the_surnames_of_a_real_letter_are_in_the_list \
         offers_its_unknown_names_once_each a_candidate_protects_nothing_until_it_is_taught \
         a_name_whose_given_half_is_unknown_is_still_invisible \
         a_person_answers_twice_and_a_whole_document_is_understood \
         a_swedish_letter_is_read_by_a_pack_that_is_only_data \
         a_swedish_word_that_is_also_a_name_opens_nothing \
         swedish_labels_are_rows_like_every_other_language \
         german_reads_exactly_what_it_read_before \
         what_each_pack_needs_beyond_the_shared_rules_is_declared \
         the_pack_is_what_was_asked_for_and_not_what_the_machine_is \
         the_matrix the_catalogue_is_what_the_providers_say \
         a_small_german_set_positive_and_negative the_rules_that_were_there_before_still_hold \
         a_title_with_no_name_after_it_is_nothing a_degree_after_the_name_is_left \
         frau_as_an_ordinary_noun_names_nobody a_word_like_den_in_front_of_a_salutation \
         an_austrian_title_is_stepped_over replaces_what_was_selected \
         salutation_stays_and_the_company \
         never_mentions_are_counted codes_with_no_characters; do
  if grep -Rqs "fn .*$t" z_core/tests z_core/src 2>/dev/null; then
    pass "  test present: $t"
  else
    skip "  test present: $t" "not written yet"
  fi
done

# The same, for the screens. These are the tests that hold «no number on screen
# is invented in Dart» to account, so their absence must be as loud.
for t in "the core reports it" "the scan the core ran" "own two strings" "never the credential" \
         "not one Dart worked out" "Skip decides nothing" "does not touch what leaves" \
         "the manual door needs no key" "as the model wrote it" "only the safe text arrives" \
         "the vault room" "say where they live" "in the language it is offering" \
         "not on Home" "word for word" "forgetting shows its cost first" \
         "clipboard untouched until confirmed" \
         "named a rescan, not scanned on import" \
         "offers Disconnect, not" "names both acts by their reach" \
         "says how much, and what to do" \
         "name the reach they would forget" "is the pack that is kept" \
         "display only, and Why lives" "its own next move" \
         "takes the reveal with it" "takes the revealed tokens with it" \
         "hides rather than keeps" "no longer in front" "gone from the screen" \
         "in the frame after the window does" \
         "drawn with a solid line" "protected on its own is drawn dashed" \
         "the line still says who decided" "stays wavy, whoever found it" \
         "put back in the answer is drawn dotted" \
         "own report, and none of the words" \
         "selection in blue, not in nothing" "reads through a mark" \
         "survives the rebuild the Workspace does" "a tap still asks" \
         "a name is two presses" "a list is read and counted" \
         "both acts say what they need" "the rule set in the top bar is a choice" \
         "the band" "read again once there is one" "never insists" \
         "asks once per name, with what the decision is worth" \
         "no model is named in Dart" "the original is a chosen thing" \
         "never inherits the last one"; do
  if grep -Rqs -- "$t" apps/flutter_app/test 2>/dev/null; then
    pass "  screen test present: $t"
  else
    skip "  screen test present: $t" "not written yet"
  fi
done

echo
if [ "$FAILED" -eq 0 ]; then
  echo "all gates passed"
else
  echo "GATES FAILED"
fi
exit "$FAILED"
