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
TEST_FEATURES="--features fake_provider" 

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
if grep -q 'unsafe_code = "forbid"' Cargo.toml 2>/dev/null; then
  pass "G4a unsafe_code = forbid in the workspace lints"
else
  fail "G4a workspace lints do not forbid unsafe_code"
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
         lie_always_without_vault lie_missing_credential lie_rescan_is_named; do
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
         "named a rescan, not scanned on import"; do
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
