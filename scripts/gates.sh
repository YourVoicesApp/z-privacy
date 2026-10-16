#!/usr/bin/env bash
# Z Privacy — the gates. Each one fails the build; none is reviewed by eye.
# Run from anywhere:  ./scripts/gates.sh
# Exit status is the verdict: 0 = all gates pass.
#
# What each gate defends is written in docs/SECURITY_INVARIANTS.md.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

FAILED=0
# The script counts its own checks. Both seats counted them with `grep -c` until
# 10 Oct, and both got it wrong the same night: a `----` line quoted *inside* a
# failure's output was counted as a skip. The verdict of a run belongs to the run,
# not to the arithmetic of whoever is reading it.
CHECKS=0
FAILS=0
SKIPS=0
pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; CHECKS=$((CHECKS + 1)); }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILED=1; CHECKS=$((CHECKS + 1)); FAILS=$((FAILS + 1)); }
skip() { printf '  ----  %s (skipped: %s)\n' "$1" "$2"; CHECKS=$((CHECKS + 1)); SKIPS=$((SKIPS + 1)); }

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
# All three are test-only features, and none is in `default`. They are listed
# here and not only in the manifest because a feature the suite forgets to ask
# for takes its tests with it silently — the same shrink G22 exists to refuse.
# G23 checks this line for the clock.
#
# `measuring` joined on 14 Oct, by the lead's ruling, and it buys two things a
# feature-gated instrument otherwise loses: the guard that proves the door
# forwards the product's own word search is **run**, and `--all-targets` lints
# `examples/what_arrives.rs` at all — without the feature cargo skips that
# target and does not compile that test, so both went quietly missing. «A guard that is
# not run is not a guard, and an instrument nobody checks goes on printing
# numbers after it has stopped being right» — and those numbers are what the
# owner will judge Arabic by. The cost is building the instrument on every gate
# run, which is the cheaper half of the trade.
TEST_FEATURES="--features fake_provider,test_clock,measuring" 

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

# ---------------------------------------------------------------- G27
# **One rule decides which language reads a text** — 080.
#
# The owner, 13 Oct 2026, from his own run: a German PDF dragged in gave 7
# findings; the same text pasted into the chat gave 0. The two doors read the
# same words with two different languages — the file door asked the session,
# the chat door read `config.packId` and never looked at a session at all. One
# rule written at one door and never applied to its sibling, which is this
# project's most expensive trap.
#
# So: the app's language is read in exactly one function, every other surface
# asks that function, and both doors take the language of the next text from
# one place. A second reader of the config's pack is how this defect was built.
G27_READS=$(grep -Rn "config?\.packId\|config!\.packId" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
            | grep -v '/src/rust/' | grep -vE ':[0-9]+: *//' || true)
G27_N=$(printf '%s\n' "$G27_READS" | grep -c . || true)
if [ "$G27_N" = "1" ] && printf '%s' "$G27_READS" | grep -q 'core/session_state.dart'; then
  pass "G27 the app's language is read in one place, and it is the ground's own function"
else
  fail "G27 the config's pack is read in $G27_N place(s), expected one in core/session_state.dart:"
  printf '%s\n' "$G27_READS" | sed 's/^/        /'
fi

# And both doors ask one function for the language of the next text.
G27_DOORS=$(grep -n 'packForTheNextText' "$FLUTTER_LIB/screens/shell.dart" 2>/dev/null || true)
if [ "$(printf '%s\n' "$G27_DOORS" | grep -c .)" -ge 2 ]; then
  pass "G27 the chat door and the file door take their language from one function"
else
  fail "G27 only $(printf '%s\n' "$G27_DOORS" | grep -c .) door(s) in shell.dart ask packForTheNextText — the other one decides for itself"
fi

# ---------------------------------------------------------------- G30
# **The shared half of a pack names no language of its own** — the detection
# round of 14 October, item 2.
#
# `packs/people.rs` holds the rules every language is read with, and its own
# first line says that not one word in it is German, Swedish or English. Three
# of its reasons had «German» typed into them, so a Swedish letter was told
# that «AB» is a German legal form and that its people stand in the German name
# dictionary — and an English one that «Ltd» is German. The word now comes from
# the pack (`in_english`), like every other word these rules use.
#
# Comments may name a language: they explain where a rule came from, and a
# measurement in a comment that cannot name German would be a comment that
# cannot be read. What may not name one is the code — a reason a person reads.
SHARED=z_core/src/scanner/packs/people.rs
G30_BAD=$(grep -nE '(German|Swedish|English)' "$SHARED" 2>/dev/null \
          | grep -vE '^[0-9]+:[[:space:]]*(//|/\*|\*)' || true)
if [ -z "$G30_BAD" ]; then
  pass "G30 the shared pack rules name no language in their code — the pack does"
else
  fail "G30 a language is named in the shared rules themselves:"
  printf '%s\n' "$G30_BAD" | sed 's/^/        /'
fi

# And every pack carries that word, or the reasons would say «» about a
# document somebody is reading right now.
G30_PACKS=""
for pack in de sv en; do
  if ! grep -q 'in_english:' "z_core/src/scanner/packs/$pack.rs" 2>/dev/null; then
    G30_PACKS="$G30_PACKS $pack"
  fi
done
if [ -z "$G30_PACKS" ]; then
  pass "G30 every pack says what its language is called in English"
else
  fail "G30 a pack does not name its own language:$G30_PACKS"
fi

# ---------------------------------------------------------------- G31
# **A token is not a candidate** — 079 rule 5, and the question the lead asked
# the hour after the import began scanning: can the scanner protect text that
# is already a token?
#
# It could. Measured on a German answer carrying five tokens: the `E-Mail:`
# label protected one outright and minted a second token over it — so what left
# the machine no longer carried the identifier the other session can resolve,
# and restoring would have handed back a token instead of an address — and a
# person was asked, about a token, whether it is a person.
#
# The law is one line in the scanner, after every layer and before they settle,
# because it is about the text and not about any one rule. The shape test is
# `is_token`, in `tokens.rs`, and there is one of it.
#
# **Three seats on 14 Oct, each named, and a fourth is a red.** 079's import
# side gave the same question two more askers, and they are different acts over
# one fact rather than one act written three times:
#
#   * `scanner/mod.rs` — a token is not a candidate (item 5);
#   * `ops/mod.rs` — a **hand** may not protect one, in the one function the
#     three protect doors ask, and the one that stops the press being offered;
#   * `returning.rs` — where the tokens of a returning document stand, which is
#     the whole of reading one back.
#
# Named rather than counted so that a fourth asker has to say which of these it
# is — the loosening this gate exists to make visible.
SCANNER=z_core/src/scanner/mod.rs
TOKENS=z_core/src/tokens.rs
G31_SEATS="scanner/mod.rs ops/mod.rs returning.rs"
G31_CALLS=$(grep -Rn 'token_spans(' z_core/src --include='*.rs' | grep -v 'fn token_spans' || true)
G31_N=$(printf '%s\n' "$G31_CALLS" | grep -c . || true)
G31_BAD=""
for seat in $G31_SEATS; do
  HOW_MANY=$(printf '%s\n' "$G31_CALLS" | grep -c "$seat:" || true)
  [ "$HOW_MANY" = "1" ] || G31_BAD="$G31_BAD $seat($HOW_MANY)"
done
if [ "$G31_N" = "3" ] && [ -z "$G31_BAD" ]; then
  pass "G31 where the tokens stand is asked in three named places, once each"
else
  fail "G31 the token law is asked in $G31_N place(s), expected one each in$( \
       for seat in $G31_SEATS; do printf ' %s' "$seat"; done)$G31_BAD:"
  printf '%s\n' "$G31_CALLS" | sed 's/^/        /'
fi

if [ "$(grep -c 'fn is_token' "$TOKENS" 2>/dev/null || echo 0)" = "1" ] \
   && [ "$(grep -c 'fn token_spans' "$TOKENS" 2>/dev/null || echo 0)" = "1" ]; then
  pass "G31 the shape of a token is written in one place: tokens.rs"
else
  fail "G31 the token shape test is written more than once, or it is gone"
fi

# ---------------------------------------------------------------- G32
# **A document that comes back is read, at every door, and a hand may not
# protect what Z put there** — 079, the import side.
#
# Two halves of one law, and each has the shape this house has paid to learn:
#
#   * the **three** doors a hand can protect through ask one function before
#     anything else, and before `remember_in_vault`, which writes a value into
#     the vault — a law placed any later would have taught the vault a token of
#     ours (083a's three exits, the same enumeration by class);
#   * the glass asks «has this come back» in exactly one place, the bench's own
#     read of the scan a document arrived with, so that the four doors a
#     document can arrive by cannot each remember separately (item 3).
DOORS=z_core/src/ops/mod.rs
G32_BAD=""
for door in protect protect_all_matches protect_cell_in_lines; do
  BODY=$(awk -v d="$door" '
    $0 ~ "^pub\\(crate\\) fn " d "\\(" {inside=1}
    inside && /^}/ {print; inside=0; next}
    inside {print}
  ' "$DOORS")
  if [ -z "$BODY" ]; then
    G32_BAD="$G32_BAD $door(missing)"
  elif ! printf '%s\n' "$BODY" | grep -q 'a_token_already_stands_there('; then
    G32_BAD="$G32_BAD $door"
  fi
done
if [ -z "$G32_BAD" ]; then
  pass "G32 all three protect doors ask whether a token stands there first"
else
  fail "G32 a hand can protect a token through:$G32_BAD"
fi

# The law is one function, and the vault is taught nothing before it is asked.
if [ "$(grep -c 'fn a_token_already_stands_there' "$DOORS" 2>/dev/null || echo 0)" = "1" ]; then
  pass "G32 the law a hand meets is written in one function"
else
  fail "G32 the token law is written more than once in $DOORS, or it is gone"
fi
G32_ORDER=""
for door in protect protect_all_matches; do
  BODY=$(awk -v d="$door" '
    $0 ~ "^pub\\(crate\\) fn " d "\\(" {inside=1}
    inside && /^}/ {print; inside=0; next}
    inside {print}
  ' "$DOORS")
  ASK=$(printf '%s\n' "$BODY" | grep -n 'a_token_already_stands_there(' | head -1 | cut -d: -f1)
  LEARN=$(printf '%s\n' "$BODY" | grep -n 'remember_in_vault(' | head -1 | cut -d: -f1)
  if [ -z "$ASK" ] || [ -z "$LEARN" ] || [ "$ASK" -gt "$LEARN" ]; then
    G32_ORDER="$G32_ORDER $door"
  fi
done
if [ -z "$G32_ORDER" ]; then
  pass "G32 the token is asked about before the vault is taught the value"
else
  fail "G32 the vault is taught before the token law is asked, in:$G32_ORDER"
fi

# And one surface asks whether a document has come back.
G32_DART=$(grep -Rn 'z\.returningDocument(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' || true)
G32_DART_N=$(printf '%s\n' "$G32_DART" | grep -c . || true)
if [ "$G32_DART_N" = "1" ] && printf '%s' "$G32_DART" | grep -q 'core/session_state.dart'; then
  pass "G32 one surface asks whether a document came back, and it is the bench"
else
  fail "G32 the returning-document door is asked in $G32_DART_N place(s), expected one in core/session_state.dart:"
  printf '%s\n' "$G32_DART" | sed 's/^/        /'
fi

# The sentence for that state is written once: one state, one wording (046/L).
# Comments may quote it — the doc comment above it explains the wording, and a
# gate that could not read that would be a gate against explaining.
G32_SAID=$(grep -Rn "already protected — Z put it there" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' | grep -vE ':[0-9]+:[[:space:]]*//' || true)
G32_SAID_N=$(printf '%s\n' "$G32_SAID" | grep -c . || true)
if [ "$G32_SAID_N" = "1" ] && printf '%s' "$G32_SAID" | grep -q 'core/messages.dart'; then
  pass "G32 «this is already protected — Z put it there» is worded in one place"
else
  fail "G32 that sentence is written in $G32_SAID_N place(s), expected one in core/messages.dart:"
  printf '%s\n' "$G32_SAID" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G33
# **One outcome, one sentence, one place** — the fold of 15 October.
#
# `ProtectOutcome` was worded by hand at every press that could reach it: the
# acts bar over a selection, the column press in the workspace, and 084's
# search bar. Three exhaustive switches over one enum, and they had already
# drifted — the bar said «Already protected as T.» where the other two named
# who by, and wrote `Snapped` a third way. The same family as 046/L and as
# G32's own last check: a state said in two voices is a product that disagrees
# with itself, and the day a sixth variant lands, three files have to be found.
#
# So the enum is read in two files and no others, and the gate names both with
# the reason it is allowed:
#
#   * `core/messages.dart` — the only file that turns an outcome into **words**,
#     which is this file's whole job (the owner's rule of 29 September);
#   * `core/protecting.dart` — the only file that folds **many** places' answers
#     into the one answer a press gets, the way `protect_cell_in_lines` already
#     does in the core for a column. It says nothing: no sentence is written
#     there, and the switch it holds counts places.
#
# A screen that matches the enum again is a sentence about to drift, whatever
# it says, so the gate reads the arms and not the words. Comment lines are
# allowed to name a variant: a doc comment that explains which outcome a press
# can meet is the opposite of the defect.
G33_READERS=$(grep -Rn 'ProtectOutcome_' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
              | grep -v '/src/rust/' | grep -vE ':[0-9]+:[[:space:]]*(//|///|\*)' || true)
G33_FILES=$(printf '%s\n' "$G33_READERS" | grep -v '^$' | cut -d: -f1 | sort -u)
G33_STRAY=$(printf '%s\n' "$G33_FILES" | grep -v '^$' \
            | grep -vE "^$FLUTTER_LIB/core/(messages|protecting)\.dart$" || true)
G33_STRAY_N=$(printf '%s\n' "$G33_STRAY" | grep -c . || true)
# Two causes, and each says which one it is: a screen that words an outcome
# again, or a mapper that has stopped wording them at all.
if [ "$G33_STRAY_N" != "0" ]; then
  fail "G33 $G33_STRAY_N file(s) read a protect outcome outside core/messages.dart and core/protecting.dart:"
  printf '%s\n' "$G33_STRAY" | sed 's/^/        /'
elif ! printf '%s\n' "$G33_FILES" | grep -q "^$FLUTTER_LIB/core/messages.dart$"; then
  fail "G33 core/messages.dart matches no ProtectOutcome variant: the fold is gone, or it has stopped being exhaustive"
else
  pass "G33 a protect outcome becomes a sentence in core/messages.dart and nowhere else"
fi

# ---------------------------------------------------------------- G38
# **A session's language is chosen by the person, once** — rules 56 and 57, the
# owner on 16 October 2026 after making a session he was never asked about:
# «لم يسألني عن لغة الجلسة».
#
#   * **56** — Swedish is offered beside German and English everywhere a
#     language is chosen; Arabic stays unoffered until he says otherwise, and
#     both packs stay in the core either way.
#   * **57** — a session does not begin before the person picks, nothing is
#     pre-marked, and the application's own language no longer becomes a
#     session's language in silence. The doors are enumerated from what they
#     do, because «a law written at one door out of several» is what this
#     house pays for most often.
SHELL_DART=$FLUTTER_LIB/screens/shell.dart
LANGS=$FLUTTER_LIB/widgets/language_list.dart

G38_OFFERED=$(grep -oE "offeredLanguages = <String>\[[^]]*\]" "$LANGS" \
              | grep -oE "'[a-z]{2}'" | tr -d "'" | tr '\n' ' ' | sed 's/ $//')
if [ "$G38_OFFERED" = "de en sv" ]; then
  pass "G38 the languages offered are the measured three: de en sv (Arabic unoffered, both packs kept)"
else
  fail "G38 the offered languages are «$G38_OFFERED» — expected «de en sv» (rule 56)"
fi

# One list, every reader. A second literal pair is the «two copies of de, en»
# the one constant exists to prevent.
G38_LITERALS=$(grep -RnE "\['de',\s*'en'|\[\"de\",\s*\"en\"" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
               | grep -v '/src/rust/' | grep -v "^$LANGS:" || true)
G38_READERS=$(grep -Rn 'offeredLanguages' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
              | grep -v "^$LANGS:" | grep -c . || true)
if [ -z "$G38_LITERALS" ] && [ "$G38_READERS" -ge 4 ]; then
  pass "G38 one list decides what is offered, and $G38_READERS places read it"
else
  fail "G38 a second list of languages was written beside the one constant:"
  printf '%s\n' "$G38_LITERALS" | sed 's/^/        /'
fi

# **The application's language chooses no session's language.** Read from the
# source: who asks `appLanguage` at all. Two readers are right — the tally that
# draws the app's own pack, and `packForTheNextText`, which answers for a
# session that exists and has none of its own (080, rule 33). A third is the
# silent default rule 57c took out.
G38_APP=$(grep -Rn 'appLanguage(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
          | grep -v '/src/rust/' | grep -vE '^\S+: *//|// ' | cut -d: -f1 | sort -u \
          | sed "s|$FLUTTER_LIB/||" | tr '\n' ' ' | sed 's/ $//')
if [ "$G38_APP" = "core/session_state.dart screens/home.dart" ]; then
  pass "G38 the application's language is read where it is drawn and nowhere a session is born"
else
  fail "G38 «appLanguage» is read in «$G38_APP» — expected core/session_state.dart and screens/home.dart only (rule 57c)"
fi

# **Every door a text enters by asks first.** The doors are the imports (G37's
# own census); each must reach the one function that answers «which language»,
# and that function is the only place the fallback is read.
G38_QUIET=""
for door in _askFromHome _begin; do
  if ! awk -v want="$door" '
    $0 ~ "^  [A-Za-z_][A-Za-z_<>,? ]* " want "\\(" { inside = 1 }
    inside && /_theLanguageOfTheTextToCome\(/ { found = 1 }
    inside && /^  }/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$SHELL_DART"; then
    G38_QUIET="$G38_QUIET $door"
  fi
done
G38_ASKS=$(awk '
  /^  [A-Za-z_][A-Za-z_<>,? ]* _?[A-Za-z_]+\(/ { match($0, /[A-Za-z_]+\(/); here = substr($0, RSTART, RLENGTH - 1) }
  /_theLanguageOfTheTextToCome\(/ { if (here != "" && here != "_theLanguageOfTheTextToCome") print here }
' "$SHELL_DART" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ -z "$G38_QUIET" ] && [ "$G38_ASKS" = "_askFromHome _begin" ]; then
  pass "G38 both doors a text enters by ask which language before anything is read"
else
  fail "G38 these doors read a text without asking:$G38_QUIET (asked from «$G38_ASKS»)"
fi

# **And the room that begins a session by hand cannot default.** Two halves in
# one place: the press is dead until a language is picked, and the door itself
# refuses rather than filling one in.
if awk '
  /^  Future<void> _begin\(\) async \{/ { inside = 1 }
  inside && /let|final chosen = _packId;/ { bare = 1 }
  inside && /chosen == null/ { refuses = 1 }
  inside && /^  }/ { inside = 0 }
  END { exit(bare && refuses ? 0 : 1) }
' "$FLUTTER_LIB/screens/settings.dart" \
   && grep -q '_busy || _packId == null) ? null : _begin' "$FLUTTER_LIB/screens/settings.dart"; then
  pass "G38 a session begun by hand waits for its language, and the press says so"
else
  fail "G38 the «New session» room takes a language nobody chose (rule 57a)"
fi

# ---------------------------------------------------------------- G39
# **A block crosses from one client to the next, and says neither where nor
# when** — rule 58, the owner's answer of 16 October 2026:
#
#   «البلوك يعبر من ملف عميل إلى ملف عميل. كلمة حُميت عند العميل A تُحمى عند
#   العميل B، فالبلوك في خزنة المستخدم لا في ملف العميل. والجملة على الشاشة لا
#   تذكر أين حُميت الكلمة أول مرة ولا متى.»
#
# The behaviour is measured by the guards; what is read here is the **condition**
# he attached, because it is a promise about sentences and a sentence is added
# by a line of code. So the enumeration is of the places a card could learn
# where or when a word was first protected: the date on a block, the profile a
# hint is filtered by, and the row the glass draws from `learnedAt`.
#
# The law it amends is not repealed: a **taught value** of one client is still
# not loaded for another. That half lives in the values loop of `hints_for`,
# which is why the check below reads the block loop alone.
G39_MODEL=z_core/src/vault/model.rs

# One question, asked in one place. A second reader of `exempt` would be a
# second chance to ask it with the profile left out.
G39_ASKERS=$(awk '
  /^(    )?pub\(crate\) fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /works_in\(/ { if (here != "" && here != "works_in") print here }
' z_core/src/vault/model.rs z_core/src/vault/mod.rs z_core/src/ops/mod.rs z_core/src/ops/vault.rs \
  | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G39_ASKERS" = "hints_for" ]; then
  pass "G39 whether a block works is asked in one place, and it is the one that knows the profile"
else
  fail "G39 «does this block work here» is asked from «$G39_ASKERS» — expected hints_for alone (rule 58/59)"
fi

# And the block loop reads the profile **only** through that question: a second
# mention of `active_profile` under it would be a block scoped to a client.
G39_SCOPED=$(awk '
  /The blocks, after the values/ { inside = 1 }
  inside && /active_profile/ { print NR ": " $0 }
  inside && /^        out.sort_by_key/ { inside = 0 }
' "$G39_MODEL" | wc -l | tr -d ' ')
if [ "$G39_SCOPED" = "1" ]; then
  pass "G39 a block is not filtered by a client anywhere but the one exemption question"
else
  fail "G39 the block loop reads the active profile $G39_SCOPED times — expected once, inside works_in (rule 58)"
fi

# **No date.** A block carries `made_at`, and it may reach the file and nothing
# else: a card that said «protected on 3 October» would be the condition broken
# in the one place a protection explains itself.
G39_WHEN=$(grep -rn "made_at" z_core/src --include='*.rs' 2>/dev/null \
           | cut -d: -f1 | sort -u | grep -v 'vault/model.rs\|vault/format.rs' | tr '\n' ' ' | sed 's/ $//')
if [ -z "$G39_WHEN" ]; then
  pass "G39 when a block was made reaches the vault file and no sentence"
else
  fail "G39 a block's date is read outside the vault file, in: $G39_WHEN (rule 58's condition)"
fi

# And the one date the card *can* carry is a taught value's own, read in that
# order: the clause is written only after the value is found.
if awk '
  /^pub\(crate\) fn explain\(/ { inside = 1 }
  inside && /known\.as_ref\(\)\.map\(\|k\| k\.learned_at\)/ { if (!asked) asked = NR }
  inside && /day_of\(/ { if (!said) said = NR }
  inside && /^}/ { inside = 0 }
  END { exit(asked && said && asked < said ? 0 : 1) }
' z_core/src/ops/mod.rs; then
  pass "G39 the Why card says «kept since» only for knowledge it found first, never for a block"
else
  fail "G39 the Why card can write a date without having found the value that has one (rule 58)"
fi

# The glass draws that row only when there is a date, and a block's is zero.
if awk '
  /learnedAt > BigInt.zero/ { asked = NR }
  /Taught on/ { said = NR }
  END { exit(asked && said && asked < said ? 0 : 1) }
' apps/flutter_app/lib/widgets/why_sheet.dart; then
  pass "G39 the glass draws «Taught on» only where there is something to draw"
else
  fail "G39 the Why sheet can draw a date row for a word nobody taught (rule 58)"
fi

# **No where.** A block's claimant is a stand-in the core writes where an
# identity would stand; it reaches the glass as a count and never as a word.
G39_HANDLE=$(grep -Rn "a word you protected" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null | tr '\n' ' ')
if [ -z "$G39_HANDLE" ]; then
  pass "G39 a block's stand-in name is in no sentence the glass draws"
else
  fail "G39 the glass writes a block's claimant into a sentence: $G39_HANDLE"
fi

# ---------------------------------------------------------------- G40
# **«Forget» exempts a word's blocks and deletes none of them** — rule 59, the
# owner, 16 October 2026: «Forget يُعفي بلوكات تلك الكلمة من العمل ولا يمسحها».
#
# Three things source can be read for. **One hand** writes an exemption, so a
# door cannot invent a fourth reach; **every door that takes a word out of the
# vault's knowledge** calls it, enumerated from what the doors *do* rather than
# from the four this round remembered; and **nothing takes an exemption back**,
# which is the half that would quietly undo the person's act.
G40_OPS=z_core/src/ops/vault.rs

G40_WRITERS=$(awk '
  /^    pub\(crate\) fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /\.exempt\.push\(/ { if (here != "") print here }
' "$G39_MODEL" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G40_WRITERS" = "exempt_block" ]; then
  pass "G40 one function writes an exemption, for «in this conversation» and for «Forget» alike"
else
  fail "G40 an exemption is written by: «$G40_WRITERS» — expected «exempt_block» (rule 59)"
fi

# **Nothing takes one back.** Every way a `Vec` loses an element, named — the
# same reading G35 makes of the blocks themselves, because an exemption the
# person asked for is as permanent as the block it sits on until they teach the
# word again.
G40_UNDONE=$(grep -RnE '\.exempt\s*\.\s*(remove|retain|clear|pop|drain|truncate|swap_remove|dedup|split_off)|\.exempt\s*=' \
               z_core/src --include='*.rs' 2>/dev/null || true)
if [ -z "$G40_UNDONE" ]; then
  pass "G40 nothing in the core takes an exemption back, so a rescan cannot undo a «Forget»"
else
  fail "G40 an exemption is taken away, and the person's «Forget» would be undone by it:"
  printf '%s\n' "$G40_UNDONE" | sed 's/^/        /'
fi

# **Every door, enumerated from what it does.** A function that removes a value,
# a spelling or a taught name is a «Forget» of a word, whatever it is called —
# so each must reach the one hand, itself or through another door that does.
# `forget_user_name` is the named exception and says why: it presses two of the
# others.
G40_DRY=""
for door in $(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /values\.retain\(|taught_names\.retain\(|aliases\.retain\(/ { if (here != "") print here }
' "$G40_OPS" | sort -u); do
  # `forget_user_name` is the one named exception: it presses two of the other
  # doors (`forget_name` for the dictionary row, `delete_value` for the
  # «always» twin), and each of those exempts. Every other door answers for
  # itself — and never with its own signature line, which is why the wanted
  # call is read with the door's own name excluded.
  # The bracket form, not a backslash: `awk -v` reads escape sequences, so
  # `\(` would arrive as a bare `(` and the regexp would not compile.
  if [ "$door" = "forget_user_name" ]; then
    want='forget_name[(]|delete_value[(]'
  else
    want='forget_the_blocks_of[(]'
  fi
  if ! awk -v door="$door" -v want="$want" '
    $0 ~ "^(pub\\(crate\\) )?fn " door "\\(" { inside = 1; next }
    inside && $0 ~ want { found = 1 }
    inside && /^}/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$G40_OPS"; then
    G40_DRY="$G40_DRY $door"
  fi
done
G40_DOORS=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /values\.retain\(|taught_names\.retain\(|aliases\.retain\(/ { if (here != "") print here }
' "$G40_OPS" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ -z "$G40_DRY" ]; then
  pass "G40 every door that forgets a word exempts its blocks: $G40_DOORS"
else
  fail "G40 these doors take a word out of the vault and leave its blocks working:$G40_DRY"
fi

# **The way back asks nothing about work.** z-pdf still reads a forgotten word
# out of a document protected before the act (rule 59's third sentence, and
# rule 50), which is true only while the lookup is blind to the exemptions.
if awk '
  /pub\(crate\) fn block_value_for\(/ { inside = 1 }
  inside && /exempt|works_in/ { asked = 1 }
  inside && /^    }/ { inside = 0 }
  END { exit(asked ? 1 : 0) }
' "$G39_MODEL"; then
  pass "G40 the door back looks a token up without asking whether the block still works"
else
  fail "G40 the way back consults the exemptions, so a forgotten word could not be read back (rule 59)"
fi
# ---------------------------------------------------------------- G37
# **The session is born at its first document, and nowhere else** — rule 55,
# the owner's answer of 16 October 2026: «المحادثة لا علاقة بالوثائق… ولكن عند
# إدخال الوثائق نحفظها كما اتفقنا».
#
# A *conversation* is what the person writes to a model; the **session** is the
# container, and a container exists the moment it holds something. The rule is
# therefore two laws that pull against each other, and both are read from the
# source here: **a document in the preview always has a session**, and **a
# session never exists without a document or a conversation**. The code's word
# for the container is still `Conversation`; 066 pays the rename.
BORN=z_core/src/ops/conversation.rs

# One hand hands out a session's number and its key.
G37_BIRTHS=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /\.begin_conversation\(/ { if (here != "") print here }
' "$BORN" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G37_BIRTHS" = "begin_in" ]; then
  pass "G37 one function in the core begins a session, and every door goes through it"
else
  fail "G37 a session is begun by: «$G37_BIRTHS» — expected «begin_in», so a second birth appeared that nobody measures"
fi

# And a birth nobody asked for happens at one door: the preview's.
G37_SILENT=$(grep -RlE 'born_at_the_first_document\(' z_core/src --include='*.rs' 2>/dev/null \
             | tr '\n' ' ' | sed 's/ $//')
G37_WHERE=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /born_at_the_first_document\(/ { if (here != "" && here != "born_at_the_first_document") print here }
' "$BORN" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G37_SILENT" = "$BORN" ] && [ "$G37_WHERE" = "keep_the_preview" ]; then
  pass "G37 a session nobody asked for is born at one door, the one a document enters by"
else
  fail "G37 a silent birth is reached from «$G37_WHERE» in «$G37_SILENT» — expected keep_the_preview in $BORN alone"
fi

# **No empty sessions.** The question «is there a document here» is asked
# before anything is born, in the same function and above it — a session in the
# list holding nothing is the defect this order prevents.
if awk '
  /^pub\(crate\) fn keep_the_preview\(/ { inside = 1 }
  inside && /trim\(\)\.is_empty\(\)/ { asked = NR }
  inside && /born_at_the_first_document\(/ { born = NR }
  inside && /^}/ { inside = 0 }
  END { exit(asked && born && asked < born ? 0 : 1) }
' "$BORN"; then
  pass "G37 nothing is born before the preview is asked whether it holds a document"
else
  fail "G37 keep_the_preview births a session without asking first whether anything is in the preview"
fi

# **One name, two languages.** The core writes the name of a session nobody
# named and the glass reads it to tell an unnamed session from a named one
# (081). Two spellings of one string is this house's «one fact, one source»,
# and a cross-language seam is where it goes wrong quietly.
G37_RUST=$(grep -oE 'A_SESSION_CALLED: &str = "[^"]+"' "$BORN" | sed 's/.*= "//; s/"$//')
G37_DART=$(grep -oE "_aSessionCalled = '[^']+'" "$FLUTTER_LIB/core/session_state.dart" \
           | sed "s/.*= '//; s/'$//")
if [ -n "$G37_RUST" ] && [ "$G37_RUST" = "$G37_DART" ]; then
  pass "G37 the core and the glass spell a session nobody named the same: «$G37_RUST N»"
else
  fail "G37 the core calls it «$G37_RUST» and the glass «$G37_DART», so one of them draws a name the other cannot read"
fi

# **And every door a document enters by on the glass tells the list.** The rule
# says «the moment it enters the preview», which on a screen means the ground
# is asked again at that instant — enumerated from the imports, not from the
# doors we remember.
G37_IMPORTS=$(grep -Rn 'z\.importText(\|z\.importDocument(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
              | grep -v '/src/rust/' | cut -d: -f1 | sort -u | tr '\n' ' ' | sed 's/ $//')
G37_DOORS=$(awk '
  /^  [A-Za-z_][A-Za-z_<>,? ]* _?[A-Za-z_]+\(/ { match($0, /[A-Za-z_]+\(/); here = substr($0, RSTART, RLENGTH - 1) }
  /z\.importText\(|z\.importDocument\(/ { if (here != "") print here }
' "$FLUTTER_LIB/screens/shell.dart" | sort -u | tr '\n' ' ' | sed 's/ $//')
G37_QUIET=""
for door in $G37_DOORS; do
  if ! awk -v want="$door" '
    $0 ~ "^  [A-Za-z_][A-Za-z_<>,? ]* " want "\\(" { inside = 1 }
    inside && /_theDocumentHasEntered\(/ { found = 1 }
    inside && /^  }/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$FLUTTER_LIB/screens/shell.dart"; then
    G37_QUIET="$G37_QUIET $door"
  fi
done
if [ "$G37_IMPORTS" = "$FLUTTER_LIB/screens/shell.dart" ] \
   && [ "$G37_DOORS" = "_askFromHome _begin" ] && [ -z "$G37_QUIET" ]; then
  pass "G37 both doors a document enters the preview by tell the list it was kept"
else
  fail "G37 a document enters by «$G37_DOORS» in «$G37_IMPORTS» and these tell the list nothing:$G37_QUIET"
fi

# ---------------------------------------------------------------- G36
# **The saved document, and the census of the doors it leaves by** — 089 rule 9,
# the owner's rule of 15 October: «عنصرنا هو البلوك لا المستند».
#
# Documents are not saved, with one exception: the one in the preview that has
# not left it, kept with its decisions so a power cut finds it as it was left.
# **Leaving by a door takes it out.** That is a law at every door text leaves
# by, which is this house's most expensive shape — so the doors are
# **enumerated from what they do**, not from a list somebody keeps: every
# function that reaches a provider or hands the protected text to its caller.
#
# The census found a fourth door the first three were written without: Direct
# Mode (`ask_model_directly`), where the person sends the text as it stands.
DOORS=z_core/src/ops/mod.rs
KEPT=z_core/src/ops/conversation.rs

G36_OUT=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /crate::gateway::send\(|crate::providers::ask\(|payload_view\(build_payload\(/ { if (here != "") print here }
' "$DOORS" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G36_OUT" = "ask_model ask_model_directly payload_to_take_out send" ]; then
  pass "G36 four doors take text out of this machine, and the list is the measured one"
else
  fail "G36 the doors that take text out are: $G36_OUT — expected «ask_model ask_model_directly payload_to_take_out send», so a door appeared that nobody measures"
fi

G36_STAYS=""
for door in ask_model ask_model_directly payload_to_take_out send; do
  if ! awk -v want="$door" '
    $0 ~ "^(pub\\(crate\\) )?fn " want "\\(" { inside = 1 }
    inside && /the_preview_has_left\(/ { found = 1 }
    inside && /^}/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$DOORS"; then
    G36_STAYS="$G36_STAYS $door"
  fi
done
if [ -z "$G36_STAYS" ]; then
  pass "G36 every door that takes text out takes the preview's copy with it"
else
  fail "G36 these doors take text out and leave the saved copy behind:$G36_STAYS"
fi

# **And every door a document arrives by keeps it.** Asked the way G34 asks
# about the scan: by reading which functions install a document's text, so a
# third installer could not appear without this line moving.
G36_IN=$(awk '
  /^pub\(crate\) fn [a-z_]+\(/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /\.original = / { print here }
' "$DOORS" | sort -u | tr '\n' ' ' | sed 's/ $//')
G36_DRY=""
for door in $G36_IN; do
  if ! awk -v want="$door" '
    $0 ~ "^pub\\(crate\\) fn " want "\\(" { inside = 1 }
    inside && /keep_the_preview\(/ { found = 1 }
    inside && /^}/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$DOORS"; then
    G36_DRY="$G36_DRY $door"
  fi
done
if [ "$G36_IN" = "import_document import_text" ] && [ -z "$G36_DRY" ]; then
  pass "G36 both doors a document arrives by keep it in the preview"
else
  fail "G36 a document arrives by «$G36_IN» and these keep nothing:$G36_DRY"
fi

# **One function takes a saved document away, and it is the one the doors
# call.** A second path that could remove a person's preview would be a
# deletion nobody measures — the same rule the blocks have (G35), for the same
# reason: what the app keeps for a person is not removed by accident.
# Outside the file that owns them, nothing may touch the list at all; inside
# it, the one function below is read by name. Two halves, because «who owns
# this» and «who else reaches in» are two questions.
#
# **Two acts reach that one hand since rule 55** (16 October) and they are the
# same act — the copy is no longer in this list: the text left the machine by a
# door, or the bench moved to another session and took the copy with it. Both
# are named here, so a third would have to be.
G36_GONE=$(grep -RnE '\.kept\s*\.\s*(retain|remove|clear|pop|drain|truncate|swap_remove)|\.kept\s*=\s*Vec::new' \
             z_core/src --include='*.rs' 2>/dev/null | grep -v "^$KEPT:" || true)
G36_OWNER=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /body\.kept\.retain\(/ { print here }
' "$KEPT" | sort -u | tr '\n' ' ' | sed 's/ $//')
G36_HANDS=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /take_the_copy_out\(/ { if (here != "" && here != "take_the_copy_out") print here }
' "$KEPT" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ -z "$G36_GONE" ] && [ "$G36_OWNER" = "take_the_copy_out" ] \
   && [ "$G36_HANDS" = "keep_the_preview the_preview_has_left" ]; then
  pass "G36 a saved document is taken out of a list in one place, reached by the door it left by and by the bench that moved"
else
  fail "G36 a saved document is removed by «$G36_OWNER», reached from «$G36_HANDS» — expected take_the_copy_out, from keep_the_preview and the_preview_has_left"
  printf '%s\n' "$G36_GONE" | sed 's/^/        /'
fi

# **The session file's own version moved, and the table says so.** The third of
# the three numbers, and the one rule 9 spends: a saved document is in the
# conversation's file, not in the vault's body.
G36_FMT=$(grep -oE 'SESSION_FORMAT_VERSION: u16 = [0-9]+' z_core/src/conversation.rs | grep -oE '[0-9]+$')
if [ "$G36_FMT" = "5" ] && grep -q "SESSION_FORMAT_VERSION\` = 5 |" z_core/src/vault/format.rs; then
  pass "G36 the session file is at format 5, and the fence table names it"
else
  fail "G36 the session format is $G36_FMT and the fence table in vault/format.rs does not say so"
fi

# **And the copy follows the decisions.** «A power cut finds it as it was left»
# is a promise about what the person *did*, so the copy is written again at
# every act that writes a block — one call, read here by name, rather than a
# copy written once when the document arrived and never again.
if awk '
  /^pub\(crate\) fn the_decisions_are_written\(/ { inside = 1 }
  inside && /blocks_from_this_bench\(/ { blocks = 1 }
  inside && /keep_the_preview\(/ { preview = 1 }
  inside && /^}/ { inside = 0 }
  END { exit(blocks && preview ? 0 : 1) }
' "$DOORS"; then
  pass "G36 one call writes both the blocks and the preview's copy, so a door cannot write half"
else
  fail "G36 the blocks and the saved document are written by two different calls, which is one chance per door to forget one"
fi

# **And every act that changes what is protected writes it down.** Enumerated
# from what the functions do — the ones that add or take away a protection —
# rather than from a list of names: «Here» was remembered by nobody until this
# line was written, and it was a measured red (the copy held four marks where
# the bench held three).
G36_ACTS=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /\.protections\.push\(|\.protections\.retain\(/ { if (here != "") print here }
' "$DOORS" | sort -u | grep -vE '^(protect_inner|protect_range)$' | tr '\n' ' ' | sed 's/ $//')
G36_HALF=""
for act in $G36_ACTS; do
  if ! awk -v want="$act" '
    $0 ~ "^(pub\\(crate\\) )?fn " want "\\(" { inside = 1 }
    inside && /the_decisions_are_written\(/ { found = 1 }
    inside && /^}/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$DOORS"; then
    G36_HALF="$G36_HALF $act"
  fi
done
if [ "$G36_ACTS" = "add_alias undo_last_protection unprotect unprotect_every_place" ] && [ -z "$G36_HALF" ]; then
  pass "G36 every act that adds or takes away a protection writes the copy and the blocks"
else
  fail "G36 acts that change what is protected: «$G36_ACTS» — and these write nothing down:$G36_HALF"
fi

# One surface opens a saved document, as one surface opens the door back (G34):
# the shell, which is the only place that holds a bench.
G36_DART=$(grep -Rn 'z\.openKeptDocument(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' || true)
G36_DART_N=$(printf '%s\n' "$G36_DART" | grep -c . || true)
if [ "$G36_DART_N" = "1" ] && printf '%s' "$G36_DART" | grep -q 'screens/shell.dart'; then
  pass "G36 one surface opens a saved document, and it is the shell"
else
  fail "G36 a saved document is opened in $G36_DART_N place(s), expected one in screens/shell.dart:"
  printf '%s\n' "$G36_DART" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G35
# **A block is never deleted, and every word that takes a token becomes one** —
# 089 rules 1, 2, 7 and 8, the owner's rule of 15 October 2026.
#
#   «كل كلمة يأخذ رمزاً… هي بلوك غير قابل للحذف من خزنة المستخدم… يمكن أن تُعفى
#   من العمل ولكن لا تختفي.»
#
# Two halves, and each is a thing source can be read for rather than hoped
# about: **nothing removes a block**, and **every door that gives a word a
# token writes it down**. The second is the one this house keeps paying for —
# 083a's three exits, 080's two language doors, the two import doors of item 3 —
# so it is asked the way G34 asks about installing a document: by enumerating
# the callers of the functions that mint, not by naming the doors we remember.
VAULT=z_core/src/vault
DOORS=z_core/src/ops/mod.rs
# **One name at the doors since 089 rule 9**: the blocks and the preview's copy
# are written in one call, because they are one moment and two calls at each
# door is one chance per door to write half of what happened.
BLOCKS=the_decisions_are_written

# **Nothing deletes a block.** Every way a `Vec` loses an element, named — and
# the whole of `z_core/src` asked, not only the vault, because a block deleted
# from `ops` would be a block deleted.
G35_GONE=$(grep -RnE '\.blocks\s*\.\s*(remove|retain|clear|pop|drain|truncate|swap_remove|dedup|split_off)|\.blocks\s*=' \
             z_core/src --include='*.rs' 2>/dev/null || true)
if [ -z "$G35_GONE" ]; then
  pass "G35 nothing in the core removes a block: it can be exempted from work, never deleted"
else
  fail "G35 a block is deleted, and the owner's rule is that a block never disappears:"
  printf '%s\n' "$G35_GONE" | sed 's/^/        /'
fi

# And the one writer. A second function reaching into the table is not wrong by
# itself — it is unmeasured, which for this rule is the same thing.
G35_WRITERS=$(awk '
  /^    pub\(crate\) fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /\.blocks\.push\(|\.exempt\.push\(/ { print here }
' "$VAULT/model.rs" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G35_WRITERS" = "exempt_block remember_block" ]; then
  pass "G35 the block table is written by remember_block and exempt_block, and by nothing else"
else
  fail "G35 the block table is written by: $G35_WRITERS — expected «exempt_block remember_block»"
fi

# **Every door that gives a word a token writes the block.** The three
# functions that mint into a bench's store are read for their callers, and each
# caller must drain. Two of them are named exceptions and say why: the settle
# (`rescan_with`) and the cell loop run inside the session lock and cannot
# reach the vault from there, so their own callers drain instead — which the
# list below is what proves.
G35_CALLERS=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /protect_inner\(|protect_range\(|protect_lines\(/ { if (here != "") print here }
' "$DOORS" | sort -u | grep -vE '^(protect_inner|protect_range|protect_lines)$' | tr '\n' ' ' | sed 's/ $//')
# `scan` is not in this list and must not be: it reaches the settle through
# `rescan_with`, and the line below is what measures that it drains.
G35_WANT="answer_finding ask_model protect protect_all_matches protect_cell_in_lines rescan_with set_question"
if [ "$G35_CALLERS" = "$G35_WANT" ]; then
  pass "G35 the minting functions are called from seven doors, and the list is the measured one"
else
  fail "G35 a word can be given a token from: $G35_CALLERS — expected «$G35_WANT», so a door appeared that nobody measures"
fi

G35_DRY=""
for door in answer_finding ask_model protect protect_all_matches protect_cell_in_lines scan set_question; do
  if ! awk -v want="$door" '
    $0 ~ "^(pub\\(crate\\) )?fn " want "\\(" { inside = 1 }
    inside && /the_decisions_are_written\(/ { found = 1 }
    inside && /^}/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$DOORS"; then
    G35_DRY="$G35_DRY $door"
  fi
done
if [ -z "$G35_DRY" ]; then
  pass "G35 every door that gives a word a token writes its block ($BLOCKS)"
else
  fail "G35 these doors give a word a token and write no block:$G35_DRY"
fi

# `rescan_with` is the settle, and it is the one caller that does not drain: it
# holds the session and cannot reach the vault. Its own callers must, and this
# is the line that says which they are.
G35_SETTLERS=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /rescan_with\(/ { if (here != "" && here != "rescan_with") print here }
' "$DOORS" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G35_SETTLERS" = "rescan_keeping scan" ] \
   && grep -q "the_decisions_are_written" "$DOORS" \
   && awk '/^fn rescan_keeping\(/ { inside = 1 } inside && /the_decisions_are_written\(/ { found = 1 } inside && /^}/ { inside = 0 } END { exit(found ? 0 : 1) }' "$DOORS"; then
  pass "G35 the settle is reached by scan and rescan_keeping, and both write the blocks"
else
  fail "G35 the settle is reached from «$G35_SETTLERS» and one of them does not write the blocks"
fi

# **The answer page's own word is ours, and never a block.** It is minted by the
# bench like any other word because the owner asked for it to be protected like
# any other — so the one place that lists the words a bench named has to drop
# it by name, beside the store, where no caller can forget.
if grep -A 12 'fn words_it_named' z_core/src/tokens.rs 2>/dev/null | grep -q 'ANSWER_PAGE_WORD'; then
  pass "G35 the answer page's own word is dropped where the words a bench named are listed"
else
  fail "G35 nothing stops «Zprivacy-svara» becoming a block, which would protect our own word in every document for ever"
fi

# **The blocks widen the lookup, never the allowed list** — the lead's ruling of
# 15 October, in the one line that could ever break it. `restore` asks the
# allowed list by itself and only then looks a value up, so a wider lookup
# cannot widen what a turn may carry (G9). Read as an order, the way G32 reads
# the law before `remember_in_vault`: a build where the value came first and
# the list was checked after would pass every behaviour guard that happened not
# to carry a foreign token.
G35_GATE=$(awk '
  /let allowed_here = / { seen = NR }
  /values\.value_for\(/ { if (seen && NR > seen) print "ordered" }
' z_core/src/tokens.rs | head -1)
if [ "$G35_GATE" = "ordered" ]; then
  pass "G35 the allowed list is read before a value is looked up, so the blocks cannot widen it"
else
  fail "G35 restore looks a value up without reading the allowed list first (G9), or the line moved"
fi

# **The sentence goes** — 089 rule 7. «Kept only while it is open» and «nothing
# is kept» were the trade the owner withdrew, and a sentence deleted from the
# screen that stayed in a second screen is the «0 tries left» shape. The
# comments that tell the history are left alone: what is read here is what a
# person can be shown.
G35_SAID=$(grep -RnE "kept only while it is open|Nothing is kept behind" \
             "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -vE ':\s*(//|///|\*)' || true)
if [ -z "$G35_SAID" ]; then
  pass "G35 no screen says a protection is kept only while a conversation is open"
else
  fail "G35 the withdrawn sentence is still on the glass:"
  printf '%s\n' "$G35_SAID" | sed 's/^/        /'
fi

# **The three format numbers say what they are** — 089 rule 8, the ed's note.
# The table in `format.rs` is the one place a person goes to read which number
# governs what, and it named model 12 while the constant said 13 and session
# format 1 while the constant said 4. A table nobody has to update is a table
# that drifts.
G35_MODEL=$(grep -oE 'MODEL_VERSION: u16 = [0-9]+' "$VAULT/format.rs" | grep -oE '[0-9]+$')
G35_SESSION=$(grep -oE 'SESSION_FORMAT_VERSION: u16 = [0-9]+' z_core/src/conversation.rs | grep -oE '[0-9]+$')
if grep -q "\`MODEL_VERSION\` = $G35_MODEL |" "$VAULT/format.rs" \
   && grep -q "SESSION_FORMAT_VERSION\` = $G35_SESSION |" "$VAULT/format.rs"; then
  pass "G35 the fence table names the numbers the constants hold: model $G35_MODEL, session $G35_SESSION"
else
  fail "G35 the fence table in format.rs disagrees with the constants (model $G35_MODEL, session format $G35_SESSION)"
fi

# ---------------------------------------------------------------- G34
# **The door back has no seat** — 079 rule 3, built as 089 rule 5.
#
# «The mode is RESTORE, never protection» (079 rule 3), and «a returning
# document is never re-protected and never re-scanned as fresh content»
# (rule 5, *forbidden, absolutely*). A flag on an import door would make that a
# thing somebody has to remember at a door that already protects by law — the
# shape item 3 of 14 October was built to end, read the other way round.
#
# So the door takes **no session**: there is no bench for a protection to land
# on, no `s.original` to install, and nothing to scan. The law is a state the
# code cannot express rather than a branch that has to be taken, which is the
# climb `make_the_wrong_state_unrepresentable` names — and this gate reads the
# signature, the body and the one surface that asks.
DOORS=z_core/src/ops/mod.rs
BACK=read_a_document_that_came_back
# The signature, in the contract: a door with a seat in it would be a door that
# can protect, whatever its body says today.
G34_SIG=$(grep -n "^pub fn $BACK(" "$API_FILES_FIRST" 2>/dev/null || true)
if [ "$(printf '%s\n' "$G34_SIG" | grep -c .)" != "1" ]; then
  fail "G34 the contract declares the door back $(printf '%s\n' "$G34_SIG" | grep -c .) time(s), expected one"
elif printf '%s' "$G34_SIG" | grep -q 'SessionId'; then
  fail "G34 the door back takes a session, so a returning document can be protected on one:"
  printf '%s\n' "$G34_SIG" | sed 's/^/        /'
else
  pass "G34 the door back takes no session: there is no bench to protect on"
fi

# And its body: it reads the file and hands back the reading. Not one call that
# scans, protects or installs a document — each of those is named, because
# «it does not do that today» is not a measurement.
G34_BODY=$(awk -v d="$BACK" '
  $0 ~ "^pub\\(crate\\) fn " d "\\(" {inside=1}
  inside && /^}/ {print; inside=0; next}
  inside {print}
' "$DOORS")
G34_DID=$(printf '%s\n' "$G34_BODY" \
          | grep -nE '(^|[^a-z_])(scan|the_scan_that_arrives_with_the_document|protect|protect_inner|protect_range|import_text|import_document)\(' || true)
if [ -z "$G34_BODY" ]; then
  fail "G34 the door back is not built in $DOORS"
elif [ -n "$G34_DID" ]; then
  fail "G34 the door back scans or protects what came back:"
  printf '%s\n' "$G34_DID" | sed 's/^/        /'
else
  pass "G34 the door back only reads: it neither scans nor protects"
fi

# **Every way a document gets onto a bench scans it.** G29 asks the two import
# doors by name; this asks the question the other way round, so that a third
# door could not install a document without anybody checking it — the
# enumeration `a_control_that_fails_to_bite_is_a_finding` asks for.
G34_INSTALLERS=$(awk '
  /^pub\(crate\) fn [a-z_]+\(/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /\.original = / { print here }
' "$DOORS" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$G34_INSTALLERS" = "import_document import_text" ]; then
  pass "G34 a document is installed on a bench by the two import doors only, and both scan (G29)"
else
  fail "G34 a document's text is installed on a bench by: $G34_INSTALLERS — G29 checks import_text and import_document, so anything else is a door nobody measures"
fi

# One surface asks it, as one surface asks whether a document came back (G32):
# the «z-pdf» entry in the + menu, and no second door of its own.
G34_DART=$(grep -Rn 'z\.readADocumentThatCameBack(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' || true)
G34_DART_N=$(printf '%s\n' "$G34_DART" | grep -c . || true)
if [ "$G34_DART_N" = "1" ] && printf '%s' "$G34_DART" | grep -q 'screens/shell.dart'; then
  pass "G34 one surface opens the door back, and it is the shell's «z-pdf» entry"
else
  fail "G34 the door back is opened in $G34_DART_N place(s), expected one in screens/shell.dart:"
  printf '%s\n' "$G34_DART" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G29
# **A document arrives scanned, through every door it can arrive by** — the
# detection round of 14 October, item 3.
#
# `import_text` and `import_document` installed the text and returned, leaving
# the scan to whoever called next. Two Dart doors remembered and nothing made
# them: `list_findings` right after an import was empty, a value the vault
# already knows was not put back, and a person opening a document met a press
# that did nothing. One law written at one door out of several — 083a's shape,
# and 080's.
#
# So the scan is at the door, in one function both doors call; and the glass
# asks for a scan in exactly one place, which is the rescan.
DOORS=z_core/src/ops/mod.rs
if [ "$(grep -c 'fn the_scan_that_arrives_with_the_document' "$DOORS" 2>/dev/null || echo 0)" = "1" ]; then
  pass "G29 the scan a document arrives with is built in one function"
else
  fail "G29 the import scan is written in more than one place, or it is gone"
fi

G29_BAD=""
for door in import_text import_document; do
  BODY=$(awk -v d="$door" '
    $0 ~ "^pub\\(crate\\) fn " d "\\(" {inside=1}
    inside && /^}/ {print; inside=0; next}
    inside {print}
  ' "$DOORS")
  if [ -z "$BODY" ]; then
    G29_BAD="$G29_BAD $door(missing)"
  elif ! printf '%s\n' "$BODY" | grep -q 'the_scan_that_arrives_with_the_document('; then
    G29_BAD="$G29_BAD $door"
  fi
done
if [ -z "$G29_BAD" ]; then
  pass "G29 both import doors scan what they have just read: import_text, import_document"
else
  fail "G29 an import door hands back a document it has not scanned:$G29_BAD"
fi

# And nothing on the glass scans a document it has just imported: the one Dart
# caller of the scan door is the bench's own rescan.
G29_DART=$(grep -Rn 'z\.scan(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' || true)
G29_DART_N=$(printf '%s\n' "$G29_DART" | grep -c . || true)
if [ "$G29_DART_N" = "1" ] && printf '%s' "$G29_DART" | grep -q 'core/session_state.dart'; then
  pass "G29 one surface asks for a scan, and it is the bench's rescan"
else
  fail "G29 the scan door is asked in $G29_DART_N place(s), expected one in core/session_state.dart:"
  printf '%s\n' "$G29_DART" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G28
# **The three exits share one law** — 083a, closing contract C3.
#
# The law was written at one exit out of three. A send through a key refused
# with `OpenSuggestions` (G12); Copy Protected and Save as PDF asked the core
# nothing, took the Safe column's text and put the waiting word on the
# clipboard or in a PDF exactly as the person had written it. One rule written
# in place and never applied to its siblings — the same shape as 080's two
# language doors, and this house's most expensive trap.
#
# So: the refusal is built in exactly one function in the core, every door that
# takes text out calls that function, and no Dart surface asks the exit door for
# itself. Each half of this gate is the shape of the defect it refuses.
LAW=z_core/src/ops/mod.rs
MADE=$(grep -n 'return Err(ApiError::OpenSuggestions' "$LAW" 2>/dev/null || true)
if [ "$(printf '%s\n' "$MADE" | grep -c .)" = "1" ] \
   && [ "$(grep -c 'fn no_word_waits' "$LAW" 2>/dev/null || echo 0)" = "1" ]; then
  pass "G28 the refusal «a word is waiting» is built in one function in the core"
else
  fail "G28 the refusal is built in more than one place, or no_word_waits is gone:"
  printf '%s\n' "$MADE" | sed 's/^/        /'
fi

# And every door that takes text out of the machine asks it. The body of each
# one is read, not the file: a call in a neighbouring function would otherwise
# answer for a door that does not check at all.
G28_BAD=""
for door in payload_to_take_out send ask_model; do
  BODY=$(awk -v d="$door" '
    $0 ~ "^pub\\(crate\\) fn " d "\\(" {inside=1}
    inside && /^}/ {print; inside=0; next}
    inside {print}
  ' "$LAW")
  if [ -z "$BODY" ]; then
    G28_BAD="$G28_BAD $door(missing)"
  elif ! printf '%s\n' "$BODY" | grep -q 'no_word_waits('; then
    G28_BAD="$G28_BAD $door"
  fi
done
if [ -z "$G28_BAD" ]; then
  pass "G28 all three exits ask the one law: payload_to_take_out, send, ask_model"
else
  fail "G28 an exit does not ask no_word_waits():$G28_BAD"
fi

# And nothing on the glass asks the exit door for itself. The order's one
# helper asks it, out where a guard can drive it, and each press is a line that
# takes what it is handed — the shape 081 left behind and 083a keeps.
G28_DART=$(grep -Rn 'payloadToTakeOut' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' || true)
G28_DART_N=$(printf '%s\n' "$G28_DART" | grep -c . || true)
if [ "$G28_DART_N" = "1" ] && printf '%s' "$G28_DART" | grep -q 'core/session_state.dart'; then
  pass "G28 one surface asks the core what may leave, and it is the order's own helper"
else
  fail "G28 the exit door is asked in $G28_DART_N place(s), expected one in core/session_state.dart:"
  printf '%s\n' "$G28_DART" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G26
# **Every press that writes the clipboard empties it first** — 081.
#
# The owner's root rule: «العمل دائماً يحدث على حافظة نظيفة». His 12 October
# leak was not something the app wrote, it was what the app *left*: a refusal
# at the exit wrote nothing, erased nothing, and the German letter he had
# copied minutes earlier was still there to be pasted into a model.
#
# «Clear it when the copy fails» is a branch, and a branch is a thing every
# refusal written from now on has to remember. So the emptying is one function,
# and this gate refuses any surface that writes the clipboard without calling
# it — the shape that let one door be fixed and four be forgotten.
CLIP_HOME=apps/flutter_app/lib/core/the_clipboard.dart
if [ ! -f "$CLIP_HOME" ]; then
  fail "G26 $CLIP_HOME is gone — the rule has no home, so it has no single copy"
else
  # One emptying in the whole interface, and it is in that file.
  EMPTYINGS=$(grep -Rn "ClipboardData(text: '')" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null               | grep -v '/src/rust/' || true)
  if [ "$(printf '%s\n' "$EMPTYINGS" | grep -c "^$CLIP_HOME:")" = "1" ] \
     && [ "$(printf '%s\n' "$EMPTYINGS" | grep -c .)" = "1" ]; then
    pass "G26 the clipboard is emptied in one place, and it is the rule's own file"
  else
    fail "G26 the emptying is written in more than one place, or not in $CLIP_HOME:"
    printf '%s\n' "$EMPTYINGS" | sed 's/^/        /'
  fi

  # And every surface that writes it calls that one function.
  WRITERS=$(grep -Rl 'Clipboard.setData' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
            | grep -v '/src/rust/' | grep -v "^$CLIP_HOME$" | sort || true)
  CLIP_BAD=""
  for f in $WRITERS; do
    # Either the surface empties it itself, or its write is reached through
    # `beginThenRead`, whose step 0 is the emptying and nothing above it. The
    # send sheet is the second kind: the order of an exit lives in the helper
    # all three exits share, where a guard can drive it, and the press is one
    # line that takes what it is handed.
    grep -qE 'emptyTheClipboardFirst|beginThenRead' "$f" || CLIP_BAD="$CLIP_BAD $f"
  done
  if [ -z "$CLIP_BAD" ]; then
    pass "G26 every surface that writes the clipboard empties it first ($(printf '%s' "$WRITERS" | grep -c .) seat(s))"
  else
    fail "G26 a surface writes the clipboard without emptying it first:"
    for f in $CLIP_BAD; do printf '        %s\n' "$f"; done
  fi
fi

# ---------------------------------------------------------------- G25
# A sentence a person reads is one line of prose, not a wrapped literal.
#
# 046/D, from the owner's own screen: the refusal for «this client» with no
# client open carried **nineteen spaces inside the sentence**, because the Rust
# literal was wrapped across two lines with no trailing «\» to eat the newline
# and the indentation.
#
# The sweep found three, not one: that refusal, the Why card's sentence for a
# protection whose reason no longer exists (two holes of eighteen spaces each),
# and the home screen's own line about what is uploaded — three spaces between
# two sentences, in Dart, on the first screen of the product. So the gate reads
# the hand-written Flutter code as well as the core: a sentence does not become
# truer for being written in another language.
if [ -f scripts/check_sentences.py ]; then
  if OUT=$(python3 scripts/check_sentences.py z_core/src "$FLUTTER_LIB" 2>&1); then
    pass "G25 no screen sentence carries a run of spaces"
  else
    fail "G25 a sentence has a hole in it:"; printf '%s\n' "$OUT" | sed 's/^/        /'
  fi
else
  skip "G25 no sentence carries a run of spaces" "no checker yet"
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

# ---------------------------------------------------------------- G4c
# **The same lint, for the platform nobody here runs.** A warning nobody can see
# is blindness later (the lead, 9 Oct): `use std::io::{Read, Write}` left `Read`
# unused on Windows for as long as that half existed, and no run on this machine
# could show it — on Linux the import is used and `-D warnings` has nothing to
# say. Compiling for the target found it in seconds, and found four more lints
# inside the one `unsafe` file, which had never been linted at all.
#
# `clippy`, not `check`, and `-- -D warnings` rather than `RUSTFLAGS`: that way
# the hardening lands on our crates and not on our dependencies, whose warnings
# are not ours to fix and would red this gate for somebody else's commit.
# Nothing is linked, so this costs seconds once the Windows dependencies are
# cached — and it answers the question the Windows workflow's first job asks,
# before anybody presses its button.
#
# Two preconditions, each with its own sentence: a skip that cannot say which
# tool is missing is a skip nobody acts on.
WIN_TARGET=x86_64-pc-windows-gnu
if ! rustup target list --installed 2>/dev/null | grep -qx "$WIN_TARGET"; then
  skip "G4c the Windows half compiles, warnings included" "no $WIN_TARGET (rustup target add $WIN_TARGET)"
elif ! command -v x86_64-w64-mingw32-gcc >/dev/null 2>&1; then
  skip "G4c the Windows half compiles, warnings included" "no cross C compiler (apt install gcc-mingw-w64-x86-64)"
elif cargo clippy --target "$WIN_TARGET" --workspace --all-targets $TEST_FEATURES --quiet -- -D warnings >/tmp/g4c.$$ 2>&1; then
  pass "G4c the Windows half compiles and lints clean, tests included"
else
  fail "G4c the Windows half does not compile or does not lint clean:"
  grep -E '^(error|warning)' /tmp/g4c.$$ | head -8 | sed 's/^/        /'
fi
rm -f /tmp/g4c.$$

# ---------------------------------------------------------------- G3, G6, G9, G10
# The invariants that live as tests.
if cargo test --workspace $TEST_FEATURES --quiet >/tmp/gt.$$ 2>&1; then
  pass "G3/G6/G9/G10/G11/G12 cargo test"
  # How many that was, summed over every binary and the doc-tests, for the
  # comparison at the foot of this script. Taken from the output already in
  # hand: running the suite twice to count it would double the slowest gate.
  RUST_PASSED=$(grep -oE '[0-9]+ passed' /tmp/gt.$$ | awk '{s+=$1} END {print s+0}')
else
  fail "cargo test:"; tail -30 /tmp/gt.$$ | sed 's/^/        /'
  # **Empty, not a number.** A suite that stopped half way counted half a tree:
  # «472 passed» out of an aborted run is not a smaller measurement, it is not a
  # measurement. Reported as a real count it produced a second red — against the
  # 568 written down — for a cause that was not its own, and a red that is
  # downstream of another red is noise in front of the one that matters.
  RUST_PASSED=""
fi
rm -f /tmp/gt.$$


# ---------------------------------------------------------------- G22
# The storage protection layer must be MEASURED on the platform you are on,
# not merely written for one. Nine named contracts: six on the vault's own file
# and, since 058, three on the folder it sits in. On Windows every one of them
# is `#[cfg(unix)]` and simply does not exist, so the suite there is smaller and
# still says «ok». A count of tests would drift as tests are added — these are
# asked for by name, and the script says how many it asked for.
if bash scripts/check_storage_contracts.sh >/tmp/g22.$$ 2>&1; then
  pass "G22 $(sed 's/\x1b\[[0-9;]*m//g' /tmp/g22.$$ | tail -1)"
else
  fail "G22 storage protection is not fully measured here:"
  sed 's/\x1b\[[0-9;]*m//g' /tmp/g22.$$ | grep -E "^  FAIL|contracts have no test" | sed 's/^/        /'
fi
rm -f /tmp/g22.$$

# ---------------------------------------------------------------- G7 (from Dart)
# The claim "no panic crosses the boundary" is only proven from the other side:
# call the whole contract from Dart and see typed errors come back.
LIB=apps/flutter_app/build/linux/x64/debug/bundle/lib

# ---------------------------------------------------------------- G7-lib
# The Dart half never tests this tree. It tests the library sitting in
# `build/`, and the two part company in silence: `libz_bridge.so` is an
# artefact that no checkout, rebase or applied patch touches, so a tree whose
# sources moved keeps answering through yesterday's binary.
#
# 13 Oct that cost 35 minutes of false red. The library had been built from the
# branch where `conversation_record` takes four arguments, over a tree where it
# takes two. Seven tests went red — each only after a five-minute Dart timeout
# — and the one line that named the cause («left: 18, right: 26», the SSE
# decoder counting the caller's bytes against the library's) sat twenty lines
# deep inside a test failure. Nothing here compared the two dates, so the only
# guard was a rule written down for humans, and that rule had already failed at
# three seats.
#
# The red direction is the cheap one. A stale library can equally answer GREEN
# for a tree that is broken, and then the suite signs a number belonging to no
# commit. So the library is not an environment detail, it is an input to the
# measurement: if anything under z_core/src or z_bridge/src is newer than the
# .so, the Dart half is not measured at all and this says so by name, rather
# than letting 297 tests speak for a tree that does not exist.
#
# `find -newer` compares the timestamps themselves — no clock arithmetic, no
# date parsing, no second-guessing. A source rewritten with identical bytes (a
# `git checkout` of an unchanged file) reds this too, and that is the direction
# to err in: a rebuild costs two minutes, a measurement of the wrong tree cost
# a day the last time it happened.
if [ -f "$LIB/libz_bridge.so" ]; then
  SOURCE_NEWER_THAN_LIB=$(find z_core/src bridges/native/z_bridge/src -type f \
                            -newer "$LIB/libz_bridge.so" -printf '%p\n' 2>/dev/null |
                          sort | head -3)
else
  SOURCE_NEWER_THAN_LIB=""
fi
if [ ! -f "$LIB/libz_bridge.so" ] || ! command -v flutter >/dev/null 2>&1; then
  skip "G7-dart contract callable from Dart" "run: cd apps/flutter_app && flutter build linux --debug"
  # Empty, never zero: «the Dart suite did not run here» and «the Dart suite
  # found nothing» must not be spelled the same.
  DART_PASSED=""
elif [ -n "$SOURCE_NEWER_THAN_LIB" ]; then
  fail "G7-lib the library the Dart half speaks through was NOT built from this tree: $LIB/libz_bridge.so is dated $(date -r "$LIB/libz_bridge.so" '+%d %b %H:%M') and the source beside it is newer — run: cd apps/flutter_app && flutter build linux --debug"
  printf '%s\n' "$SOURCE_NEWER_THAN_LIB" | while read -r f; do
    printf '        newer: %s  %s\n' "$(date -r "$f" '+%d %b %H:%M')" "$f"
  done
  # Refusing by name, not passing by silence: the suite is not run, because its
  # verdict would belong to another tree.
  skip "G7-dart contract callable from Dart" "the library does not belong to this tree, so its answer would not be about this tree"
  # The same emptiness, for the same reason as above: this run measured no Dart
  # number and must not be read as having measured one.
  DART_PASSED=""
else
  pass "G7-lib the library the Dart half speaks through was built from this tree"
  # **A red that says what failed.** The compact reporter rewrites one line, so
  # a log of it keeps only that line's last state: on 13 Oct seven failures came
  # back as one test's name and a RenderFlex dump from a file that had not
  # failed at all, and finding the seven took a second full run of the suite by
  # hand. `--file-reporter` writes every event beside it, and the log is kept
  # rather than deleted, because the evidence of a red is worth more than a
  # tidy /tmp.
  DART_LOG=/tmp/gd.$$
  DART_JSON=/tmp/gd-$$.json
  if (cd apps/flutter_app && LD_LIBRARY_PATH="$PWD/build/linux/x64/debug/bundle/lib" flutter test --concurrency=1 --reporter compact --file-reporter="json:$DART_JSON" >"$DART_LOG" 2>&1); then
    pass "G7-dart the whole contract answers from Dart without a panic"
    DART_GREEN=1
  else
    fail "G7-dart flutter test:"
    if [ -f scripts/dart_failures.py ] && [ -f "$DART_JSON" ]; then
      python3 scripts/dart_failures.py "$DART_JSON" | sed 's/^/        /'
    fi
    tail -20 "$DART_LOG" | sed 's/^/        /'
    printf '        the whole log: %s · every event: %s\n' "$DART_LOG" "$DART_JSON"
    DART_GREEN=
  fi
  # The compact reporter's own running total, last word it says — read before
  # anything is removed, because it is read out of the log itself.
  DART_PASSED=$(grep -oE '\+[0-9]+' "$DART_LOG" 2>/dev/null | tail -1 | tr -d '+')
  if [ -n "$DART_GREEN" ]; then rm -f "$DART_LOG" "$DART_JSON"; fi
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
# The German name bank: a signal for Person detection and never a verdict.
# Three things are checked here. The file must have the shape the loader
# expects — `--check` needs no network, so the owner's own CSV can be dropped
# in and checked the same way. Where the sources are on the machine, the bank
# is **rebuilt into a temp directory and compared byte for byte**, as the brand
# gate does, so a name cannot be edited into the file by hand. And the rule
# must never raise a word to Auto on the strength of a list of names: that is
# item B of his paper, and the test that holds it is named here so it cannot be
# deleted quietly.
if [ -f scripts/build_de_names.py ]; then
  if OUT=$(python3 scripts/build_de_names.py --check 2>&1); then
    pass "the name bank: $(echo "$OUT" | sed 's/^PASS  //')"
  else
    fail "the name bank: $(echo "$OUT" | head -2 | tr '\n' ' ')"
  fi
  if OUT=$(python3 scripts/build_de_names.py --rebuild-check 2>&1 | tail -1); then
    case "$OUT" in
      ----*) skip "  the bank is what the sources make" "$(echo "$OUT" | sed 's/^----  //')" ;;
      *) pass "  $(echo "$OUT" | sed 's/^PASS  //')" ;;
    esac
  else
    fail "  the bank is not what the sources and the script make"
  fi
else
  skip "the name bank" "no generator yet"
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
# 9 October: the owner took the downloads off the site altogether — «الموقعُ
# للتعريف ... لا تنزيلَ فقط تعريفٌ بالمنتج» — so the question this gate asks
# has a third honest answer: no file is offered at all. It still catches what it
# was written for, because it only asks about a page that offers a file.
if grep -rqE 'zprivacy-v1-[a-z0-9_.-]+\.(tar\.gz|exe)' site/*/index.html 2>/dev/null; then
  if grep -rq '{{WINDOWS_BUILD}}' site/*/index.html 2>/dev/null; then
    pass "  the download page names the build it is offering (unfilled, so unpublishable)"
  elif grep -rqE '>Build</p>' site/*/index.html 2>/dev/null; then
    pass "  the download page names the build it is offering"
  else
    fail "  the download page offers a file without naming the build it came from"
  fi
else
  pass "  the site offers no file, so there is no build for it to name"
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

# ------------------------------------------------- the Swedish supplement
# SV-16: ten pages of a Swedish research magazine, the owner's own file. The
# first Swedish document with a guard of its own, added with 038-B/2 — which was
# measured here and moved the numbers by name: auto 3 → 13 and people 27 → 36,
# five photographers who had been in the clear and four names offered beside
# what the person does. Not in the repository: a skip, not a pass.
SUPP="${ZPRIVACY_SWEDISH_SUPPLEMENT:-$HOME/Documents/framtidens-forskning-p1-10.pdf}"
if [ -f "$SUPP" ]; then
  if cargo test --quiet --test the_swedish_supplement >/dev/null 2>&1; then
    pass "the Swedish supplement: the credits are protected, the captions are not"
  else
    fail "the Swedish supplement: the credits are protected, the captions are not (cargo test --test the_swedish_supplement)"
  fi
else
  skip "the Swedish supplement: the credits are protected, the captions are not" "the supplement is not on this machine"
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
         a_three_page_document_hands_over_two_edges a_token_moves_every_edge_after_it \
         a_swallowed_break_does_not_renumber_the_pages \
         the_payload_is_what_it_was_before \
         a_taught_name_is_found_in_every_case a_longer_lowercase_does_not_move_the_span \
         protecting_every_place_is_case_blind_too a_lowercase_word_is_still_not_a_name \
         full_case_folding_is_not_claimed \
         a_surname_broken_at_a_line_end_is_one_name what_it_finds_it_can_find_again \
         a_value_without_a_hyphen_is_not_found_across_a_real_one \
         the_pair_rule_reads_across_a_wrapped_line \
         the_pair_rule_does_not_read_across_a_page \
         two_words_on_two_lines_are_still_two_words \
         a_photo_credit_is_a_person_without_being_asked a_caption_is_not_a_credit \
         a_role_beside_a_name_is_offered_not_decided \
         the_column_shows_what_the_page_did_to_the_names \
         discovery_is_still_blind_to_a_break the_german_pack_reads_none_of_this \
         the_credits_are_protected_and_the_captions_are_not \
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
         a_string_drawn_before_a_font_is_chosen_is_counted_not_invented \
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
         a_name_whose_given_half_was_unknown_is_found_now \
         a_person_answers_twice_and_a_whole_document_is_understood \
         a_swedish_letter_is_read_by_a_pack_that_is_only_data \
         english_is_installed_and_carries_its_names \
         the_films_english_letter_is_read_by_a_pack_of_english_words \
         an_english_company_ends_in_its_legal_form \
         a_document_with_no_names_offers_nobody \
         an_english_surname_that_ends_in_son_is_offered \
         the_other_two_packs_did_not_move \
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
         never_mentions_are_counted codes_with_no_characters \
         the_same_value_now_keeps_its_token_the_next_day \
         an_answer_from_another_conversation_is_reported_and_not_passed_through \
         something_that_is_not_a_token_is_not_reported \
         the_same_session_gives_the_same_token_days_apart \
         two_sessions_do_not_share_a_name_for_the_same_value \
         two_clients_in_one_session_now_share_a_name \
         another_document_in_the_same_session_keeps_the_name \
         an_edited_document_keeps_its_name_inside_the_session \
         without_a_vault_the_name_is_random_again \
         an_answer_from_monday_restores_on_friday \
         the_same_name_in_two_sessions_takes_two_tokens \
         the_same_name_in_two_documents_of_one_session_takes_one_token \
         an_answer_from_a_deleted_session_refuses_and_names_it \
         a_session_survives_the_vault_being_locked \
         a_long_conversation_does_not_grow_the_vault \
         every_token_that_leaves_belongs_to_the_session \
         the_reader_sees_a_turn_the_old_door_wrote \
         a_question_sent_through_the_key_is_written_into_the_session \
         a_document_sent_with_no_question_still_leaves_a_turn \
         the_direct_door_writes_what_it_sent_as_it_sent_it \
         an_answer_brought_back_from_outside_is_written_too \
         a_stored_turn_restores_only_what_its_payload_carried \
         a_session_read_without_a_bench_reads_itself_back \
         a_send_with_no_session_open_is_not_refused_today \
         a_version_one_file_reads_with_no_allowed_list \
         the_saved_files_and_the_vault_do_not_share_a_folder \
         each_fence_falls_when_a_value_is_planted_in_it \
         the_language_a_session_was_born_into_outlives_the_application \
         a_session_born_with_no_document_has_never_been_asked \
         changing_the_language_in_the_header_reaches_the_open_session \
         a_session_from_model_twelve_has_never_been_asked_its_language \
         the_first_document_of_a_session_born_without_one_writes_its_language \
         switching_to_the_language_a_bench_already_has_still_writes_it \
         a_format_two_turn_names_no_key_and_says_so \
         a_turn_remembers_which_key_and_model_answered_it \
         an_answer_the_person_carried_says_the_person_carried_it \
         a_session_holding_both_kinds_of_turn_keeps_them_apart \
         a_format_three_turn_was_about_a_file_it_cannot_name \
         a_turn_remembers_which_file_it_was_about \
         text_the_person_typed_says_there_was_no_file \
         the_report_still_names_no_file_though_the_session_knows_it \
         a_reopened_session_reads_its_own_history_back \
         a_token_the_payload_never_allowed_stays_a_token \
         every_protected_word_comes_back_when_the_document_opens_again \
         a_language_written_with_no_document_open_is_the_one_the_document_is_read_with \
         a_language_this_build_does_not_know_is_refused_by_name \
         an_answer_from_another_session_names_every_token_and_restores_none \
         a_handle_or_an_answer_of_another_session_is_refused \
         a_token_this_payload_did_not_allow_stays_unknown_in_its_own_session \
         no_text_leaves_while_a_word_waits \
         every_door_that_takes_text_out_refuses_with_the_same_number \
         the_refusal_carries_the_number_of_words_waiting \
         the_word_answered_the_exit_opens \
         the_column_the_person_reads_while_answering_still_builds \
         an_iban_is_the_number_and_not_the_words_after_it \
         a_bank_value_carries_no_word_of_prose \
         an_iban_in_a_footer_line_stops_before_the_next_label \
         the_bic_in_a_footer_line_is_read_as_a_bic \
         the_rest_of_the_letter_did_not_move \
         a_swedish_letter_is_never_told_its_words_are_german \
         a_company_form_belongs_to_the_language_that_lists_it \
         a_salutation_belongs_to_the_language_that_lists_it \
         the_name_dictionary_counts_the_names_it_actually_holds \
         no_reason_names_a_language_the_document_is_not_read_with \
         ltd_is_called_an_english_legal_form \
         text_typed_in_arrives_scanned a_text_file_arrives_scanned \
         a_word_file_arrives_scanned a_pdf_arrives_scanned \
         a_second_document_in_the_same_session_arrives_scanned_too \
         a_value_the_vault_knows_comes_back_protected_and_is_never_asked_about \
         an_empty_import_is_not_a_refusal \
         a_pdf_whose_headers_stand_on_their_own_lines_is_read \
         the_object_keyword_is_never_found_inside_endobj \
         a_page_tree_packed_in_an_object_stream_is_read_whatever_its_spacing \
         a_document_typed_or_pasted_back_keeps_its_tokens \
         a_text_file_coming_back_keeps_its_tokens \
         a_word_file_coming_back_keeps_its_tokens \
         a_pdf_coming_back_keeps_its_tokens \
         a_rescan_does_not_find_a_token_either \
         a_hand_over_a_token_is_told_it_is_already_protected \
         the_same_conversation_reads_every_name_back \
         every_protected_name_comes_back_after_the_bench_is_gone \
         the_answer_page_proves_the_origin_on_its_own \
         with_the_vault_shut_nothing_is_named_and_nothing_is_called_unknown \
         a_document_from_another_machine_says_so \
         two_namespaces_are_two_conversations \
         the_door_only_reads \
         an_ordinary_document_is_not_one \
         the_door_back_reads_a_file_with_no_bench_of_its_own \
         the_door_back_brings_a_taught_value_back_after_the_bench_is_gone \
         the_door_back_reads_a_pdf_and_a_text_file_the_same_way \
         the_door_back_leaves_the_bench_and_the_vault_untouched \
         a_locked_vault_leaves_the_door_back_standing \
         a_file_the_door_back_cannot_read_is_refused_by_name \
         every_name_comes_back_after_a_restart \
         nothing_deletes_a_block \
         leave_it_makes_no_block \
         a_block_is_protected_in_another_conversation \
         an_exemption_belongs_to_one_conversation \
         the_blocks_are_counted_and_never_valued \
         the_door_back_makes_no_block \
         one_press_exempts_every_block_the_selection_spans \
         here_uncovers_every_place_the_selection_spans \
         a_block_of_two_words_stays_one_token_elsewhere \
         the_preview_survives_a_restart_with_its_decisions \
         the_copy_follows_every_decision \
         a_second_document_takes_the_next_number \
         going_back_keeps_it \
         the_manual_door_takes_it_out \
         the_send_door_takes_it_out \
         the_model_door_takes_it_out \
         the_direct_door_takes_it_out \
         rename_changes_the_name_and_not_the_number \
         a_session_begun_by_hand_keeps_the_open_document \
         an_older_session_holds_none \
         the_first_document_of_a_new_session_is_kept_and_listed \
         a_chat_in_a_new_session_is_kept_as_chat1 \
         a_session_of_documents_only_is_named_by_its_number \
         the_first_number_is_retired_at_every_door \
         nothing_is_born_without_a_document \
         a_document_is_in_one_session_at_a_time \
         a_saved_document_keeps_its_decisions \
         a_format_four_file_holds_no_saved_document \
         a_block_keeps_its_tokens_and_its_exemptions \
         a_block_crosses_from_one_client_to_another \
         a_blocks_card_says_no_where_and_no_when \
         forget_everywhere_exempts_every_profile_and_keeps_the_block \
         forget_from_this_profile_exempts_that_client_only \
         a_forgotten_word_still_comes_back_from_an_old_document \
         every_door_that_forgets_a_word_exempts_its_blocks \
         nothing_short_of_teaching_it_again_undoes_a_forget \
         a_document_that_arrives_with_the_vault_shut_has_no_session; do
  if grep -Rqs "fn .*$t" z_core/tests z_core/src 2>/dev/null; then
    pass "  test present: $t"
  else
    fail "  test MISSING: $t (renamed, or deleted — this roster is not a wish list)"
  fi
done

# ---------------------------------------------------------------- the owed list
# **«Not written yet» is a declaration, never a silence** — the lead's ruling,
# 9 October 2026, and the reason the loop above now fails.
#
# It used to `skip` for a name it could not find, so «we have not got to it» and
# «somebody renamed it» read identically — and when 064 renamed three tests, the
# gate stopped measuring three properties and said «not written yet» about tests
# that existed. Absence was being read as progress. That is the same family as an
# overflow counter that cannot rise, and as a check that prints PASSED because the
# words «FAILED» are absent from an empty log.
#
# So a test that is genuinely owed is declared **here**, by name, with the number
# of the paper that owes it. The list is empty today, and an empty list is the
# honest state: every name in the roster above exists. When something appears
# here it carries its debt in writing, and when it is written it moves up.
#
#   OWED="the_name_of_the_test:071 another_one:072"
OWED=""
for entry in $OWED; do
  [ -z "$entry" ] && continue
  t=${entry%%:*}
  paper=${entry#*:}
  if grep -Rqs "fn .*$t" z_core/tests z_core/src 2>/dev/null; then
    pass "  owed test now written: $t (paper $paper) — move it up into the roster"
  else
    printf '  \033[33mOWED\033[0m  %s\n' "test not written yet: $t — owed by paper $paper"
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
         "two edges in both columns" "moves the other, and Apart stops it" \
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
         "never inherits the last one" \
         "takes that line, and the core says what is in it" \
         "protects that cell in every held line" \
         "between two columns says why" \
         "a wrapped row still presses the cell" \
         "carries the column act, so no press is wasted" \
         "another conversation says so, by name, above the answer" \
         "own answer restores with nothing said" \
         "puts nothing out while a word waits" \
         "the exits are pressable while a word waits" \
         "the first waiting word in reading order" \
         "closes the sheet and says it where the word is"; do
  if grep -Rqs -- "$t" apps/flutter_app/test 2>/dev/null; then
    pass "  screen test present: $t"
  else
    skip "  screen test present: $t" "not written yet"
  fi
done

# ------------------------------------------------- the line Windows is compared against
# `docs/MEASURED_ON_LINUX.txt` is what the Windows job prints as «what Linux
# says». Three numbers used to be typed into the workflow itself, where they sat
# for a month naming an older commit. They live in one file now, the merging
# hand writes them, and this compares them with what this run measured.
#
# Two of the three are compared. `gates` is not: the Rust and Dart counts belong
# to the tree, while the number of checks a run prints belongs to the machine —
# the owner's golden documents, clippy and flutter each turn a measurement into
# a skip with the tree untouched. Every precondition below is its own assertion
# with its own reason, so a red here can only mean the one thing it says.
NUMBERS=docs/MEASURED_ON_LINUX.txt
if [ ! -f "$NUMBERS" ]; then
  fail "the numbers Windows is compared against: $NUMBERS is missing"
else
  WANT_RUST=$(awk '/^  rust[[:space:]]/ {print $2}' "$NUMBERS")
  WANT_DART=$(awk '/^  dart[[:space:]]/ {print $2}' "$NUMBERS")
  if [ -z "$WANT_RUST" ] || [ -z "$WANT_DART" ]; then
    fail "the numbers Windows is compared against: $NUMBERS has no «rust» or «dart» line"
  elif [ -z "$RUST_PASSED" ]; then
    skip "the numbers Windows is compared against" "the Rust suite did not finish, so its count is not a measurement"
  elif [ "$RUST_PASSED" -eq 0 ]; then
    fail "the numbers Windows is compared against: the suite finished and counted no tests at all"
  elif [ "$RUST_PASSED" != "$WANT_RUST" ]; then
    fail "the numbers Windows is compared against: this tree runs $RUST_PASSED Rust tests, $NUMBERS still says $WANT_RUST (the merging hand writes it)"
  elif [ -z "$DART_PASSED" ]; then
    pass "the numbers Windows is compared against: Rust $RUST_PASSED as written"
    skip "  and the Dart half" "the suite did not run here, so its number was not checked"
  elif [ "$DART_PASSED" != "$WANT_DART" ]; then
    fail "the numbers Windows is compared against: this tree runs $DART_PASSED Dart tests, $NUMBERS still says $WANT_DART (the merging hand writes it)"
  else
    pass "the numbers Windows is compared against: Rust $RUST_PASSED and Dart $DART_PASSED, both as written in $NUMBERS"
  fi
fi

echo
echo "$CHECKS checks, $FAILS failed, $SKIPS skipped"
if [ "$FAILED" -eq 0 ]; then
  echo "all gates passed"
else
  echo "GATES FAILED"
fi
exit "$FAILED"
