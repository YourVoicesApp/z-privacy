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
if ( set +o pipefail; grep -A3 '^\[features\]' z_core/Cargo.toml | grep -q '^default = \[\]' ); then
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
if [ "$G27_N" = "1" ] && grep -q 'core/session_state.dart' <<< "$G27_READS"; then
  pass "G27 the app's language is read in one place, and it is the ground's own function"
else
  fail "G27 the config's pack is read in $G27_N place(s), expected one in core/session_state.dart:"
  printf '%s\n' "$G27_READS" | sed 's/^/        /'
fi

# **And every door that reads a text in a session asks the one hand** — 080,
# and rule 57-د since 17 October.
#
# It used to count the mentions of `packForTheNextText` in `shell.dart` and
# pass at two or more. That measured the old shape: two doors, each reading the
# fallback for itself. Rule 57-د puts the asking in one place —
# `_theLanguageOfTheTextToCome` — because an old session with no language of its
# own must be **asked**, once, and the answer written into it; and the fourth
# door, `_openKept`, was reading the fallback on its own, so a session from
# before 080 had its kept documents read with the application's eye for ever.
#
# So the doors are enumerated **from what they do**: a method of the shell that
# reads a text into a session is one, whatever it is called, and each must ask.
# A fifth door added tomorrow is counted the day it is written.
G27_DOORS=$(awk '
  /^  (Future<[^>]*>|void) [_A-Za-z]+\(/ { name = $0; sub(/^  /, "", name); sub(/\(.*/, "", name);
                                          inside = 1; reads = 0; asks = 0 }
  inside && /z\.importText\(|z\.importDocument\(|z\.openKeptDocument\(/ { reads = 1 }
  inside && /_theLanguageOfTheTextToCome\(/ { asks = 1 }
  inside && /^  \}/ { if (reads) print (asks ? "asks" : "SILENT") " " name; inside = 0 }
' "$FLUTTER_LIB/screens/shell.dart" 2>/dev/null || true)
G27_SILENT=$(printf '%s\n' "$G27_DOORS" | grep -c '^SILENT' || true)
G27_ASKS=$(printf '%s\n' "$G27_DOORS" | grep -c '^asks' || true)
# **Two, since rule 70, and the number is read rather than remembered.** It was
# three: `_begin`, `_openKept` and `_askFromHome` — the first screen's own chat,
# which read a question into a session of its own. That screen is gone with the
# rule, so the count came down by a door, and taking one away moves this line as
# surely as adding one would (the same arithmetic rule 62 taught G36 on 17
# October). The doors are still enumerated from what they do, so a third one
# written tomorrow is counted the day it is written.
if [ "$G27_SILENT" = "0" ] && [ "$G27_ASKS" -ge 2 ]; then
  pass "G27 all $G27_ASKS doors that read a text in a session take its language from one hand"
else
  fail "G27 $G27_SILENT door(s) read a text in a session without asking the one hand (and $G27_ASKS do ask; two are known):"
  printf '%s\n' "$G27_DOORS" | sed 's/^/        /'
fi

# **«Nobody has said» is an answer the type can hold** — rule 57-د.
#
# `packForTheNextText` returned a `String` and ended `?? appLanguage(ground)`,
# so an old session's silence was spelled as the application's language and no
# caller could tell the two apart. It answers `String?` now, and `null` means
# «ask». The signature is the measurement, because a build that puts the
# fallback back has to delete the `?` to do it.
if grep -q 'String? packForTheNextText(Ground ground)' "$FLUTTER_LIB/core/session_state.dart" 2>/dev/null; then
  pass "G27 the language of the next text can answer «nobody has said»"
else
  fail "G27 packForTheNextText no longer answers String? — an unchosen language is being spelled as a chosen one"
fi

# And one reader of it, which is the hand: a second reader is a second place
# where «nobody has said» could quietly become the application's language.
G27_READERS=$(grep -Rn 'packForTheNextText(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
              | grep -v '/src/rust/' | grep -vE ':[0-9]+: *//' \
              | grep -v 'String? packForTheNextText' || true)
G27_RN=$(printf '%s\n' "$G27_READERS" | grep -c . || true)
if [ "$G27_RN" = "1" ] && grep -q 'screens/shell.dart' <<< "$G27_READERS"; then
  pass "G27 one reader asks for the language of the next text, and it is the hand that also asks the person"
else
  fail "G27 the language of the next text is read in $G27_RN place(s), expected one in screens/shell.dart:"
  printf '%s\n' "$G27_READERS" | sed 's/^/        /'
fi

# **And the door back asks no language at all** — 079 rule 3. It reads a
# protected file into its own names, takes no session and scans nothing, so a
# question there would be a question about nothing.
G27_BACK=$(awk '
  /^  (Future<[^>]*>|void) [_A-Za-z]+\(/ { inside = 1; back = 0; asks = 0 }
  inside && /readADocumentThatCameBack\(/ { back = 1 }
  inside && /_theLanguageOfTheTextToCome\(|packForTheNextText\(/ { asks = 1 }
  inside && /^  \}/ { if (back) print (asks ? "ASKS" : "silent"); inside = 0 }
' "$FLUTTER_LIB/screens/shell.dart" 2>/dev/null || true)
if [ "$G27_BACK" = "silent" ]; then
  pass "G27 the door back reads a file with no language asked of anybody"
elif [ -z "$G27_BACK" ]; then
  fail "G27 no door back found in shell.dart — this check measures nothing"
else
  fail "G27 the door back asks for a language ($G27_BACK): it takes no session, so there is nothing for an answer to belong to"
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
#
# **The fourth seat, 18 Oct, and this gate is what asked for it.** The attacker's
# B1-3: `payload.rs` — the exit audit, where a protected value's places are
# counted. A token spells its kind in capital letters, so a plain count found
# «IBAN» inside every account this document protected and refused every door.
# It is a different act over the same fact: not «a token is not a candidate»
# but «a token is not a place a value stands». One call there, over both texts
# at once, because the two sides of a bound measured by two expressions are how
# they drift apart.
SCANNER=z_core/src/scanner/mod.rs
TOKENS=z_core/src/tokens.rs
G31_SEATS="scanner/mod.rs ops/mod.rs returning.rs payload.rs"
G31_CALLS=$(grep -Rn 'token_spans(' z_core/src --include='*.rs' | grep -v 'fn token_spans' || true)
G31_N=$(printf '%s\n' "$G31_CALLS" | grep -c . || true)
G31_BAD=""
for seat in $G31_SEATS; do
  HOW_MANY=$(printf '%s\n' "$G31_CALLS" | grep -c "$seat:" || true)
  [ "$HOW_MANY" = "1" ] || G31_BAD="$G31_BAD $seat($HOW_MANY)"
done
if [ "$G31_N" = "4" ] && [ -z "$G31_BAD" ]; then
  pass "G31 where the tokens stand is asked in four named places, once each"
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
  elif ! grep -q 'a_token_already_stands_there(' <<< "$BODY"; then
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
if [ "$G32_DART_N" = "1" ] && grep -q 'core/session_state.dart' <<< "$G32_DART"; then
  pass "G32 one surface asks whether a document came back, and it is the bench"
else
  fail "G32 the returning-document door is asked in $G32_DART_N place(s), expected one in core/session_state.dart:"
  printf '%s\n' "$G32_DART" | sed 's/^/        /'
fi

# The sentence for that state is written once: one state, one wording (046/L).
# Comments may quote it — the doc comment above it explains the wording, and a
# gate that could not read that would be a gate against explaining.
# **And the generated list is not a second place** — 092. The sentence is a key
# in `lib/l10n/*.arb` now, and `flutter gen-l10n` writes one Dart class per
# language from it: three files that hold the same sentence by construction,
# none of them written by hand. What this gate is about is a **second decision**
# about the wording, so it reads the hand-written tree and the one list's key —
# the generated classes are the list, not an opinion beside it.
G32_SAID=$(grep -Rn "already protected — Z put it there" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' | grep -v '/l10n/' | grep -vE ':[0-9]+:[[:space:]]*//' || true)
G32_KEYED=$(grep -c 'theTokenIsAlreadyOurs' apps/flutter_app/lib/l10n/app_en.arb 2>/dev/null || echo 0)
G32_SAID_N=$(printf '%s\n' "$G32_SAID" | grep -c . || true)
if [ "$G32_SAID_N" = "0" ] && [ "$G32_KEYED" != "0" ]; then
  pass "G32 «this is already protected — Z put it there» is worded in one place: the one list"
elif [ "$G32_SAID_N" = "1" ] && grep -q 'core/messages.dart' <<< "$G32_SAID"; then
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
elif ! grep -q "^$FLUTTER_LIB/core/messages.dart$" <<< "$G33_FILES"; then
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
# **And the generated list is not one of them** — 092: `gen-l10n` writes
# `supportedLocales` from the three ARB files themselves, so that array **is**
# the one list in another shape, and it is not written by hand. G50/G51 are
# what keep the three files in step; this gate stays about a second list
# somebody typed.
G38_LITERALS=$(grep -RnE "\['de',\s*'en'|\[\"de\",\s*\"en\"" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
               | grep -v '/src/rust/' | grep -v '/l10n/' | grep -v "^$LANGS:" || true)
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
# **One reader since rule 70**, and it was two: the second was the first
# screen's own tally, which drew the app's pack beside the vault's count, and
# both went with the screen. What is left is `packForTheNextText`, which answers
# for a session that exists and has no language of its own (080, rule 33) — and
# that one reader is the whole of what this check is for.
if [ "$G38_APP" = "core/session_state.dart" ]; then
  pass "G38 the application's language is read in one place, and nowhere a session is born"
else
  fail "G38 «appLanguage» is read in «$G38_APP» — expected core/session_state.dart only (rule 57c)"
fi

# **Every door a text enters by asks first.** The doors are the imports (G37's
# own census) **and the way back to a kept document**; each must reach the one
# function that answers «which language», and that function is the only place
# the fallback is read.
#
# **`_openKept` joined them on 17 October, rule 57-د.** It read the language
# straight from `packForTheNextText`, which answered for a session created
# before 080 with the application's — so an old session's kept documents came
# back read with the wrong eye, for ever, and nobody was asked.
#
# **And `_askFromHome` left them the same day** — rule 70: it read the first
# screen's own question into a session of its own, and that screen is gone.
#
# **`_askWithNoDocument` joined them on 18 October, rule 72.** The one box is
# in the first part now and what is written in it with no document open is a
# question that opens a session of its own — a session about to be born, which
# is exactly the state rule 57b's one question is for. It imports nothing, and
# that is why it is a door all the same: the scanner reads the question, and it
# needs a language before it reads a word.
#
# Three doors named here by hand, and G27 enumerates them from what they do, so
# a fourth one written tomorrow is caught by the gate that counts rather than
# by the gate that remembers.
G38_QUIET=""
for door in _askWithNoDocument _begin _openKept; do
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
if [ -z "$G38_QUIET" ] && [ "$G38_ASKS" = "_askWithNoDocument _begin _openKept" ]; then
  pass "G38 both doors a text enters by ask which language before anything is read"
else
  fail "G38 these doors read a text without asking:$G38_QUIET (asked from «$G38_ASKS», expected «_askWithNoDocument _begin _openKept»)"
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
# **By the key and not by the English** — 092. This read `/Taught on/`, and
# the day that sentence moved into the one list the gate stopped finding
# anything and reddened on a claim that was still true. The claim is about the
# **order** — the condition before the row — so the key is as good a name for
# the row as its wording was, and it is one that survives being read in German.
if awk '
  /learnedAt > BigInt.zero/ { asked = NR }
  /sentences\.taughtOnRow/ { said = NR }
  END { exit(asked && said && asked < said ? 0 : 1) }
' apps/flutter_app/lib/widgets/why_sheet.dart; then
  pass "G39 the glass draws «Taught on» only where there is something to draw"
else
  fail "G39 the Why sheet can draw a date row for a word nobody taught (rule 58)"
fi

# **No where.** A block's claimant is a stand-in the core writes where an
# identity would stand; it reaches the glass as a count and never as a word.
# **And the `.arb` files with them** — 092: a sentence's home is the one list,
# so a check that a phrase is in **no** sentence has to read the list or it is
# looking where sentences used to be.
G39_HANDLE=$(grep -Rn "a word you protected" "$FLUTTER_LIB" --include='*.dart' --include='*.arb' 2>/dev/null | tr '\n' ' ')
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

# **Every door, enumerated from what it does — and the census is re-made from
# the source, never from the names this round remembers.**
#
# **The attacker's م6, 17 October:** `delete_entity` took an identity out of the
# vault and left its blocks working, while the dialog promised «the next
# document will not recognise these values again». It was invisible to this
# gate because the gate read three collections by name —
# `values|taught_names|aliases` — and an identity lives in a fourth. A census
# written from the names we know finds the doors we know.
#
# So the shape of the act is what is counted: **a removal verb on a collection
# that holds the person's knowledge**. Both lists are written here, so a new
# collection and a new verb are each a change somebody has to make on purpose.
# The verbs were read off the source first: `retain` is the only one in use,
# and the other six are named so that the day one of them appears it is counted
# rather than discovered by an attacker.
G40_VERBS='retain|remove|swap_remove|pop|drain|clear|truncate'
G40_KNOWS='entities|values|aliases|taught_names|exceptions|label_rules|lists|profiles'
G40_CENSUS=$(awk -v verbs="$G40_VERBS" -v knows="$G40_KNOWS" '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  $0 ~ "(" knows ")[[:space:]]*\\.[[:space:]]*(" verbs ")\\(" { if (here != "") print here }
' "$G40_OPS" | sort -u)
G40_DRY=""
for door in $G40_CENSUS; do
  # **The named exceptions, and the reason each one is not a door.** Each is
  # read from what the act does to a *word*, which is the only thing a block
  # can be about:
  #
  #   * `forget_user_name` presses two of the other doors (`forget_name` for
  #     the dictionary row, `delete_value` for the «always» twin), and both
  #     exempt. Its own `values.retain` takes the twin of the very word
  #     `forget_name` has just exempted.
  #   * `forget_exception` removes a permission to leave a word **in the
  #     clear**. Taking it back protects more, never less: no word leaves the
  #     vault's knowledge, so there is nothing to exempt.
  #   * `forget_label_rule` removes a rule about the word *before* a value
  #     («Mail:», «Kundennummer:»). The label is never the protected word, and
  #     never took a token.
  #   * `move_user_list` carries every name from one list to another and then
  #     drops the row the names left behind, «because an empty list is not a
  #     list». Not one name leaves the vault's knowledge — each is still
  #     taught, under another language — so there is nothing to exempt. This
  #     one was found **by this census**, not by the list of doors the round
  #     began with, which is the whole reason the census is re-made from the
  #     shape of the act.
  case "$door" in
    forget_user_name) want='forget_name[(]|delete_value[(]' ;;
    forget_exception|forget_label_rule|move_user_list) want='' ;;
    *) want='forget_the_blocks_of[(]' ;;
  esac
  [ -z "$want" ] && continue
  # The bracket form, not a backslash: `awk -v` reads escape sequences, so
  # `\(` would arrive as a bare `(` and the regexp would not compile.
  if ! awk -v door="$door" -v want="$want" '
    $0 ~ "^(pub\\(crate\\) )?fn " door "\\(" { inside = 1; next }
    inside && $0 ~ want { found = 1 }
    inside && /^}/ { inside = 0 }
    END { exit(found ? 0 : 1) }
  ' "$G40_OPS"; then
    G40_DRY="$G40_DRY $door"
  fi
done
G40_DOORS=$(printf '%s\n' "$G40_CENSUS" | tr '\n' ' ' | sed 's/ $//')
G40_N=$(printf '%s\n' "$G40_CENSUS" | grep -c . || true)
if [ -z "$G40_DRY" ] && [ "$G40_N" -ge 9 ]; then
  pass "G40 all $G40_N places that take knowledge out of the vault answer for their blocks: $G40_DOORS"
else
  fail "G40 these take a word out of the vault and leave its blocks working:$G40_DRY (census of $G40_N: $G40_DOORS)"
fi

# **And the mark is written only once the act cannot be refused.** An exemption
# is one-way (nothing takes one back but teaching the word again), and
# `Vault::with_open_mut` does not roll the vault back when its closure returns
# `Err` — the change stays in memory and the next successful write seals it. So
# a door that can still refuse *after* it has exempted a word would make a
# refused press permanent, and an unknown identity reads as «no profile», which
# is the widest reach of the three. Found by the lead on `623f9b7` in
# `remove_value_alias`, and read as an order here rather than trusted.
G40_LATE=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3); act = 0; late = 0 }
  here != "" && /forget_the_blocks_of\(/ { act = NR }
  here != "" && act && /return Err\(|ok_or\(|ok_or_else\(/ { late = NR }
  /^}/ { if (here != "" && act && late) printf "%s ", here; here = "" }
' "$G40_OPS" | sed 's/ $//')
if [ -z "$G40_LATE" ]; then
  pass "G40 no door exempts a word and can then refuse the act, so a refused press writes nothing"
else
  fail "G40 these doors mark the blocks and can still refuse afterwards, which makes a refused press permanent: $G40_LATE"
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
# ---------------------------------------------------------------- G41
# **The container on the glass is a «session», never a «conversation»** — rule
# 55-هـ, the owner, 17 October 2026.
#
# Rule 55 made the session the thing that holds the work — a session is born at
# its first document and keeps it — and the screens went on calling it a
# conversation in twenty-odd sentences, some of them beside the word «session»
# in the same card. One thing with two names on one glass is a product a person
# has to translate before they can read it.
#
# **What the word still means where it stays:** «conversation» is what was
# written to the AI and what came back. Those sentences name the session beside
# it, as the thing that keeps the exchange — which is exactly the distinction
# this gate is here to hold open.
#
# It reads **string literals only**, with a scanner that tracks whether a quote
# is open across lines, because a grep for the word in this tree answers with a
# hundred identifiers — `conversation_begin`, `Scope::Conversation`,
# `open_conversation` — and those are code, not sentences. Comments may say
# whatever they need to: they explain where a rule came from, and a comment that
# cannot name the old word cannot record the rename.
G41_SCAN='
FNR == 1 { inside = 0 }
{
  line = $0
  if (line ~ /^[[:space:]]*(\/\/|\/\*|\*)/) next
  gsub(/\\./, "", line)
  n = split(line, p, Q)
  for (i = 1; i <= n; i++) {
    state = (i % 2 == 1) ? inside : !inside
    if (state && p[i] ~ /[Cc]onversation/) print FILENAME ":" FNR ": " p[i]
  }
  quotes = (n > 0) ? n - 1 : 0
  if (quotes % 2 == 1) inside = !inside
}'

# **The allowed list, and the reason for every line of it.**
#
#   1. **`home.dart`'s two and `the_journey.dart`'s one are gone** — rule 70, 17
#      October. They were «This session keeps its conversation, sealed in your
#      vault», «No session is open — nothing of this conversation is kept» and
#      «Nothing of this conversation is written anywhere: a session is what
#      keeps one, and none is open»: the first screen's own line about what it
#      kept, and the journey's. Both files are deleted with the screen, so the
#      exceptions go with them — and this list's own staleness check below is
#      what would have said so if they had been left here.
#
#      **What that leaves owed, in writing**: «an answer no session could
#      keep» is a real state (no vault, so no key to seal one with) and the
#      journey was where the app said so. The chat panel is where it belongs
#      now — paper 090 B3 — and this is the note that it is not said anywhere
#      while that panel is unbuilt.
#   2. `settings.dart` — «there are no sessions to show … the conversations
#      themselves were never in it»: the rows and their keys are in the vault,
#      the exchanges never were. Both words, each about its own thing.
#   3. the import path of `conversation_view.dart`, in two files: a file name is
#      not a sentence, and the widget keeps the name of what it draws — the
#      turns of an exchange.
#   4. the two widget keys `the-conversation` and `open-this-conversation`: a
#      key is read by a guard and never by a person.
#   5. `session.rs`'s `.field("conversation", …)`: the label of a field in a
#      `Debug` dump, which no screen shows.
#
# **A phrase and not a line number**, so the list does not rot as files move —
# and if somebody re-wraps one of these sentences the gate reds and the line has
# to be justified again, which is the pressure this list exists to apply.
G41_ALLOWED='the conversations themselves were never in it\.
package:zprivacy/widgets/conversation_view\.dart
: the-conversation$
: open-this-conversation$
session\.rs:[0-9]+: conversation$'
# One line each, joined into one expression — and read back line by line below,
# which is why no line of it may carry a «|» of its own.
G41_ALLOW=$(printf '%s' "$G41_ALLOWED" | paste -sd'|' -)

# **Both quote characters, since the attacker's ن15.** His note named
# `InvalidSession` «saying conversation about a session» — true of the build he
# attacked (`5f5bef1`, `messages.dart:62`) and already closed by rule 55-هـ in
# the merge, which is measurable: `git show 5f5bef1:…` has the old word and
# this tree has «That session is no longer open». So nothing escaped this gate.
# What the note did show is a door it could have escaped by: this scan read
# `'…'` only, and Dart takes `"…"` just as happily. One sentence in the other
# quote would have been invisible. There is none today — measured — and now
# there cannot be one.
G41_DART=$(find "$FLUTTER_LIB" -name '*.dart' -not -path '*/src/rust/*' | sort \
           | xargs awk -v Q="'" "$G41_SCAN" 2>/dev/null || true)
G41_DART2=$(find "$FLUTTER_LIB" -name '*.dart' -not -path '*/src/rust/*' | sort \
            | xargs awk -v Q='"' "$G41_SCAN" 2>/dev/null || true)
G41_DART=$(printf '%s\n%s\n' "$G41_DART" "$G41_DART2" | grep . || true)
G41_RUST=$(find z_core/src -name '*.rs' | sort \
           | xargs awk -v Q='"' "$G41_SCAN" 2>/dev/null || true)
G41_ALL=$(printf '%s\n%s\n' "$G41_DART" "$G41_RUST" | grep -c . || true)
G41_LEFT=$(printf '%s\n%s\n' "$G41_DART" "$G41_RUST" | grep . | grep -vE "$G41_ALLOW" || true)
if [ -z "$G41_LEFT" ]; then
  pass "G41 every sentence on the glass calls the container a session ($G41_ALL mentions, all of them allowed by name)"
else
  fail "G41 these sentences still call the container a «conversation» — rule 55-هـ (or they belong in G41's allowed list, with a reason):"
  printf '%s\n' "$G41_LEFT" | sed 's/^/        /'
fi

# **And an exception that matches nothing is a finding, not a comfort.** A
# control that cannot bite is this house's own lesson: a stale line here would
# quietly permit a sentence somebody has already deleted, and the next rename
# would inherit a list nobody can read.
G41_STALE=""
while IFS= read -r allowed; do
  [ -z "$allowed" ] && continue
  if ! grep -qE "$allowed" <<< "$G41_DART"$'\n'"$G41_RUST"; then
    G41_STALE="$G41_STALE
        $allowed"
  fi
done <<EOF
$G41_ALLOWED
EOF
if [ -z "$G41_STALE" ]; then
  pass "G41 every line of the allowed list still answers for a sentence that exists"
else
  fail "G41 these allowed lines match nothing any more, so they permit nothing and explain nothing:$G41_STALE"
fi
# ---------------------------------------------------------------- G46
# **The chat the model is shown is the core's, built in one place** — rule 67,
# the owner's «لا أستطيع أن أتابع الشات معه على نفس الموضوع» of 17 October.
#
# `ask_model` carried a `history: Vec<String>` from Phase 4 until this round,
# and **every caller passed `const []`**. So the parameter was not a door the
# screen used: it was a door the screen could use, and the first thing anybody
# would have put through it is the *restored* text of a turn — the person's own
# names, on their way back out to a model, because that is the form a screen
# has them in. The parameter is deleted and the core fills the context from the
# stored turns of the open chat.
#
# Four things, each of them the shape of a way this could come undone:
#
#  1 — the contract takes no history from anybody;
#  2 — `ask_model`'s own body asks the builder, read from the body and not from
#      the file, so a call in a neighbouring function cannot answer for it;
#  3 — the builder is **one** function, and **both doors send one payload**:
#      what a person carries to a model of their own is the payload as it
#      stands, and the in-app door sends that same payload with one earlier
#      exchange **added** on top of it, built by that one function. So the copy
#      is built in the core, from a payload read through the one accessor, with
#      nothing of it assembled at the door and no restored word able to leave
#      by it — and two builders would have made the two doors disagree about
#      what the person was shown;
#  4 — nothing on the glass assembles a history.
API_C=z_core/src/api.rs
OPS_C=z_core/src/ops/mod.rs
CHAT_C=z_core/src/ops/conversation.rs

# Both surfaces the UI can reach, as G2b reads both: a door on the bridge's own
# wrapper is as much a door as one on the core's contract.
G46_ARG=$(grep -n '^pub fn ' $API_FILES 2>/dev/null | grep -E 'history' || true)
if [ -z "$G46_ARG" ]; then
  pass "G46 no door on either contract surface takes a history: the core builds it"
else
  fail "G46 a contract function takes a history again:"; printf '%s\n' "$G46_ARG" | sed 's/^/        /'
fi

# **The comment lines are thrown away first, and that is not tidiness.** Pinned
# with the builder taken out of `ask_model` and the gate stayed green: the
# sentence above the deleted line still named the builder, so a comment
# answered for the code. A guard that reads prose measures prose.
G46_BODY=$(awk '
  /^pub\(crate\) fn ask_model\(/ {inside=1}
  inside && /^}/ {print; inside=0; next}
  inside && $0 !~ /^[[:space:]]*\/\// {print}
' "$OPS_C")
if grep -q 'the_chat_so_far' <<< "$G46_BODY"; then
  pass "G46 ask_model's own body builds the chat it carries"
else
  fail "G46 ask_model reaches a model without asking for the chat so far — a second question would arrive alone again"
fi

G46_BUILT=$(grep -c 'fn the_chat_so_far' "$CHAT_C" 2>/dev/null || echo 0)
G46_READERS=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /the_chat_so_far/ && $0 !~ /^[[:space:]]*\/\// { if (here != "") print here }
' "$OPS_C" | sort -u | tr '\n' ' ' | sed 's/ $//')
# And the one place the gateway's context is filled.
G46_FILLS=$(grep -c 'context: crate::gateway::Context {' "$OPS_C" 2>/dev/null || echo 0)
if [ "$G46_BUILT" = "1" ] && [ "$G46_FILLS" = "1" ] \
   && [ "$G46_READERS" = "ask_model build_the_chat the_question_alone" ]; then
  pass "G46 one builder makes the chat, and its readers are the three that need it: ask_model, build_the_chat, the_question_alone"
else
  fail "G46 the chat is built in $G46_BUILT place(s), the context is filled in $G46_FILLS, and the readers are «$G46_READERS» — expected one, one, and «ask_model build_the_chat the_question_alone»"
fi

# **And the copy assembles nothing of its own** — point 3's own half. The door
# hands over a payload's text, read through the one accessor; the day it starts
# joining lines again is the day a second assembler exists for text that leaves
# this machine, and the day the two doors can disagree about what the person was
# shown.
if awk '
  /^fn build_the_chat\(/ { inside = 1 }
  inside && /^}/ { inside = 0 }
  inside && $0 ~ /^[[:space:]]*\/\// { next }
  inside && /chat\.lines\.join|chat\.lines\[|lines\.join\(/ { bad = 1 }
  inside && /payload_view\(/ { read_through = 1 }
  END { exit((bad || !read_through) ? 1 : 0) }
' "$OPS_C"; then
  pass "G46 the copy a person takes away is a payload read through the one accessor, assembled nowhere"
else
  fail "G46 the copy a person takes away assembles its own text, or no longer reads one through the payload accessor (the owner, 24 October 2026)"
fi

# `^[^/]*` so that a line of prose about the argument that was deleted is not
# read as the argument coming back: a comment's `//` stands before the word, and
# an argument's does not. The deletion is written down in `session_state.dart`
# in exactly those words, which is how this was found.
# **And the document a turn names is the one the payload carried** — rule 69.
#
# Stamped on the payload when it was built, read off the payload when the answer
# lands. The two differ in exactly the path that matters: a person who copies
# the text out and comes back with an answer from a browser has had the
# preview's copy taken out in between (rule 9), so the bench holds nothing to
# name. Pinned by reading `s.kept` here instead, and the pasted answer lost its
# anchor at once.
G46_STAMP=$(awk '
  /^pub\(crate\) fn ingest_answer\(/ {inside=1}
  inside && /^}/ {inside=0; next}
  inside && $0 !~ /^[[:space:]]*\/\// {print}
' "$OPS_C")
if grep -q 'p\.kept()' <<< "$G46_STAMP" \
   && ! grep -qE '\bs\.kept\b' <<< "$G46_STAMP"; then
  pass "G46 the document a turn names is the one its payload carried, not whatever the bench holds when the answer lands"
else
  fail "G46 ingest_answer takes the preview's handle off the bench — an answer carried back by hand would name no document, because the copy left before it came home"
fi

G46_DART=$(grep -RnE '^[^/]*\bhistory:' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' || true)
if [ -z "$G46_DART" ]; then
  pass "G46 no screen assembles a history"
else
  fail "G46 a screen hands a history to the core:"; printf '%s\n' "$G46_DART" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G57
# **One mailbox, and the public pages agree on it** — the outside model's ن8,
# 19 October 2026.
#
# It measured three public sentences for one fact: `README.md` and
# `packaging/linux/README.txt` printed `yourvoices.app@mono-peak.com` — the
# other product's address — while the site and the privacy pages printed
# `zprivacy@mono-peak.com`. A person who downloaded the archive wrote to a
# mailbox that is not this product's. The site's address is the one kept,
# because that is the one a stranger reaches first and the one the privacy
# pages name as the contact for a GDPR request.
#
# Read from the site rather than written here: the gate has no address of its
# own, so there is nothing for it to disagree with. Whatever the site says is
# what the two READMEs must say.
SITE_PAGE=site/en/index.html
G57_FILES="README.md packaging/linux/README.txt"
if [ -f "$SITE_PAGE" ]; then
  G57_SITE=$(grep -oE '[a-zA-Z0-9._%-]+@mono-peak\.com' "$SITE_PAGE" | sort -u | head -1)
  G57_WRONG=""
  for f in $G57_FILES; do
    [ -f "$f" ] || continue
    for found in $(grep -oE '[a-zA-Z0-9._%-]+@mono-peak\.com' "$f" | sort -u); do
      [ "$found" = "$G57_SITE" ] || G57_WRONG="$G57_WRONG $f:«$found»"
    done
  done
  if [ -n "$G57_SITE" ] && [ -z "$G57_WRONG" ]; then
    pass "G57 one mailbox on every public page: «$G57_SITE»"
  else
    fail "G57 the site says «$G57_SITE» and these say something else:$G57_WRONG — a person writes to whichever page they read"
  fi
else
  skip "G57 one mailbox on every public page" "no $SITE_PAGE in this tree"
fi

# ---------------------------------------------------------------- G58
# **The contract paper counts the ZCFG names that the code allows** — the
# outside model's N-ZCFG-DOC.
#
# `docs/SECURITY_INVARIANTS.md` said «four names» for a year after `config.rs`
# grew to eight (the four layout bits of the work surface). Not a leak — the
# model graded it a stale contract — but the paper is the thing an auditor
# reads, and a paper that undercounts the file it describes is the quiet half
# of G18: the allowlist is the promise, and the promise is published here.
#
# So the number in the paper is read from the array in the code. A ninth name
# reds this gate until somebody writes down what it is and why it is allowed.
G58_CONFIG=z_core/src/config.rs
G58_PAPER=docs/SECURITY_INVARIANTS.md
if [ -f "$G58_CONFIG" ] && [ -f "$G58_PAPER" ]; then
  G58_N=$(grep -oP 'const ALLOWED: \[&str; \K[0-9]+' "$G58_CONFIG" | head -1)
  G58_WORDS="? واحد اثنان ثلاثة أربعة خمسة ستّة سبعة ثمانية تسعة عشرة"
  G58_WORD=$(printf '%s' "$G58_WORDS" | cut -d' ' -f$((G58_N + 1)))
  if [ -n "$G58_N" ] && grep -q "$G58_WORD أسماء" "$G58_PAPER"; then
    pass "G58 the contract paper says «$G58_WORD أسماء» and config.rs allows $G58_N"
  else
    fail "G58 config.rs allows $G58_N ZCFG names and the paper does not say «$G58_WORD أسماء» — the published promise undercounts the file it describes"
  fi
else
  skip "G58 the paper counts the ZCFG names the code allows" "no config.rs or no paper"
fi

# ---------------------------------------------------------------- G60
# **The Windows release carries the runtime it needs** — 098, after the owner
# met a clean Windows machine on 20 October where `VCRUNTIME140.dll` was
# missing and Node's own installer had failed on it.
#
# A Flutter application on Windows needs `vcruntime140.dll`,
# `vcruntime140_1.dll` and `msvcp140.dll`, and `flutter build windows` copies
# none of them. The shape chosen is Microsoft's «app-local deployment» — the
# three beside `zprivacy.exe` — because the other shape runs
# `vc_redist.x64.exe`, which installs machine-wide and asks for an
# administrator, and this installer promises neither
# (`PrivilegesRequired=lowest`, per-user).
#
# **This is a check on the text, and it says so.** Linux cannot run the
# Windows job, install the package or load a DLL; what a gate here can do is
# refuse a workflow that has stopped naming the three files in the step that
# copies them and in the step that asserts them — which is how this round
# would quietly come undone, since the copy is one `foreach` away from being
# edited to two names. The measurement itself lives where the files are made:
# the assert step prints each version into the run's log, and a missing one
# fails that job.
#
# Three checks: the copy names the three, the assert names the three, and the
# obligation travels — Microsoft's redistribution notice is in the folder the
# job copies into every release.
WINJOB=.github/workflows/windows-core.yml
RUNTIME_NOTICE=packaging/third-party/msvc-runtime-NOTICE.txt
G60_DLLS="vcruntime140.dll vcruntime140_1.dll msvcp140.dll"

if [ -f "$WINJOB" ]; then
  # **Each window ends at the next step, not at a step named here.** Item 3
  # inserted a step between the assert and the staging, and a boundary spelled
  # by name had quietly widened the assert's window to include it — a gate
  # green because it was reading somebody else's lines.
  G60_COPY=$(awk '
    /^      - name: The runtime the application needs/ {inside=1; next}
    inside && /^      - name: / {inside=0}
    inside && $0 !~ /^[[:space:]]*#/ {print}
  ' "$WINJOB")
  G60_ASSERT=$(awk '
    /^      - name: The three are in the bundle/ {inside=1; next}
    inside && /^      - name: / {inside=0}
    inside && $0 !~ /^[[:space:]]*#/ {print}
  ' "$WINJOB")
  G60_MISSING=""
  for dll in $G60_DLLS; do
    grep -qF "$dll" <<< "$G60_COPY" || G60_MISSING="$G60_MISSING copy:$dll"
    grep -qF "$dll" <<< "$G60_ASSERT" || G60_MISSING="$G60_MISSING assert:$dll"
  done
  if [ -n "$G60_COPY" ] && [ -n "$G60_ASSERT" ] && [ -z "$G60_MISSING" ]; then
    pass "G60 the Windows job copies the three runtime libraries beside the application and asserts them (read as text: Linux cannot run that job)"
  else
    fail "G60 the Windows job no longer names$G60_MISSING — a release that is missing one of them stops on a clean machine with Windows' own dialogue"
  fi

  # **And the folder they are copied from is asked for, never typed** — 098
  # item 5. The step read `VCToolsRedistDir` for the redistributable folder and
  # then typed the toolset's own number inside it, which is this step's rule
  # left unapplied to its second case: the runner image moved to Visual Studio
  # 18 with MSVC 14.51 on 21 October, that folder does not exist there, the copy
  # threw, and every step after it — the versions, the needles, the staging, the
  # zip, the installer, the MSIX, the uploads — was skipped. A whole run, no
  # release.
  #
  # Two things, because either alone is a half: the glob is there, and no
  # number is typed anywhere in the step. Comment lines are already dropped
  # above, which is what lets this paragraph name what it forbids.
  G60_TOOLSET=$(printf '%s\n' "$G60_COPY" | grep -cE 'Microsoft\.VC[0-9][0-9]*\.CRT' || true)
  if grep -qF 'Microsoft.VC14*.CRT' <<< "$G60_COPY" && [ "$G60_TOOLSET" -eq 0 ]; then
    pass "G60 the copy step asks the runner which CRT folder it has — one match by shape, and no toolset number typed"
  else
    fail "G60 the copy step names a toolset folder by hand ($G60_TOOLSET typed): the next runner image with a newer MSVC stops the release at the copy"
  fi
else
  skip "G60 the Windows job carries the runtime" "no $WINJOB in this tree"
fi

if [ -f "$RUNTIME_NOTICE" ] && grep -q "msvc-runtime-NOTICE.txt" "$WINJOB" 2>/dev/null; then
  pass "G60 Microsoft's redistribution notice is in the tree and travels with every Windows release"
else
  fail "G60 the runtime ships and its notice does not travel: $RUNTIME_NOTICE must exist and the job must copy it"
fi

# ---------------------------------------------------------------- G61
# **A release says nothing about its builder, on Windows too** — 098 item 3,
# from the Windows session's measurement of 20 October: the `z_bridge.dll`
# installed on the owner's machine carries
# `C:\Users\runneradmin\.cargo\registry\src\index.crates.io-…` **242
# times**. The file measured was not that job's output, so this proves the job
# rather than that file.
#
# Two halves, as on Linux: the compiler is told to write relative-looking paths
# (`--remap-path-prefix`, from `CARGO_HOME` and `RUSTUP_HOME` rather than a
# typed `$USERPROFILE\.cargo`, because a prefix that does not match removes
# nothing and says nothing), and then what was built is **searched**. The
# search runs in the job, on the three files we write, because the artefact is
# there and not here.
#
# **This is a check on the text, and it says so** — the same sentence G60
# carries. What it can refuse is a job that has stopped naming a needle or a
# file, and a packaging script whose list has drifted from the job's. They are
# one list, so they are read as one.
G61_NEEDLES='runneradmin
D:\a\
\.cargo\registry
/home/'
G61_OURS="zprivacy.exe z_bridge.dll data/app.so"
G61_MISSING=""

if [ -f "$WINJOB" ]; then
  G61_STEP=$(awk '
    /^      - name: Nothing in the three files we built/ {inside=1; next}
    inside && /^      - name: / {inside=0}
    inside && $0 !~ /^[[:space:]]*#/ {print}
  ' "$WINJOB")
  printf '%s\n' "$G61_NEEDLES" | while IFS= read -r n; do
    [ -n "$n" ] || continue
    grep -qF -- "$n" <<< "$G61_STEP" || printf 'job:%s\n' "$n"
  done > /tmp/g61.$$
  for f in $G61_OURS; do
    grep -qF -- "$f" <<< "$G61_STEP" || printf 'job:%s\n' "$f" >> /tmp/g61.$$
  done
  # The remap's own half: read from the variables, not from a typed home.
  if ! grep -q 'cargo_home="$CARGO_HOME"' "$WINJOB"; then
    printf 'job:CARGO_HOME\n' >> /tmp/g61.$$
  fi
  G61_MISSING=$(tr '\n' ' ' < /tmp/g61.$$)
  rm -f /tmp/g61.$$
  if [ -n "$G61_STEP" ] && [ -z "$G61_MISSING" ]; then
    pass "G61 the Windows job searches the three files it builds for the four paths of the machine that built them (read as text: Linux cannot read that artefact)"
  else
    fail "G61 the Windows job no longer names: $G61_MISSING — 242 of one of these needles were measured in an installed library"
  fi
else
  skip "G61 the Windows job proves its own paths" "no $WINJOB in this tree"
fi

G61_SCRIPT=scripts/package_windows.sh
if [ -f "$G61_SCRIPT" ]; then
  G61_LIST=$(grep -n 'for needle in' "$G61_SCRIPT" | head -1)
  G61_LEFT=""
  printf '%s\n' "$G61_NEEDLES" | while IFS= read -r n; do
    [ -n "$n" ] || continue
    grep -qF -- "$n" <<< "$G61_LIST" || printf 'script:%s\n' "$n"
  done > /tmp/g61s.$$
  G61_LEFT=$(tr '\n' ' ' < /tmp/g61s.$$)
  rm -f /tmp/g61s.$$
  # `runneradmin` is in the script as the whole home it belongs to, which is
  # the same needle with its own prefix; asked for by the part that matters.
  if [ -z "$G61_LEFT" ]; then
    pass "G61 the packaging script and the job search for the same four paths — one list"
  else
    fail "G61 the packaging script's list has drifted from the job's: $G61_LEFT"
  fi
fi

# **And the crate list names the crate, not the builder's disk** — 098 item
# 4(ج). `cargo tree` writes a workspace crate as «z_core v0.1.0 (…)». The Linux
# script stripped that with `s| \(/[^)]*\)$||`, which needs a leading `/` and
# therefore could never match `(D:\a\…)` — and the Windows session found
# exactly that in line 62 of an installed build's own notice. Both generators
# carry the general form now, and this refuses either of them going back to the
# Unix-only one: a rule in two spellings is how the second case gets forgotten.
G61_STRIP='s| \([^)]*\)$||'
G61_UNIX='s| \(/[^)]*\)$||'
G61_NOTICE=""
for f in scripts/package_linux.sh "$WINJOB"; do
  [ -f "$f" ] || continue
  # **Comment lines first**: both files now explain the old pattern in prose,
  # and the first run of this gate dutifully found it there and failed. A
  # census of what a file *does* may not read what it *says* — G53 and G60
  # learned the same lesson in this round.
  G61_DOES=$(grep -vE '^[[:space:]]*#' "$f")
  grep -qF -- "$G61_STRIP" <<< "$G61_DOES" || G61_NOTICE="$G61_NOTICE $f:no-strip"
  grep -qF -- "$G61_UNIX" <<< "$G61_DOES" && G61_NOTICE="$G61_NOTICE $f:unix-only"
done
if [ -z "$G61_NOTICE" ]; then
  pass "G61 both crate lists name the crate and not the folder it was built in, in one spelling"
else
  fail "G61 a crate list would carry the builder's own path:$G61_NOTICE"
fi

# ---------------------------------------------------------------- G63
# **The job stages outside the tree it was built from** — 098 item 4(أ), from
# the real run 39508181140 on `4bb202f`.
#
# `scripts/package_windows.sh` refuses a dirty tree, because an archive built
# from one cannot be rebuilt by anybody. The staging step made `staging/`
# **inside** the checkout, so the script met «?? staging/» and refused: no
# stamp, no zip, no `.sha256`, the installer and the MSIX skipped, the uploads
# failed. Items 1–3 all ride a release that this red prevented from existing.
#
# Neither `ALLOW_DIRTY` nor a `.gitignore` line is the answer — both teach the
# check to look away from the one thing it is for. So this reads that the
# staging folders are the runner's own, and that no step builds one inside the
# workspace again. A check on the text, said so in its sentence, as its two
# neighbours are.
if [ -f "$WINJOB" ]; then
  G63_DOING=$(grep -vE '^[[:space:]]*#' "$WINJOB")
  # The forms a path **relative to the checkout** takes in this file, named one
  # by one rather than by a pattern loose enough to catch the definition of the
  # right answer — which is what the first run of this gate did
  # (`STAGE=$temp/staging/…` is the fix, not the fault).
  G63_WRONG=$(printf '%s\n' "$G63_DOING" \
    | grep -nE '(\.\./\.\./staging|-Path staging|path: staging|=staging[-/]|\$root\\staging)' || true)
  G63_MISSING=""
  grep -q 'temp=${RUNNER_TEMP' <<< "$G63_DOING" || G63_MISSING="$G63_MISSING RUNNER_TEMP"
  grep -q 'STAGE=\$temp/staging' <<< "$G63_DOING" || G63_MISSING="$G63_MISSING STAGE"
  grep -q 'INSTALLER_OUT=\$temp/staging-installer' <<< "$G63_DOING" \
    || G63_MISSING="$G63_MISSING INSTALLER_OUT"
  grep -q 'package_windows.sh "\$STAGE"' <<< "$G63_DOING" \
    || G63_MISSING="$G63_MISSING the-packaging-call"
  if [ -z "$G63_WRONG" ] && [ -z "$G63_MISSING" ]; then
    pass "G63 the Windows job stages under the runner's own temp, so the packaging script's clean-tree law cannot fire on the job's own folder"
  else
    [ -n "$G63_MISSING" ] && fail "G63 the Windows job no longer names:$G63_MISSING"
    [ -n "$G63_WRONG" ] && { fail "G63 a step would stage inside the checkout again:"; printf '        %s\n' "$G63_WRONG"; }
  fi
else
  skip "G63 the Windows job stages outside the tree" "no $WINJOB in this tree"
fi

# ---------------------------------------------------------------- G64
# **The Dart suite names the library it speaks through in one place** — 098
# item 4(ب). Fifty-nine test files each held
# `const _libPath = 'build/linux/…/libz_bridge.so'`, and on Windows every one
# of them threw out of its `setUpAll`: seventy-one failures, sixty-six of them
# hidden behind a `tail -40`, and five more from a `tearDownAll` whose `late`
# folder was never set because the setUpAll above it had thrown first.
#
# One helper chooses by platform now, and this refuses the sixtieth file that
# would write a path of its own. Comment lines are dropped before counting,
# because a comment naming the library is prose and this measures what runs.
DART_TESTS=apps/flutter_app/test
G64_HELPER=$DART_TESTS/the_bridge_the_tests_speak_through.dart
if [ -d "$DART_TESTS" ] && [ -f "$G64_HELPER" ]; then
  G64_OTHERS=$(grep -rn -- 'libz_bridge\.so\|runner/Debug/z_bridge\.dll' "$DART_TESTS" \
    --include='*.dart' 2>/dev/null \
    | grep -v "^$G64_HELPER:" \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)
  if [ -z "$G64_OTHERS" ]; then
    pass "G64 the Dart suite asks one place where its bridge is, so the platform is chosen once"
  else
    fail "G64 a test names a platform's own library path instead of the one place:"
    printf '        %s\n' "$G64_OTHERS"
  fi
  if grep -q "dart-tests-windows" "$WINJOB" 2>/dev/null; then
    pass "G64 the Windows job hands over the Dart suite's own record, not forty lines of it"
  else
    fail "G64 the Windows job tails the Dart log and uploads no record: sixty-six failures of seventy-one were lost that way"
  fi
else
  skip "G64 the Dart suite names its bridge once" "no $G64_HELPER in this tree"
fi

# ---------------------------------------------------------------- G67
# **A path is spelled the way the system spells it** — 098 item 5, from the
# Windows suite's own record (`dart.json`, run 39548354872, 21 October).
#
# Two of the four reds that record carried were one fault wearing two coats:
# a path separator typed into our own text instead of asked of the platform.
#
#  1 — **The one place the app writes a file joined it with a `/`.**
#      `'$into/$stem.pdf'` writes the file in the right place on Windows, which
#      takes either separator, and then the screen says «Saved to
#      C:\Users\…\ZPrivacy/Brief-protected-21.pdf» — a path no folder window of
#      theirs prints, in the one sentence a person checks after a save. The
#      suite said it its own way: «the saved file carries the tokens» looks for
#      the path on the glass while the listing hands back `…\Brief…pdf`, so two
#      spellings of one file did not match.
#  2 — **A census compared path names in two spellings.** `messages_test`'s
#      exemptions were typed with `/`, `Directory.listSync` on Windows hands
#      back `\`, and the mapper was reported as its own offender along with
#      every generated file. `test/a_path_in_one_spelling.dart` is the one
#      translation, and this refuses a path fragment typed into a comparison
#      against a `.path` without it.
#
# Read as text, on Linux, about Windows — the same sentence G60 and G64 carry,
# and for the same reason: nothing here can run that suite. Comment lines are
# dropped before both searches, because the paragraphs above quote exactly what
# the checks forbid, and a gate that reads its own prose reds on itself.
G67_LIB_FILES=$(find "$FLUTTER_LIB" -name '*.dart' -not -path '*/lib/src/rust/*' -not -path '*/lib/l10n/*' 2>/dev/null | sort)
G67_SPELLING=$DART_TESTS/a_path_in_one_spelling.dart
if [ -n "$G67_LIB_FILES" ]; then
  # shellcheck disable=SC2086
  G67_GLUED=$(grep -nE '\$[A-Za-z_][A-Za-z0-9_.]*/' $G67_LIB_FILES 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)
  if [ -z "$G67_GLUED" ]; then
    pass "G67 the app builds no path by gluing a separator into its own text: the folder and the name are joined"
  else
    fail "G67 a path is spelled here instead of joined, and Windows shows that spelling to the person:"
    printf '        %s\n' "$G67_GLUED"
  fi
else
  skip "G67 the app joins a folder and a name" "no $FLUTTER_LIB in this tree"
fi

if [ -f "$G67_SPELLING" ]; then
  G67_TYPED=$(grep -rnE "\.path\.(contains|endsWith|startsWith)\('[^']*/" "$DART_TESTS" --include='*.dart' 2>/dev/null \
    | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*|/\*)' || true)
  if [ -z "$G67_TYPED" ]; then
    pass "G67 every census over a listing compares the names in one spelling, so it measures both platforms"
  else
    fail "G67 a census compares a typed path fragment against what the platform spelled — green on Linux, red or blind on Windows:"
    printf '        %s\n' "$G67_TYPED"
  fi
else
  skip "G67 a census compares one spelling" "no $G67_SPELLING in this tree"
fi

# ---------------------------------------------------------------- G68
# **A path crosses into PowerShell once, and is converted where it crosses** —
# 098 item 6, measured on run 39586867441.
#
# That run was the first ever to reach the stamp on Windows: the three runtime
# libraries beside the application at 14.51.36247.0, `BUILD-INFO.txt` naming
# the commit with a clean tree, the four builder needles zero in all 36 files
# we compile. Then step 13:
#
#     Compress-Archive : The path '/d/a/_temp/staging/zprivacy-v1-windows-x86_64'
#     either does not exist or is not a valid file system path.
#
# `package_windows.sh` runs under bash and spells its paths bash's way;
# PowerShell reads Windows' spelling and cannot see such a path at all. Neither
# half is wrong — the translation at the seam was missing — and because the
# `.sha256`, the installer, the MSIX and every upload hang on that zip, one
# unconverted path cost the fourth run in a row with no release.
#
# The rule the checker holds is deliberately strict: **no variable reaches a
# `powershell` or `pwsh` command unless `cygpath` produced it**, because
# guessing which interpolation is a path is exactly how this one was missed. A
# value that honestly is not a path is allowed by name, in the file, with its
# reason («# not-a-path: NAME»). And a variable already converted may not be
# converted again: a path converted twice is a path broken twice.
#
# **And the job has the same seam**: a `shell: bash` step writes a name into
# `$GITHUB_ENV`, a `shell: pwsh` step reads it as `$env:NAME`. Today those names
# are built from `$RUNNER_TEMP` with the backslashes turned round — `D:/a/_temp`,
# which both shells read — and the Inno step turns them back. That is correct
# and one `pwd` away from not being, so the checker holds it too.
#
# Measured in five shapes on temp copies before it was trusted: a raw
# interpolation (the fault itself, which it names variable by variable), a
# `WIN_`-looking name that `cygpath` never touched, a double conversion, the
# by-name allowance, and a `$GITHUB_ENV` name written from `pwd` and read by a
# pwsh step. Read as text, on Linux, about Windows — nothing here can
# run PowerShell; what this measures is not «the zip works» but «no path
# reaches it in the wrong spelling», which is the fault that happened.
#
# A tree with no crossing at all is a **skip** and not a pass: zero crossings
# is honestly nothing to check, and a gate that says «pass» about nothing is
# how a check stops measuring in silence.
if [ -f scripts/check_powershell_paths.py ]; then
  if G68_OUT=$(python3 scripts/check_powershell_paths.py 2>&1); then
    G68_N=$(printf '%s' "$G68_OUT" | tail -1 | grep -oE '[0-9]+' | head -1)
    if [ "${G68_N:-0}" -gt 0 ]; then
      pass "G68 every path a script hands to PowerShell is converted where it crosses —$(printf '%s' "$G68_OUT" | tail -1)"
    else
      skip "G68 a path crosses into PowerShell converted" "no script here calls PowerShell, so there is nothing to convert"
    fi
  else
    fail "G68 a path reaches PowerShell in this shell's spelling, which Windows cannot see — the zip, its hash, the installer and the MSIX all hang on it:"
    printf '%s\n' "$G68_OUT" | sed 's/^/        /'
  fi
else
  skip "G68 a path crosses into PowerShell converted" "no checker yet"
fi

# ---------------------------------------------------------------- G69
# **A tool on a runner may not ask a question, and may not build what nobody
# measured** — 098 item 7, from run 39719891044.
#
# That run is the first that reached the end with something to hand over: the
# zip and its `.sha256`, the folder, the installer with its hash, and 414 Dart
# tests green on Windows. One step was red and one was skipped, and the two are
# the same mistake twice.
#
#   * `msix:create` looked for the publisher's certificate in
#     `CurrentUser\Root`, did not find the throw-away one, and asked the
#     console «Do you want to install the certificate … ? (y/N)». No console
#     answers on a runner: the prompt's own timer completed with `null`, the
#     tool died on `type 'Null' is not a subtype of type 'FutureOr<String>'`,
#     exit 255. `--install-certificate false` is the tool's own switch for it,
#     and a runner must never install anything anyway.
#   * The same call ran `flutter build windows` again, **after** the needle
#     search and the staging, so the package held a folder nobody had searched
#     or hashed. `--build-windows false`, and the step after it opens the
#     package and compares the six files with the staged ones.
#   * «Upload the installer» was the one upload of the three without
#     `if: always()`, so a built and hashed installer was thrown away by a red
#     four steps later. The comment above «Upload the folder» already states
#     that law; this is it applied to its sibling.
#
# **This is a check on the text, and it says so** — the same sentence G60, G64
# and G68 carry. Linux cannot run that job, install a package or answer a
# console prompt; what a gate here can do is refuse a workflow that has
# stopped carrying the two switches, stopped comparing what the package holds,
# or grown an upload that a red above it can throw away.
if [ -f "$WINJOB" ]; then
  G69_MSIX=$(awk '
    /^      - name: An MSIX for sideloading/ {inside=1; next}
    inside && /^      - name: / {inside=0}
    inside && $0 !~ /^[[:space:]]*#/ {print}
  ' "$WINJOB")
  G69_MISSING=""
  # `--` before the pattern: a switch is what is being looked for, and grep
  # would otherwise read `--install-certificate false` as an option of its own.
  for switch in --install-certificate --build-windows; do
    grep -qF -- "$switch false" <<< "$G69_MSIX" \
      || G69_MISSING="$G69_MISSING «$switch false»"
  done
  if [ -n "$G69_MSIX" ] && [ -z "$G69_MISSING" ]; then
    pass "G69 the MSIX call tells the tool to ask nothing and build nothing: it packs the folder this run measured (read as text: Linux cannot run that job)"
  else
    fail "G69 the MSIX call no longer carries$G69_MISSING — without the first the tool asks a console that is not there and exits 255, without the second it packs a build nobody searched"
  fi

  # **And the signature it makes asks nothing of anybody else.** 098 item 8,
  # from run 39734294387: `msix` 3.16.8 appends
  # `/tr http://timestamp.digicert.com` to every pfx signing of its own accord
  # (`sign_tool.dart:234`) and never `/td sha256`, so signtool asks that server
  # for a SHA-1-digest timestamp, which it has stopped answering, and the
  # signing dies whole on «SignerSign() failed» (0x80096005) — after the
  # certificate was chosen and the store added, which is why the log reads like
  # the certificate's fault.
  #
  # A timestamp exists so a signature can outlive the certificate that made
  # it. This certificate is made and deleted inside one step, so the job wants
  # none. `--signtool-options` is the tool's own door: when the options name a
  # certificate file with `/f`, `sign_tool.dart:26-34` and `:210` take them as
  # the whole command and add no `/tr`. So the call must carry those options,
  # they must name `/fd SHA256`, and `/tr` must appear nowhere in the step.
  #
  # The window is the step's lines with every comment dropped — the paragraph
  # above the call quotes the switch this check forbids, and a gate that reds
  # on its own explanation measures nothing.
  G69_UNTIMED=""
  grep -qF -- '--signtool-options' <<< "$G69_MSIX" \
    || G69_UNTIMED="$G69_UNTIMED «--signtool-options, or the tool writes the signing command itself and timestamps it»"
  grep -qF -- '/fd SHA256' <<< "$G69_MSIX" \
    || G69_UNTIMED="$G69_UNTIMED «/fd SHA256 inside those options»"
  if grep -qE '(^|[[:space:]"])/tr([[:space:]]|$)' <<< "$G69_MSIX"; then
    G69_UNTIMED="$G69_UNTIMED «no /tr at all: a timestamp asked for a certificate that dies with this run»"
  fi
  if [ -n "$G69_MSIX" ] && [ -z "$G69_UNTIMED" ]; then
    pass "G69 the MSIX is signed by a command this job wrote: SHA-256, and no timestamp asked of a server, because the certificate dies with the run"
  else
    fail "G69 the signing command is no longer the one item 8 measured; it has to carry:$G69_UNTIMED"
  fi

  # The window is the comparison step's own lines, so a gate that asks «is the
  # package read and compared» cannot be answered by a comment that says so.
  G69_CMP=$(awk '
    /^      - name: What the MSIX packed is what was measured/ {inside=1; next}
    inside && /^      - name: / {inside=0}
    inside && $0 !~ /^[[:space:]]*#/ {print}
  ' "$WINJOB")
  G69_UNREAD=""
  for want in zprivacy.exe z_bridge.dll data/app.so vcruntime140.dll vcruntime140_1.dll msvcp140.dll ZipFile Get-FileHash 'env:STAGE'; do
    grep -qF "$want" <<< "$G69_CMP" || G69_UNREAD="$G69_UNREAD $want"
  done
  if [ -n "$G69_CMP" ] && [ -z "$G69_UNREAD" ]; then
    pass "G69 the step after the MSIX opens the package as a zip and compares its six files with the staged copies, hash for hash"
  else
    fail "G69 the package is no longer compared with the folder that was measured — missing:$G69_UNREAD"
  fi

  # **And an unsigned package never reaches an upload.** The tool packs before
  # it signs, so the run that died at the certificate question had already
  # written a `.msix` that carries no signature, and `if: always()` uploaded it
  # with the zip — a package Windows refuses, in an artefact named like a
  # release. The step that reads it must exist, must ask the signature rather
  # than the colour of the step above, must delete the package **and** the
  # certificate that says nothing without it, must run `if: always()` because
  # the case it exists for is a red above it, and must sit **before** the first
  # upload: after one, it keeps nothing.
  G69_SIG=$(awk '
    /^      - name: An unsigned package is not handed to anybody/ {inside=1; next}
    inside && /^      - name: / {inside=0}
    inside && $0 !~ /^[[:space:]]*#/ {print}
  ' "$WINJOB")
  G69_UNASKED=""
  for want in 'if: always()' Get-AuthenticodeSignature NotSigned Remove-Item '*.msix' .cer; do
    grep -qF -- "$want" <<< "$G69_SIG" || G69_UNASKED="$G69_UNASKED «$want»"
  done
  G69_SIG_AT=$(grep -n '^      - name: An unsigned package is not handed to anybody$' "$WINJOB" | cut -d: -f1)
  G69_UPLOAD_AT=$(awk '
    /^  [a-zA-Z_-]+:/ {job=$0; sub(/^  /,"",job); sub(/:.*/,"",job)}
    job == "app" && /uses: actions\/upload-artifact/ {print NR; exit}
  ' "$WINJOB")
  if [ -n "$G69_SIG_AT" ] && [ -n "$G69_UPLOAD_AT" ] && [ "$G69_SIG_AT" -gt "$G69_UPLOAD_AT" ]; then
    G69_UNASKED="$G69_UNASKED «before the first upload, not after it»"
  fi
  if [ -n "$G69_SIG" ] && [ -z "$G69_UNASKED" ]; then
    pass "G69 an unsigned MSIX is read and deleted before anything is uploaded, so what travels either installs or is absent"
  else
    fail "G69 nothing asks the package for its signature before the uploads — missing:$G69_UNASKED"
  fi

  # **And no upload in that job can be thrown away by a red above it.** A step
  # is read whole and comment lines are dropped, because the paragraph that
  # explains `always()` sits between two steps and would otherwise answer for
  # the one it is written above.
  G69_NAKED=$(awk '
    function flush() {
      if (body ~ /uses: actions\/upload-artifact/ && body !~ /if: always\(\)/) print name
    }
    /^  [a-zA-Z_-]+:/ { flush(); job=$0; sub(/^  /,"",job); sub(/:.*/,"",job); name=""; body=""; next }
    job != "app" { next }
    /^[[:space:]]*#/ { next }
    /^      - / {
      flush()
      body=$0
      name="(a step with no name)"
      if ($0 ~ /^      - name: /) { name=$0; sub(/^      - name: /,"",name) }
      next
    }
    { body = body "\n" $0 }
    END { flush() }
  ' "$WINJOB")
  if [ -z "$G69_NAKED" ]; then
    pass "G69 every upload in the Windows app job runs if: always(), so a red step cannot throw away what was already built and hashed"
  else
    fail "G69 an upload in the Windows app job waits on the steps above it, and a red there throws the file away:"
    printf '%s\n' "$G69_NAKED" | sed 's/^/        /'
  fi
else
  skip "G69 the MSIX asks nobody and packs what was measured" "no $WINJOB in this tree"
fi

# ---------------------------------------------------------------- G71
# **The NOTICE names the maker, and it travels** — paper 113, the owner's
# licensing word of 24 October 2026: «إمكانية استخدام الكود في الشركات
# والأفراد دون الرجوع إلى الشركة، ولكن يجب ذكر مصدر الكود والشركة المنتجة في
# تعريف منتجاتهم. هذا هو الشرط الوحيد».
#
# Apache 2.0 does not change and nobody is asked for permission. The one
# condition rides on the mechanism the licence already has: §4(d) binds anyone
# who redistributes a work containing ours to carry **our NOTICE's**
# attribution in their own notices, documentation or «About» screen. That
# clause binds nothing at all unless a `NOTICE` file exists and actually
# travels in the distribution — which is why this gate is not about a sentence
# on a page but about a file in an artefact.
#
# Three things, and the third is the one a reader would forget:
#
#   1 — the file is there and is **the owner's own text, byte for byte**. Not a
#       shape and not a few key words: he said «نعم» to five lines, and a gate
#       that checked «does it mention Faruk AB» would let somebody reword the
#       attribution a licence clause points at. The text is written out below
#       so that this gate and the file can be read side by side; two places
#       that must agree is the point, not an accident.
#   2 — **every packaging path copies it beside LICENSE, and there are two of
#       them on Windows, not one.** This gate said «the staging, which is what
#       the installer copies wholesale and what the MSIX is packed from», and
#       the second half was **wrong** — found by paper 113's own MSIX
#       comparison on its first real run (40128478018): «NOTICE is in the MSIX
#       0 time(s), not once», with the six binaries agreeing. `msix:create
#       --build-windows false` packs the runner's **Release** folder; the
#       staging is what the zip and the Inno installer are made from, and the
#       six binaries matched only because the staging copies them *from*
#       Release. So the two files the staging adds of its own — LICENSE and
#       NOTICE — were in no MSIX ever built. Paper 114 copies both into Release
#       in the step that puts the C++ runtime there, before the needle search
#       and the hashing read that folder, and this gate reads all three places:
#       the Linux archive's script, the Windows staging, and Release.
#   3 — **each of those paths asks for it by name afterwards.** A `cp` that
#       fails under `set -e` stops the job, and the Linux script's `die` says
#       which promise broke; the Windows job's own `for f in …` list and the
#       MSIX's hash comparison are what turn «it was copied» into «it is in
#       the thing people download». A gate that only read the `cp` would be
#       green on a job that copied it and shipped an archive built before it —
#       and a gate that reads only the staging would be green on a job whose
#       MSIX carries neither file, which is exactly what happened.
#
# What this gate cannot do is open an `.msix` or a `.exe` on Linux, which is
# why the Windows job carries its own two assertions and this reads that they
# are there. The archive itself is read when one exists — `G14`'s own tar
# listing — and paper 113's report carries the listing of each artefact.
G71_TEXT=$(cat <<'THE_NOTICE'
Z Privacy
Copyright 2026 Faruk AB (Sweden, org.nr 559473-3494)
https://z-privacy.com
Source: https://github.com/YourVoicesApp/z-privacy

This product includes software developed by Faruk AB.
THE_NOTICE
)
G71_BAD=""
if [ ! -f NOTICE ]; then
  G71_BAD="there is no NOTICE at the root, so Apache §4(d) binds nobody to anything"
elif [ "$(cat NOTICE)" != "$G71_TEXT" ]; then
  G71_BAD="NOTICE is not the text the owner approved — $(diff <(printf '%s\n' "$G71_TEXT") NOTICE | tr '\n' ' ')"
fi
# The two places a copy has to be made, and the two places it has to be asked
# for by name afterwards. Read as text, because the one platform that could run
# the Windows half is not this one.
if [ -z "$G71_BAD" ]; then
  grep -q 'cp -f "$ROOT/NOTICE" "$STAGE/NOTICE"' scripts/package_linux.sh \
    || G71_BAD="scripts/package_linux.sh does not put NOTICE in the archive"
fi
if [ -z "$G71_BAD" ] && [ -f "$WINJOB" ]; then
  G71_WIN=$(grep -vE '^[[:space:]]*#' "$WINJOB")
  grep -q 'cp -f ../../NOTICE "$dest/NOTICE"' <<< "$G71_WIN" \
    || G71_BAD="the Windows job does not stage NOTICE, so neither the installer nor the MSIX carries it"
  if [ -z "$G71_BAD" ]; then
    grep -qE 'for f in LICENSE NOTICE ' <<< "$G71_WIN" \
      || G71_BAD="the Windows job stages NOTICE and never asks for it by name — a copy nobody checks is a copy that can go missing in a reordered job"
  fi
  if [ -z "$G71_BAD" ]; then
    # **Anchored, because paper 114 gave this file two lines that read alike.**
    # The copy into Release is `foreach ($legal in @("LICENSE", "NOTICE"))` and
    # the comparison's list ends `… "LICENSE", "NOTICE")) {` on a line of its
    # own — so a pattern without the anchor was green on either of them, and
    # the pin that was supposed to prove the comparison bites found it by
    # matching twice. One of the two places is enough to satisfy a loose
    # pattern, which is a gate measuring the wrong half.
    grep -qE '^[[:space:]]+"LICENSE", "NOTICE"\)\) \{' <<< "$G71_WIN" \
      || G71_BAD="the MSIX comparison does not name LICENSE and NOTICE together, and the MSIX is the artefact no gate here can open"
  fi
  # **And the folder the MSIX actually packs carries them** — paper 114. The
  # staging is the installer's; Release is the MSIX's, and a copy into one is
  # not a copy into the other.
  if [ -z "$G71_BAD" ]; then
    grep -q 'foreach ($legal in @("LICENSE", "NOTICE"))' <<< "$G71_WIN" \
      || G71_BAD="nothing puts LICENSE and NOTICE into the Release folder, which is what msix:create packs — the staging is the installer's folder, not the MSIX's"
  fi
fi
# And the folder says what is in it, on both platforms: a listing that names
# LICENSE and not NOTICE is a folder lying about itself by omission.
if [ -z "$G71_BAD" ]; then
  for f in packaging/linux/README.txt packaging/windows/README.txt; do
    grep -q '^  NOTICE' "$f" \
      || G71_BAD="$f lists what is in the folder and does not name NOTICE"
  done
fi
if [ -z "$G71_BAD" ]; then
  pass "G71 the NOTICE names the maker and travels: the owner's six lines byte for byte, into the archive, into the installer's staging and into the Release folder the MSIX packs, asked for by name in each, both licence files compared against the MSIX itself, and named in both folder listings"
else
  fail "G71 $G71_BAD"
fi

# ---------------------------------------------------------------- G70
# **The suite asks its own questions in a form with no writer to kill** —
# paper 112, 24 October 2026, out of a false red that cost a round its trust.
#
# `G63` reddened once on a tree it does not read — «the Windows job no longer
# names: RUNNER_TEMP» — and passed on the run before it, on another seat's run
# twenty minutes earlier, and on a second run of the same committed tree. The
# shape was its own question: a writer piped into `grep -q` while this script
# runs under `set -o pipefail`. The reader exits at its **first match**, the
# writer still in the pipe takes SIGPIPE, and the pipeline's status becomes the
# writer's 141 rather than the reader's 0 — so «is X present» answers «no»
# about a file that holds it. Measured in the run's own shell: twenty attempts
# each of that gate's four questions, and the one whose pattern matches
# earliest missed **1 of 20** while the other three missed none. In a quiet
# shell, 400 attempts missed none — which is the worst rate there is, because a
# gate that reds once in twenty runs over nothing teaches every reader to
# re-run it and believe the green.
#
# So the shape is gone from this suite — 44 questions became herestrings, 11
# producers that must stay streams were wrapped in `( set +o pipefail; … )`,
# and two more in `check_site.sh` and `check_storage_contracts.sh` went the
# same way because the site gate runs on publishing day — and this is what
# refuses the next one.
#
# **The rule, in a form a reader can hold:** a pipe into `grep -q` is allowed
# only inside a subshell that turns `pipefail` off, and «inside» is read as
# `set +o pipefail` on the same line or within the three lines above it.
# Comment lines are dropped before anything is counted, because a gate that
# quotes what it forbids fails on its own paragraph — this house has paid for
# that four times in one round.
#
# **Its own limit, said out loud:** a `set +o pipefail` written three lines
# above a pipeline but *outside* any subshell would satisfy this and disable
# `pipefail` for everything after it. That is a worse thing than the one this
# gate is about, it is visible in any diff of this file, and no text check can
# tell a subshell from a scope without parsing shell — so it is named here
# rather than guarded against.
G70_SCRIPTS="scripts/gates.sh scripts/check_site.sh scripts/check_storage_contracts.sh"
G70_BAD=""
for f in $G70_SCRIPTS; do
  [ -f "$f" ] || { G70_BAD="$G70_BAD
$f: not in this tree, and the shape cannot be read out of a file that is not there"; continue; }
  found=$(awk '
    { line[NR] = $0 }
    END {
      for (i = 1; i <= NR; i++) {
        s = line[i]
        if (s ~ /^[ \t]*#/) continue
        gsub(/\|\|/, "@@", s)              # «or» is not a pipe
        if (s !~ /\|[ \t]*grep/) continue
        if (s !~ /grep[^|]*-[A-Za-z]*q/) continue
        ok = 0
        for (j = i; j >= i - 3 && j >= 1; j--) {
          if (line[j] ~ /set \+o pipefail/) ok = 1
        }
        if (!ok) printf "%d: %s\n", i, line[i]
      }
    }' "$f")
  [ -n "$found" ] && G70_BAD="$G70_BAD
$f
$found"
done
if [ -z "$G70_BAD" ]; then
  # **Counted off the code and never off the prose.** The first form of these
  # two lines counted the phrase anywhere in the file and reported 15 wrapped
  # streams where there are 11 — the other four are this paragraph and the line
  # above. A counter that reads its own comment is the same fault as a gate
  # that quotes what it forbids, one floor down, and it reached a PASS line.
  # And each pattern is written so that **it cannot match the line it is
  # written on**: the first wants whitespace on both sides of the redirection,
  # the second wants the bracket at the start of a word — and both of these
  # lines carry the shape inside quotes instead. The first form counted 15
  # wrapped streams where there are 11, then 12 when the comment was dropped
  # and the counter still read itself. A measuring tool that answers about
  # itself is this house's oldest instrument fault, and it reached a PASS line
  # twice in five minutes.
  G70_HERE=$(grep -hvE '^[[:space:]]*#' $G70_SCRIPTS | grep -cE '[[:space:]]<<<[[:space:]]')
  G70_WRAP=$(grep -hvE '^[[:space:]]*#' $G70_SCRIPTS | grep -cE '(^|[[:space:]])\( set \+o pipefail[[:space:]]*(;|$)')
  pass "G70 no question in this suite is asked with a writer in front of «grep -q» — $G70_HERE herestring(s) and $G70_WRAP stream(s) wrapped where pipefail must stand aside"
else
  fail "G70 a writer is piped into «grep -q» under pipefail, and its answer can be the writer's:"
  printf '        %s\n' "$G70_BAD"
fi

# ---------------------------------------------------------------- G56
# **Every claim this product makes is in one file, with its limit and its
# proof** — 094, the owner's own order of 19 October 2026: «نجعل ملف مراجعة في
# git نحدد فيه نقاط الادّعاءات التي ندّعيها في التطبيق»، then hand it to an
# outside model to attack.
#
# `docs/CLAIMS.md` is that file and this is what keeps it honest between
# reviews. The checker refuses a section missing one of its four lines — and
# the line a hurried hand drops is **the limit**, which is the whole reason the
# file exists; a path, gate, test or sentence key that does not exist, because a
# proof pointing at a deleted test reads exactly like a proof; and the loss of
# the closing «What we do not claim».
#
# **A claim marked `unproven —` is allowed and counted.** That is the owner's
# instruction, not a loophole: a claim we have not measured stays in the list
# wearing that word, because a claim removed is a claim hidden. The two numbers
# are printed on every gate run, so «how much of what we say is measured» is on
# the record rather than in somebody's memory.
if [ -f scripts/check_claims.py ]; then
  if OUT=$(python3 scripts/check_claims.py 2>&1); then
    pass "G56 every claim has its four lines and everything it names exists —$(printf '%s' "$OUT" | tail -1)"
  else
    fail "G56 a claim is missing its limit, its proof, or something it names:"
    printf '%s\n' "$OUT" | sed 's/^/        /'
  fi
else
  skip "G56 every claim has its limit and its proof" "no checker yet"
fi

# ---------------------------------------------------------------- G53
# **The second platform asks for what the first one measures** — 093, and the
# fault this file has now watched happen twice in one workflow.
#
# `windows-core.yml` asked for `fake_provider` alone when `test_clock` arrived,
# so six tests did not exist in that job and it reported green without them.
# Its own comment says so. By 093 it had happened again for `measuring`: Linux
# had three test features and Windows asked for two. A feature the suite forgets
# to ask for takes its tests with it **silently** — the suite shrinks and still
# says «ok», which is the truth about what ran and a lie about what is safe.
#
# So the two lists are held equal here, from the one place Linux writes them
# down (`TEST_FEATURES` at the top of this file). Read on Linux, about Windows:
# that is the only kind of guard that crosses a seam nobody on this desk can
# run.
#
# Four checks, each the shape of a way the Windows half goes quiet:
#
#  1 — every core feature list in the workflow names what `TEST_FEATURES`
#      names, and the bridge's list is the same three renamed `z_core/…`;
#  2 — the Dart half is there and may not be excused: `flutter test` with no
#      `continue-on-error` anywhere in the file (074's audit found no Dart test
#      on Windows at all, and «it is allowed to fail» is the same silence with
#      a flag on it);
#  3 — the release is proved, not promised: the job runs
#      `scripts/package_windows.sh`, and that script names the runner's own
#      paths as needles beside `/home/`;
#  4 — the one-writer measurement is asked for **by name**, so a test that
#      becomes `#[cfg(unix)]` one day reds here instead of ceasing to exist.
WINDOWS_JOB=.github/workflows/windows-core.yml
PACK_WIN=scripts/package_windows.sh

G53_WANT=$(printf '%s' "$TEST_FEATURES" | sed 's/^--features //' | tr ',' '\n' | sort | paste -sd, -)
# **Comment lines thrown away first, and the prefix of the bridge's own list
# with them** — G46's lesson, paid again here: this gate's first draft counted
# the sentences above the steps, which name the script, the test and
# «continue-on-error» precisely because they explain them. A gate that reads
# prose measures prose. So every census below reads a line of YAML that does
# something: a `run:`, a key, a continued command.
#
# `--features z_core/…` captures as «z_core» under this pattern, because the
# match stops at the slash. That is the bridge's list and it is read on its own
# line below, so it is dropped here by name rather than by luck.
G53_CODE=$(grep -vE '^[[:space:]]*#' "$WINDOWS_JOB" 2>/dev/null)
G53_CORE_LISTS=$(printf '%s\n' "$G53_CODE" | grep -oE -- '--features [a-z_,]+' \
                 | sed 's/^--features //' | grep -v '^z_core$' | sort -u)
G53_BAD=""
while IFS= read -r list; do
  [ -z "$list" ] && continue
  got=$(printf '%s' "$list" | tr ',' '\n' | sort | paste -sd, -)
  [ "$got" = "$G53_WANT" ] || G53_BAD="$G53_BAD «$list»"
done <<EOF
$G53_CORE_LISTS
EOF
G53_BRIDGE=$(printf '%s\n' "$G53_CODE" | grep -oE -- '--features z_core/[a-z_,/]+' \
             | sed 's|^--features ||' | sed 's|z_core/||g' | tr ',' '\n' | sed 's|^ *||' \
             | grep -v '^$' | sort -u | paste -sd, -)
if [ -n "$G53_CORE_LISTS" ] && [ -z "$G53_BAD" ] && [ "$G53_BRIDGE" = "$G53_WANT" ]; then
  pass "G53 the Windows job asks for the test features Linux measures with ($G53_WANT), for the core and for the bridge"
else
  fail "G53 the Windows job's core lists are$G53_BAD and its bridge list is «$G53_BRIDGE» — expected «$G53_WANT»; a feature it does not ask for takes its tests with it silently"
fi

G53_DART=$(printf '%s\n' "$G53_CODE" | grep -c 'flutter test --concurrency=1' || true)
G53_EXCUSED=$(printf '%s\n' "$G53_CODE" | grep -cE '^[[:space:]]*continue-on-error:' || true)
if [ "$G53_DART" = "1" ] && [ "$G53_EXCUSED" = "0" ]; then
  pass "G53 the Dart half runs on Windows, once, and is not allowed to fail quietly"
else
  fail "G53 the Windows job runs the Dart suite $G53_DART time(s) and excuses $G53_EXCUSED step(s) — expected one run and no «continue-on-error»"
fi

G53_PACKS=$(printf '%s\n' "$G53_CODE" | grep -cE '^[[:space:]]*run: bash scripts/package_windows\.sh' || true)
# **The line that searches, not the sentence that explains it.** Pinned: with
# the loop deleted the three needles were still in the file, because the
# comment above it names each one and says why. Twice in one gate — this is the
# single most expensive habit in this house, and it is cheap to measure the
# other way.
G53_NEEDLE_LINE=$(grep -E '^for needle in ' "$PACK_WIN" 2>/dev/null | head -1)
G53_NEEDLES=0
for needle in 'D:\a\' 'C:\Users\runneradmin' '/home/'; do
  grep -qF -- "$needle" <<< "$G53_NEEDLE_LINE" && G53_NEEDLES=$((G53_NEEDLES + 1))
done
if [ "$G53_PACKS" = "1" ] && [ "$G53_NEEDLES" = "3" ] && [ -f "$PACK_WIN" ]; then
  pass "G53 the Windows release is stamped and proved by one script, and it looks for the runner's own paths as well as «/home/»"
else
  fail "G53 the job calls the packaging script $G53_PACKS time(s) and the script names $G53_NEEDLES of the 3 builder paths — a release may not carry the name of the machine that built it"
fi

G53_WRITER=$(printf '%s\n' "$G53_CODE" | grep -cE -- '--test two_copies_never_lose_a_write' || true)
if [ "$G53_WRITER" = "1" ]; then
  pass "G53 the one-writer measurement is asked for by name on Windows, where the lock is LockFileEx"
else
  fail "G53 nothing in the Windows job names two_copies_never_lose_a_write — the one guard the Windows lock is under would stop existing silently"
fi

# ---------------------------------------------------------------- G49
# **One reading of the bench, and every door asks it** — 091, rules 72 and
# 72-أ, the owner's «the chat box is there from the first moment».
#
# Measured by e2 on `8510d82`: with a letter pasted into the box and no
# document in the app, «Choose who answers» worked and «Copy Protected» and
# «Save as PDF» were dead, because `build_payload` refused an empty *document*
# and the manual doors are its readers while the model door asks
# `build_the_question_alone`. One surface, one door open out of four, decided
# by which builder a press happened to use.
#
# Three things, each the shape of a way it comes undone:
#
#  1 — `what_would_leave` is written once and its readers are the four that
#      need it, **named** so that a fifth has to say which of them it is:
#      the builder every door asks, the export door that mints the answer
#      page, the panel that lists the blocks standing on the surface, and —
#      since 55-و — the exit law that births a session for a question leaving
#      with no document (the fourth seat, declared here, as G31 made the exit
#      audit declare itself);
#  2 — `build_payload` asks that function and asks the document nothing, read
#      from its own body with the comment lines thrown away (G46's lesson: a
#      sentence naming a function answered for a deleted line);
#  3 — the export door's mint is decided by the same reading, or the door is
#      open and the PDF press still refuses in its own words.
BENCH=z_core/src/ops/mod.rs

G49_ONE=$(grep -c '^fn what_would_leave(s: &Session) -> WhatWouldLeave {' "$BENCH" 2>/dev/null || echo 0)
G49_SEATS=$(grep -n 'what_would_leave(s)' "$BENCH" 2>/dev/null | wc -l | tr -d ' ')
if [ "$G49_ONE" = "1" ] && [ "$G49_SEATS" = "4" ]; then
  pass "G49 one function says what would leave this bench, read by the builder, the export door, the panel and the exit law"
else
  fail "G49 «what would leave» is written in $G49_ONE place(s) and read in $G49_SEATS — expected one answer and four named readers; a fifth reader declares itself here"
fi

# **And the question alone is assembled once**, reached by the door that lets
# text out and by the instrument that draws it, or what leaves and what is
# drawn are two texts that agree only by luck.
#
# **A third road since the owner's ruling of 24 October 2026**, and it declares
# itself here the way a fifth reader does above: `build_the_chat`, the clipboard,
# which hands a person the payload as it stands — «خارج التطبيق لا يأخذ إلا ما
# يراه المستخدم على الشاشة». It is the same builder on purpose: the whole point
# of that ruling is that what a person carries to a model of their own is what
# would leave, so a second assembler there would be the one place those two
# texts could drift apart. The in-app door adds the exchange before it **on
# top** of this payload, which is the history's own function and not a second
# assembly of the question.
G49_BUILDER=$(grep -c 'the_question_alone(core, session)' "$BENCH" 2>/dev/null || echo 0)
if [ "$G49_BUILDER" = "3" ]; then
  pass "G49 one builder assembles the question alone, reached by three roads: the door, the instrument and the clipboard"
else
  fail "G49 the question alone is assembled from $G49_BUILDER place(s) — expected the one builder, reached by the door, the instrument and the clipboard; a fourth road declares itself here"
fi

G49_BUILD=$(awk '
  /^pub\(crate\) fn build_payload\(/ {inside=1}
  inside && /^}/ {print; inside=0; next}
  inside && $0 !~ /^[[:space:]]*\/\// {print}
' "$BENCH" 2>/dev/null)
if grep -q 'what_would_leave' <<< "$G49_BUILD" \
   && ! grep -q 'original.is_empty()' <<< "$G49_BUILD"; then
  pass "G49 the builder every door asks reads the bench once, and never the document alone"
else
  fail "G49 build_payload decides for itself what is on the bench — an empty document closes three doors again while the fourth stays open"
fi

G49_EXPORT=$(awk '
  /^pub\(crate\) fn payload_to_take_out\(/ {inside=1}
  inside && /^}/ {print; inside=0; next}
  inside && $0 !~ /^[[:space:]]*\/\// {print}
' "$BENCH" 2>/dev/null)
if grep -q 'what_would_leave' <<< "$G49_EXPORT" \
   && ! grep -q 'original.is_empty()' <<< "$G49_EXPORT"; then
  pass "G49 the answer page is minted for whatever would leave, by that same reading"
else
  fail "G49 the export door asks the document whether to mint an answer page — the PDF press then refuses a text the door let through («its answer page had no token»)"
fi

# ---------------------------------------------------------------- G48
# **A word that names a field is not a value, and a value does not stand inside
# our own token** — the attacker's B1-3 of 17 October, both halves.
#
# He typed `… Frau Katrin Sommer? IBAN DE89 …` about a letter already protected
# to the end. The label left as a `PERSON` token whose value was four letters,
# and the exit audit then counted those four letters inside every
# `__Z_…_IBAN_…__` in the payload and refused to build: copy, PDF, pull and
# send all closed on that document, and on `34ed785` the chat with them, until
# a protection nobody asked for was undone.
#
# Three things, each the shape of a way it could come undone:
#
#  1 — the scanner asks the label vocabulary before any layer's candidate
#      becomes a finding, read from the body of `scan` and not from the file;
#  2 — **one** function answers «which words name a field», so the boundary a
#      grouped value stops at and the name a label is not cannot drift apart;
#  3 — the audit cannot count without being told which stretches are ours: the
#      counting function takes the spans, so a caller that forgets them does
#      not compile; it asks **once**, over both texts at once (G31's fourth
#      seat), counts both sides of its bound by that one answer, and hands
#      neither side an empty list — one definition of «where a value stands»,
#      or the bound is not about one thing.
SCAN_C=z_core/src/scanner/mod.rs
RULES_C=z_core/src/scanner/rules.rs
PAYLOAD_C=z_core/src/payload.rs

# Comment lines thrown away first, for G46's own reason: a sentence naming the
# function would otherwise answer for a deleted line.
G48_LAW=$(awk '
  /^pub\(crate\) fn scan\(/ {inside=1}
  inside && /^}/ {print; inside=0; next}
  inside && $0 !~ /^[[:space:]]*\/\// {print}
' "$SCAN_C" 2>/dev/null)
if grep -q 'is_label_word' <<< "$G48_LAW"; then
  pass "G48 no layer's candidate may be a word that names a field, asked once over the text"
else
  fail "G48 the scanner settles its findings without asking whether one of them is a label — «IBAN» becomes a person again"
fi

G48_ANSWERS=$(grep -c '^\(pub(crate) \)\?fn is_label_word(' "$RULES_C" 2>/dev/null || echo 0)
G48_READERS=$(grep -Rln 'is_label_word(' z_core/src 2>/dev/null | sort | tr '\n' ' ')
if [ "$G48_ANSWERS" = "1" ] \
   && [ "$G48_READERS" = "z_core/src/scanner/mod.rs z_core/src/scanner/rules.rs " ]; then
  pass "G48 one function says which words name a field, and both readers ask it"
else
  fail "G48 «which words name a field» is answered in $G48_ANSWERS place(s) and read in «$G48_READERS» — expected one answer, read by the scanner and by the grouped boundary"
fi

G48_COUNT=$(grep -c '^fn count(haystack: &str, needle: &str, ours: &\[(usize, usize)\]) -> usize {' "$PAYLOAD_C" 2>/dev/null || echo 0)
G48_BODY=$(awk '
  /^    pub\(crate\) fn audit\(/ {inside=1}
  inside && /^    }/ {print; inside=0; next}
  inside && $0 !~ /^[[:space:]]*\/\// {print}
' "$PAYLOAD_C" 2>/dev/null)
# **One ask, two counts, and no empty list** — the three ways this fix comes
# undone, and the only three. The signature means no caller can leave the spans
# out at all, so what is left is asking for them once (G31's fourth seat),
# giving one to each side of the bound, and not handing either side an empty
# list to shut the law up without deleting it.
G48_SPANS=$(printf '%s\n' "$G48_BODY" | grep -c 'token_spans(')
G48_SIDES=$(printf '%s\n' "$G48_BODY" | grep -c 'count(&')
G48_EMPTY=$(printf '%s\n' "$G48_BODY" | grep -cE 'Vec::new\(\)|&\[\]')
if [ "$G48_COUNT" = "1" ] && [ "$G48_SPANS" = "1" ] \
   && [ "$G48_SIDES" = "2" ] && [ "$G48_EMPTY" = "0" ]; then
  pass "G48 the audit asks once where our own tokens stand, counts both sides of its bound by it, and hands neither an empty list"
else
  fail "G48 the counting signature is in $G48_COUNT place(s); the audit asks for the spans $G48_SPANS time(s), counts $G48_SIDES side(s) and passes $G48_EMPTY empty list(s) — expected 1 · 1 · 2 · 0"
fi

# ---------------------------------------------------------------- G45
# **An attribute belongs immediately above the item it is about** — the trap
# this crate has carried three times, and the lead caught the third on
# 17 October 2026.
#
# Inserting a function «above the signature» puts it **below** the doc comment
# and below the attributes, which belong to the item that is now one item
# further down. In `text.rs` the new `their_own_word` landed between
# `utf16_len`'s `///` line and its `#[allow(dead_code)]` and its own signature:
# the doc and the allowance moved onto the new function, and `utf16_len` was
# left with neither. The same insertion made `Scope` carry two doc blocks with
# a `derive` between them — «how long a protection lasts» above the derive and
# «how far a protection reaches» below it — since task 034.
#
# The shape is cheap to read and almost never legal prose: **an attribute line
# followed immediately by a doc line**. Rust accepts it (every doc comment and
# attribute before an item applies to that item), so neither rustc nor clippy
# says a word — and that is exactly why it survived three rounds. The rule this
# gate holds is the ordinary one: doc first, attributes last, the item next.
#
# It found three the day it was written: the two above and one interleaved
# `#[allow(dead_code)]` in `vault/crypto.rs`, which was harmless and unreadable
# in the same way.
G45_FUSED=$(awk '
  prev ~ /^[[:space:]]*#\[/ && $0 ~ /^[[:space:]]*\/\/\// {
    print FILENAME ":" FNR ": " prev " ⟶ " $0
  }
  { prev = $0 }
' $(find z_core/src bridges -name '*.rs' | sort) 2>/dev/null || true)
if [ -z "$G45_FUSED" ]; then
  pass "G45 every attribute stands immediately above the item it is about, so no doc comment belongs to the wrong one"
else
  fail "G45 an attribute is separated from its item by a doc comment — whatever follows has taken the item above's doc and attributes:"
  printf '%s\n' "$G45_FUSED" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G44
# **A word of the person's own, inside a sentence of ours, is isolated** — the
# owner's test of 16 October 2026, held as a class since 17 October.
#
# His session is called «ألماني 1», and inside an English line the
# bidirectional algorithm pulled the digits and the quotes into the Arabic run:
# «This document came back from «11 .«ألماني names stay…» — every word correct
# and the order nonsense. The fix is one pair of characters, `U+2068` and
# `U+2069`, and the law was written at one sentence out of forty.
#
# **Both sides, because a sentence can be written on either.** The glass calls
# `theirOwnWord`, the core calls `text::their_own_word`, and the core's reach
# is the one that matters most: what the app is handed is a finished string,
# with nothing left to isolate.
#
# The signal is the quotation marks this house puts round a quoted word: a «»
# with an interpolation **inside** it. The isolated form reads `«{}»` with the
# function in the arguments, so what this looks for is the shape that is left
# when nobody called it.
#
# **Our own words are not in this law and must not be wrapped**: a language id,
# a pack, a rule set's name, a kind, a handle like «doc1». They are ours, they
# are already in the sentence's direction, and a pair of invisible characters
# round them would be two characters with nothing to do. Each one is allowed
# here by name, with its reason.
G44_ALLOWED_RUST='«\{pack_id\}
«\{missing\}'
# 1 · `«{pack_id}»` — a language id this build knows (de, en, sv). The app
#     chooses it from the core's own list; a person never types it.
# 2 · `«{missing}»` — the name of a rule set, also ours: the screen offers the
#     sets the core reports and sends one back.
G44_RUST=$(find z_core/src -name '*.rs' | sort | xargs awk '
  # Stop at the test module: an assertion message is not a sentence a person
  # reads. Both spellings, because `secure_file.rs` gates its tests on the
  # platform too.
  FNR == 1 { testing = 0 }
  /^#\[cfg\((all\()?test[,)]/ { testing = 1 }
  testing { next }
  /^[[:space:]]*(\/\/|\/\/\/)/ { next }
  /«\{[a-zA-Z_]/ { print FILENAME ":" FNR ": " $0 }
' 2>/dev/null || true)
G44_RUST_LEFT=$(printf '%s\n' "$G44_RUST" | grep . | grep -vE "$(printf '%s' "$G44_ALLOWED_RUST" | paste -sd'|' -)" || true)
if [ -z "$G44_RUST_LEFT" ]; then
  pass "G44 every word of the person's own that the core quotes is isolated ($(printf '%s\n' "$G44_RUST" | grep -c .) quoted, all of them ours by name)"
else
  fail "G44 the core quotes these without isolating them — an Arabic or German word here takes the punctuation with it (or they are ours, and belong in G44's allowed list with a reason):"
  printf '%s\n' "$G44_RUST_LEFT" | sed 's/^/        /'
fi

# And the glass, where the same law is one function away.
G44_ALLOWED_DART='«\$\{?list\.name
«\$name» is (in use again|off)
Forgot «\$name» and'
# 1 · `list.name` and the `$name` beside it — a list **is** a language and the
#     core refuses any name it does not know (`clean_list_name`), so the word
#     in these three sentences is ours even though a person pressed to get it.
#
# **And `lib/l10n/` is not read by this half, since 092.** A sentence in the
# one list is drawn by the generated class as `'Delete «$name»?'` — the
# sentence and its caller are now in different files, so no line of the
# generated Dart can ever carry `theirOwnWord`, and nobody could edit it if it
# did. Silencing it there alone would have left the law unguarded for every
# migrated sentence, which is why the half below this one exists: it reads the
# **list** and the **callers**, where both parts of the pair are still visible.
G44_DART=$(grep -RnE '«\$' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' | grep -v '/l10n/' \
           | grep -vE ':[0-9]+:[[:space:]]*(//|///)' || true)
G44_DART_LEFT=$(printf '%s\n' "$G44_DART" | grep . | grep -v 'theirOwnWord' \
                | grep -vE "$(printf '%s' "$G44_ALLOWED_DART" | paste -sd'|' -)" || true)
if [ -z "$G44_DART_LEFT" ]; then
  pass "G44 every word of the person's own that a screen quotes goes through theirOwnWord"
else
  fail "G44 these sentences quote a word of the person's own without isolating it (or it is ours, and belongs in G44's allowed list with a reason):"
  printf '%s\n' "$G44_DART_LEFT" | sed 's/^/        /'
fi

# **The same law for a sentence that has moved into the one list** — 092.
#
# A value in `lib/l10n/app_en.arb` that quotes a placeholder — `«{name}»` — is
# a sentence about a word the person chose, and the isolate is applied by
# whoever calls it. So for each such key, every call of `sentences.<key>(` in a
# hand-written file must wrap its argument in `theirOwnWord`.
#
# **Why the pair is not inside the value instead**, where no caller could
# forget it: `gen-l10n` writes the raw code points into the generated Dart and
# the analyzer flags every one of them (`text_direction_code_point_in_literal`)
# in a file nobody can fix — eight unfixable warnings for one sentence, which
# would hide the next real one. Measured on 19 October, then reversed, and this
# gate is what was bought with the reversal.
G44_ARB=$FLUTTER_LIB/l10n/app_en.arb
G44_LIST_BAD=""
G44_QUOTING=""
if [ -f "$G44_ARB" ]; then
  # The list is one key per line, so the key of a value that quotes a
  # placeholder is read off the same line as the quote.
  G44_QUOTING=$(grep -oE '"[A-Za-z0-9_]+": "[^"]*«\{' "$G44_ARB" 2>/dev/null \
                | sed -E 's/": ".*$//; s/^"//' | sort -u || true)
  for KEY in $G44_QUOTING; do
    CALLS=$(grep -RnE "sentences\.$KEY\(" "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
            | grep -v '/l10n/' | grep -vE ':[0-9]+:[[:space:]]*(//|///)' || true)
    if [ -z "$CALLS" ]; then
      G44_LIST_BAD="$G44_LIST_BAD«$KEY» quotes a word of the person's own and nothing calls it
"
      continue
    fi
    # **The call, and the three lines under it.** A call with two arguments is
    # written over several lines by `dart format`, and the isolate was on the
    # line *after* the call — so a one-line look refused a caller that does
    # isolate its word. Measured on
    # `entity_detail.dart`'s `identityAndItsValuesAreRemoved`.
    while IFS= read -r SITE; do
      [ -z "$SITE" ] && continue
      SITE_FILE=${SITE%%:*}
      SITE_REST=${SITE#*:}
      SITE_LINE=${SITE_REST%%:*}
      if ! ( set +o pipefail; sed -n "${SITE_LINE},$((SITE_LINE + 3))p" "$SITE_FILE" \
                 2>/dev/null | grep -q 'theirOwnWord' ); then
        G44_LIST_BAD="$G44_LIST_BAD$SITE
"
      fi
    done <<EOF
$CALLS
EOF
  done
fi
if [ -z "$G44_LIST_BAD" ]; then
  pass "G44 every sentence in the one list that quotes a person's own word is called through theirOwnWord ($(printf '%s\n' "$G44_QUOTING" | grep -c . || true) such sentence)"
else
  fail "G44 a sentence in the one list quotes a word of the person's own and its caller does not isolate it:"
  printf '%s\n' "$G44_LIST_BAD" | grep . | sed 's/^/        /'
fi

# **And one function on each side, not a pair of characters written by hand.**
# The core's own sentence for a taught rule carried `\u{2068}…\u{2069}` inline
# until 17 October, which is how a law comes to be applied at the one place
# somebody remembered.
G44_HAND=$(grep -RnE '\\u\{2068\}|\\u2068' z_core/src "$FLUTTER_LIB" --include='*.rs' --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' \
           | grep -vE 'text\.rs:[0-9]+:[[:space:]]*format!' \
           | grep -vE 'messages\.dart:[0-9]+:String theirOwnWord' \
           | grep -vE ':[0-9]+:[[:space:]]*(//|///)' || true)
if [ -z "$G44_HAND" ]; then
  pass "G44 the isolate is one function on each side, and nothing writes the pair by hand"
else
  fail "G44 the isolate pair is written out here instead of called, so the next sentence that needs it has nowhere to look:"
  printf '%s\n' "$G44_HAND" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G43
# **One copy of this program writes at a time** — the independent attacker's م5
# and خ9, 17 October 2026.
#
# He ran two copies against one vault, forty trials: in three of them both said
# `ok` and the disk held one write. The gap is between
# `Vault::ensure_disk_unchanged` and the `rename` inside `replace_atomically`,
# and the session file compared nothing at all — `conversation::write` sealed a
# body and replaced the file, so the later `rename` won and the earlier turn
# was gone with nobody told.
#
# The answer is an exclusive lock held for the whole of a core call, because the
# loss was never inside one write: it was a **read and a write with a gap
# between them**. `session::with_core` is the one boundary every such pair is
# already inside — so that is where it is taken, and this gate reads it there.
#
# Two checks, and the second is the one that keeps the first safe: a second
# place taking the same lock would be a second acquisition in one process, and
# `flock` on a second handle blocks against the first.
G43_CORE=z_core/src/session.rs
if awk '
  /^pub\(crate\) fn with_core<R>/ { inside = 1 }
  inside && /one_writer_at_a_time\(/ { found = 1 }
  inside && /^}$/ { inside = 0 }
  END { exit(found ? 0 : 1) }
' "$G43_CORE" 2>/dev/null; then
  pass "G43 every core call holds the one-writer lock, so a read and its write cannot be split"
else
  fail "G43 with_core does not take the one-writer lock — two copies can lose a write between them (م5)"
fi

G43_TAKERS=$(grep -Rn 'one_writer_at_a_time(' z_core/src --include='*.rs' 2>/dev/null \
             | grep -v 'z_core/src/secure_file.rs:' \
             | grep -vE ':[0-9]+:[[:space:]]*(//|///)' || true)
G43_N=$(printf '%s\n' "$G43_TAKERS" | grep -c . || true)
if [ "$G43_N" = "1" ] && grep -q 'session.rs' <<< "$G43_TAKERS"; then
  pass "G43 one place takes the lock, and it is the boundary every write is inside"
else
  fail "G43 the one-writer lock is taken in $G43_N place(s), expected one in session.rs — a second is a deadlock against the first:"
  printf '%s\n' "$G43_TAKERS" | sed 's/^/        /'
fi

# ---------------------------------------------------------------- G47
# **The answer is coded in the thread, and the names come back in one place**
# — rule 66, the owner, 17 October 2026: «تظهر الإجابة داخل الشات مرمزة مع زر
# عرض النص ليظهر في فقاعة… لا يظهر الجواب مباشرة بلا ترميز».
#
# Two sides of one law, and the second is the one a later round would break by
# accident: the thread draws what **travelled** — the coded strings the core
# stored — and the restored text, with the real values in it, is drawn in the
# bubble a press opens and nowhere else. A panel that drew the restored
# segments in the thread would put a person's own names on the glass with
# nothing asked for, which is the whole of what rule 66 forbids.
#
# Read from the source by **class**, the way G42 read the chat's door: a
# `TurnRow`'s restored side is `.answer`, and the only class allowed to touch
# it is the bubble's state. `.answerAsWritten` is the coded one and is
# deliberately not matched — the pattern ends at a non-letter, so the two
# cannot be confused.
CHAT_DART=$FLUTTER_LIB/widgets/the_chat.dart
if [ -f "$CHAT_DART" ]; then
  G47_RESTORED=$(awk '
    /^class [_A-Za-z]+/ { cls = $2 }
    /\.answer[^A-Za-z]/ { if (cls != "") print cls }
  ' "$CHAT_DART" | sort -u | tr '\n' ' ' | sed 's/ $//')
  if [ "$G47_RESTORED" = "_BubbleState" ]; then
    pass "G47 the restored answer is drawn in one class, and it is the bubble a press opens"
  else
    fail "G47 the restored side of a turn is read in «$G47_RESTORED» — expected «_BubbleState» only (rule 66)"
  fi
  # And the coded sides go through the painter the Safe column uses, so a token
  # is drawn the same way wherever a person meets it — never as bare text.
  if grep -q 'child: SafeText(text: text, chips: false)' "$CHAT_DART"; then
    pass "G47 the thread draws what travelled with the Safe column's own painter"
  else
    fail "G47 the chat draws the coded sides itself — a token must look the same wherever it stands"
  fi
else
  fail "G47 widgets/the_chat.dart is missing — the third part of the one screen is not built (rule 65)"
fi

# ---------------------------------------------------------------- G42
# **Nobody reaches the three exits without the outgoing text on the glass** —
# rule 60 and the owner's rule 60-أ, 17 October 2026.
#
# Rule 60 deleted the sheet's own page of outgoing text because the work
# surface draws it already. That is a premise about a screen, and this gate is
# what keeps it true: the preview side can be closed by a press and stays
# closed, and the chat has no side at all. The measured breach, in `2fb90b3`:
# **deleting the page took the «see what will leave» step out of the chat**,
# because the chat opens the same sheet. 60-أ is the owner's answer — «Ask the
# AI» protects the line and draws it in a band, and the band carries the door.
#
# So the doors are enumerated **from what they do**: a place that builds a
# `SendSheet` is a door, whatever it is called, and each must come through a
# hand that has put the text in front of the person first.
#
# **One hand again since rule 70** (17 October). There were two, because there
# were two screens and they kept the text in front of a person in two different
# ways; the first screen is gone, so the hand that was written for it is gone
# with it — see the note where its own check stood, below.
SEND_SHEET=$FLUTTER_LIB/widgets/send_sheet.dart
G42_BUILT=$(grep -Rn 'SendSheet(' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
            | grep -v '/src/rust/' | grep -v "^$SEND_SHEET:" \
            | grep -vE ':[0-9]+:[[:space:]]*(//|///|\*)' || true)
if [ -z "$G42_BUILT" ]; then
  pass "G42 every door to the three exits is built by the one hand, in send_sheet.dart"
else
  fail "G42 these places build the send sheet themselves, so nothing makes them show the text first:"
  printf '%s\n' "$G42_BUILT" | sed 's/^/        /'
fi

# **The work surface's hand opens the side it reads the text in.** Measured in
# the hand's own body: a hand that stopped writing this would open the exits
# over a closed side, which is rule 60's premise broken on the glass.
G42_SIDE=$(awk '
  /^Future<bool\?> theWayToTheDoors\(/ { inside = 1 }
  inside && /safeColumnOpen: true/ { found = 1 }
  # **`^}$` and not `^}`** — a Dart named-parameter list closes at column zero
  # («}) async {»), so the looser marker ended the body on its own signature
  # and this check read «BLIND» over a hand that does open the side. Found by
  # running it before trusting it.
  inside && /^}$/ { inside = 0 }
  END { print (found ? "opens" : "BLIND") }
' "$SEND_SHEET" 2>/dev/null || true)
if [ "$G42_SIDE" = "opens" ]; then
  pass "G42 the work surface's hand opens the preview side before the exits"
else
  fail "G42 the work surface's hand no longer opens the preview side — a closed side and the three exits can stand together"
fi

# **The chat's own door is gone, and with it the case it was written for** —
# rule 70 settles rule 60-أ's first half, 17 October.
#
# This read `theWayToTheDoorsFromTheChat` out of the source and asked whether
# the class that called it also drew the outgoing text (`SafeText`), because the
# first screen's chat had no preview side to open: the law «what leaves is seen»
# was held there by the door standing *inside* the band that drew the text. One
# screen with three parts has no such state — every question is asked beside the
# middle column, which draws what will leave — so the hand, the band and this
# check are deleted together rather than left as a check over nothing. **An
# exception that matches nothing is a finding, not a comfort**, and a check whose
# subject no longer exists is the same shape: it would have gone on passing by
# measuring an empty list.
#
# What is still measured, above: every `SendSheet` in the app is built by the one
# hand in `send_sheet.dart`, and that hand opens the preview side first.

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
#
# **55-و adds the second cause, 18 October: a question that leaves with no
# document is a session too** — «the chat without a document is a whole
# session». One birth, two causes, and they are enumerated here so that a third
# has to declare itself: the document entering the preview, and the exit law
# `ops::a_session_for_what_leaves`. Before it, that law lived in the *screen*,
# which began a session of its own whenever an exit found none open — one law
# in two languages, and the quieter copy wins the day they disagree.
#
# **And a read never births.** The workspace snapshot asks `build_payload` on
# every read to draw the Safe column, and since 091 that answers a question-only
# bench; a birth on that road would make a session out of a question nobody
# sent, which is this gate's own «no empty sessions» lost to the fix meant to
# honour it.
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
G37_WHERE=$(awk '
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /a_session_is_born\(core/ && $0 !~ /^[[:space:]]*\/\// { if (here != "" && here != "a_session_is_born") print here }
' $BORN z_core/src/ops/mod.rs | sort -u | tr '\n' ' ' | sed 's/ $//')
G37_ONCE=$(grep -c '^pub(crate) fn a_session_is_born(' "$BORN" 2>/dev/null || echo 0)
if [ "$G37_ONCE" = "1" ] && [ "$G37_WHERE" = "a_session_for_what_leaves keep_the_preview" ]; then
  pass "G37 one silent birth, caused twice: a document entering the preview, and a question leaving with none"
else
  fail "G37 the silent birth is written $G37_ONCE time(s) and caused from «$G37_WHERE» — expected one, from «a_session_for_what_leaves keep_the_preview» and nothing else"
fi

# **A read never births.** The instrument the snapshot draws the Safe column
# with must not ask the exit law, or «no empty sessions» is lost on the one
# surface the law was written for.
G37_DRAWN=$(awk '
  /^pub\(crate\) fn build_payload\(/ {inside=1}
  inside && /^}/ {print; inside=0; next}
  inside && $0 !~ /^[[:space:]]*\/\// {print}
' z_core/src/ops/mod.rs 2>/dev/null | grep -c 'a_session_for_what_leaves')
G37_LAW=$(grep -c 'a_session_for_what_leaves(' z_core/src/ops/mod.rs 2>/dev/null || echo 0)
if [ "$G37_DRAWN" = "0" ] && [ "$G37_LAW" = "3" ]; then
  pass "G37 the exit law is one function asked by the two exits that build, and a read births nothing"
else
  fail "G37 the snapshot's instrument asks the exit law $G37_DRAWN time(s) and the law is written and read $G37_LAW — expected a read that births nothing, and one definition plus two exits"
fi

# **No empty sessions.** The question «is there a document here» is asked
# before anything is born, in the same function and above it — a session in the
# list holding nothing is the defect this order prevents.
if awk '
  /^pub\(crate\) fn keep_the_preview\(/ { inside = 1 }
  inside && /trim\(\)\.is_empty\(\)/ { asked = NR }
  inside && /a_session_is_born\(/ { born = NR }
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
# **One door since rule 70**, and it was two: `_askFromHome` read the first
# screen's own question into a session of its own, and that screen is gone. The
# name is still read out of the source rather than remembered, so a second door
# written tomorrow has to tell the list too.
if [ "$G37_IMPORTS" = "$FLUTTER_LIB/screens/shell.dart" ] \
   && [ "$G37_DOORS" = "_begin" ] && [ -z "$G37_QUIET" ]; then
  pass "G37 every door a document enters the preview by tells the list it was kept"
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
# The census found a fourth door the first three were written without, and it
# was the mode in which a person sent the document as it stands. **Rule 62
# deleted it** (the owner, 17 October), so the census went back to three — and
# **rule 65 added a real fourth the same week**: `chat_to_take_out`, the copy of
# the chat. Both moves were read off what the functions do rather than off a
# list somebody keeps, which is why taking a door away moves this line as
# surely as adding one does.
#
# `DOORS_OUT` is this census, and G28 reads it too: the law «nothing leaves
# while a word waits» is asked of every door this line finds, so the two gates
# cannot disagree about how many doors there are.
DOORS=z_core/src/ops/mod.rs
KEPT=z_core/src/ops/conversation.rs

# **And it is read as the act, not as one spelling of it.** The first version of
# this line looked for `payload_view(build_…(` — the two halves written as one
# expression — and the chat door was written that way until it had to hand its
# handle back beside the text. One statement became two, the pattern stopped
# matching, and the census said three doors about a tree that had four. It
# failed, which is the safe direction; it failed because it was reading
# punctuation. So each function is asked for the two things that make it a door:
# does it **build** a payload, and does it **hand the text** to its caller — in
# either order, in however many statements. Reaching a provider is the other way
# in.
DOORS_OUT=$(awk '
  function verdict() { if (here != "" && (prov || (built && handed))) print here }
  /^(pub\(crate\) )?fn [a-z_]+/ {
    verdict()
    match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3)
    prov = 0; built = 0; handed = 0
  }
  # The tests at the foot of the file are not doors, and they build payloads and
  # read views by the dozen. Without this the last function in the file wears
  # all of it: measured, with `switch_pack` named a door that takes text out.
  /^#\[cfg\(test\)\]/ { verdict(); here = ""; prov = 0; built = 0; handed = 0 }
  /crate::gateway::send\(|crate::providers::ask\(/ { prov = 1 }
  /= *build_[a-z_]+\(|payload_view\(build_/ { built = 1 }
  /payload_view\(/ { handed = 1 }
  END { verdict() }
' "$DOORS" | sort -u | tr '\n' ' ' | sed 's/ $//')
if [ "$DOORS_OUT" = "ask_model chat_to_take_out payload_to_take_out send" ]; then
  pass "G36 four doors take text out of this machine, and the list is the measured one"
else
  fail "G36 the doors that take text out are: $DOORS_OUT — expected «ask_model chat_to_take_out payload_to_take_out send», so a door appeared that nobody measures"
fi

# **And every door that takes text out takes the preview's copy with it — with
# one named exception, and the name carries its reason.** `chat_to_take_out`
# hands out the turns of a chat, and every one of them left this machine through
# one of the other three, which took the copy with it then. Calling it there
# would delete the copy of whatever document is on the bench *now*, which may
# never have left:
# `copying_the_chat_leaves_a_document_that_never_left_in_the_preview` is the
# measurement, and it is what makes this line an exception rather than a hole.
G36_STAYS=""
for door in ask_model payload_to_take_out send; do
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
  pass "G36 every door that takes text out takes the preview's copy with it, and the chat door says why it does not"
else
  fail "G36 these doors take text out and leave the saved copy behind:$G36_STAYS"
fi

# And the exception is **declared where it is made**, so a reader of the code
# meets the reason before a reader of this file does.
if grep -q 'does not take the preview.s copy out, and that is a reason, not an' "$DOORS"; then
  pass "G36 the one door that keeps the preview's copy says so in its own words"
else
  fail "G36 chat_to_take_out is an exception to rule 9 with no reason written at it"
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

# **And one function writes a session's file** — paper 102 §3's shape, read
# here because paper 109 measured what that guard actually reaches: every
# writer of a body reads the file first inside the same lock, so the guard
# catches a read that went stale *between* a read and a write, and no first
# press can redden it. So what holds the shape is this census — one writer, in
# the one place the guard is. A second writer would be a write nobody checks,
# which is the same shape as a second hand removing a copy above.
#
# **It reads code and not comments**, because the sentence above `write_body`
# names this very call: a gate that quotes what it counts counts its own
# prose, and the function it would then name is whichever one happens to sit
# above the doc block.
G36_WRITER=$(awk '
  /^[[:space:]]*(\/\/|\*)/ { next }
  /^(pub\(crate\) )?fn [a-z_]+/ { match($0, /fn [a-z_]+/); here = substr($0, RSTART + 3, RLENGTH - 3) }
  /crate::conversation::write\(/ { print here }
' "$KEPT" | sort -u | tr '\n' ' ' | sed 's/ $//')
G36_ELSEWHERE=$(grep -rn 'conversation::write(' z_core/src --include='*.rs' \
                  | grep -v "^$KEPT:" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*(//|\*)' || true)
if [ "$G36_WRITER" = "write_body" ] && [ -z "$G36_ELSEWHERE" ]; then
  pass "G36 one function writes a session's file, and it is the one that refuses another owner's bytes (102 §3)"
else
  fail "G36 a session's file is written by «$G36_WRITER» and from outside $KEPT, so a write can get past the 102 §3 guard"
  printf '%s\n' "$G36_ELSEWHERE" | sed 's/^/        /'
fi

# **The session file's own version moved, and the table says so.** The third of
# the three numbers, and the one rule 9 spends: a saved document is in the
# conversation's file, not in the vault's body.
# **The number is written here on purpose**, so that moving the format reds
# this check and a person has to come and say «yes, 7» — the table beside the
# constant is compared by G35, and a check that only compared the two would
# have let both move in one commit with nobody told. 7 since rule 55-ز
# (22 October 2026): the request the person typed, with the covers on it.
G36_FMT=$(grep -oE 'SESSION_FORMAT_VERSION: u16 = [0-9]+' z_core/src/conversation.rs | grep -oE '[0-9]+$')
if [ "$G36_FMT" = "7" ] && grep -q "SESSION_FORMAT_VERSION\` = 7 |" z_core/src/vault/format.rs; then
  pass "G36 the session file is at format 7, and the fence table names it"
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
if [ "$G36_DART_N" = "1" ] && grep -q 'screens/shell.dart' <<< "$G36_DART"; then
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
if ( set +o pipefail; grep -A 12 'fn words_it_named' z_core/src/tokens.rs 2>/dev/null \
     | grep -q 'ANSWER_PAGE_WORD' ); then
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
elif grep -q 'SessionId' <<< "$G34_SIG"; then
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
if [ "$G34_DART_N" = "1" ] && grep -q 'screens/shell.dart' <<< "$G34_DART"; then
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
    $0 ~ "^(pub\\(crate\\) )?fn " d "\\(" {inside=1}
    inside && /^}/ {print; inside=0; next}
    inside {print}
  ' "$DOORS")
  if [ -z "$BODY" ]; then
    G29_BAD="$G29_BAD $door(missing)"
  elif ! grep -q 'the_scan_that_arrives_with_the_document(' <<< "$BODY"; then
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
if [ "$G29_DART_N" = "1" ] && grep -q 'core/session_state.dart' <<< "$G29_DART"; then
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
#
# **The list is the census's, not a hand list** — the attacker's lesson of 17
# October, twice over: a census that names its members is green on the day a
# fourth door is added. `DOORS_OUT` is read from what the functions *do* (G36
# below, where it is built), so a door that reaches a provider or hands the
# protected text to its caller is in this loop the moment it exists.
#
# And the signature is read with the `pub(crate)` optional, because a door the
# census finds may be a private one: pinned with a fifth door that was `fn`
# rather than `pub(crate) fn`, this loop said «missing» about a door that was
# right there. It failed, which is the safe direction, and it failed for the
# wrong reason — which is the one a later reader would believe.
G28_BAD=""
for door in $DOORS_OUT; do
  BODY=$(awk -v d="$door" '
    $0 ~ "^(pub\\(crate\\) )?fn " d "\\(" {inside=1}
    inside && /^}/ {print; inside=0; next}
    inside {print}
  ' "$LAW")
  if [ -z "$BODY" ]; then
    G28_BAD="$G28_BAD $door(missing)"
  elif ! grep -q 'no_word_waits(' <<< "$BODY"; then
    G28_BAD="$G28_BAD $door"
  fi
done
if [ -z "$G28_BAD" ]; then
  pass "G28 every exit asks the one law: $(printf '%s' "$DOORS_OUT" | tr '\n' ' ')"
else
  fail "G28 an exit does not ask no_word_waits():$G28_BAD"
fi

# And nothing on the glass asks the exit door for itself. The order's one
# helper asks it, out where a guard can drive it, and each press is a line that
# takes what it is handed — the shape 081 left behind and 083a keeps.
G28_DART=$(grep -Rn 'payloadToTakeOut' "$FLUTTER_LIB" --include='*.dart' 2>/dev/null \
           | grep -v '/src/rust/' || true)
G28_DART_N=$(printf '%s\n' "$G28_DART" | grep -c . || true)
if [ "$G28_DART_N" = "1" ] && grep -q 'core/session_state.dart' <<< "$G28_DART"; then
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

# ------------------------------------------------------------ G50 and G51
# **The sentences in one list** — 092, the owner, 18 October 2026: «نحتاج الآن
# أن نعقد قوائم الجمل قائمة باللغة الإنكليزية، ثم نقوم بنسخها إلى اللغات
# الأخرى، ثم نقوم بتفعيل الترجمة داخل التطبيق».
#
# Two gates in one checker, because they are two halves of one question — is
# every sentence in the list, and does the list carry every language:
#
#   * **G50** no user-facing sentence outside `lib/l10n/*.arb`. A migrated file
#     holds none; a file not yet migrated is named with the count it still
#     holds, and a **rise** is a failure. The list of what is owed is the debt
#     in writing — the shape G41's own allowed list has, and for the same
#     reason: a gate that forbids everything on the day the work starts is a
#     gate somebody turns off. The named exceptions are in the checker, each
#     with its reason.
#   * **G51** every key of the English file is in the German and the Swedish,
#     and no value in either is the English one — a copy is a key nobody
#     translated. The Swedish **was** the English until 23 October 2026 (56-أ,
#     which said the first screen offers Svenska on the day those values
#     differ); paper 106 wrote the Swedish words on the owner's word, so the
#     exception is gone and both languages answer the same rule. The few values
#     a language really does share with the English are named in the checker,
#     each with its reason.
#
# The checker is a file of its own because the question is about JSON, and the
# reasons are prose that belongs beside the rule rather than inside a `case`.
if [ -f scripts/check_the_one_list.py ]; then
  if OUT=$(python3 scripts/check_the_one_list.py 2>&1); then
    pass "G50/G51 the sentences are in one list, and the list carries every language — $OUT"
  else
    fail "G50/G51 a sentence is outside the one list, or a language is missing one:"
    printf '%s\n' "$OUT" | sed 's/^/        /'
  fi
else
  skip "G50/G51 the sentences are in one list" "no checker yet"
fi

# ------------------------------------------------------------------ G65
# **And a guard may not type a sentence the list owns** — 092, sitting five,
# item 2. The screens were the first half of the debt; the guards were the
# other. 284 finders of 458 typed a value out of `app_en.arb` when this was
# measured, 342 of 646 after the first item moved eighteen files in — the debt
# grew because the list did.
#
# While the suite reads English each of them is correct, and that is the trap:
# a reworded value reddens a guard for the wrong reason, and where the
# assertion is `findsNothing` it leaves one **green** for the wrong reason.
#
# There is no floor here, unlike the one list's own table: the thirty-three
# that remain are each in one of two classes the checker names — a text the
# glass draws from somewhere that is **not** this list, and an English that two
# keys share on purpose. A thirty-fourth is somebody typing a sentence again.
if [ -f scripts/check_no_typed_sentence.py ]; then
  if OUT=$(python3 scripts/check_no_typed_sentence.py 2>&1); then
    pass "G65 no guard types a sentence the one list owns — $OUT"
  else
    fail "G65 a guard types a sentence the one list owns:"
    printf '%s\n' "$OUT" | sed 's/^/        /'
  fi
else
  skip "G65 no guard types a sentence the one list owns" "no checker yet"
fi

# ------------------------------------------------------------------ G66
# **And a sentence a claim leans on may not be reworded quietly** — item 2-ب,
# the other half of G65. Turning 347 finders into keys removed the noise of a
# guard reddening because a word changed; it also removed the only thing that
# noticed a word changing. G50/G51 measure the list's **shape** and nothing
# measured its **meaning**.
#
# So the few sentences a claim in `docs/CLAIMS.md` actually depends on are
# pinned by their exact English, with the claim named beside each. The pairs are
# read out of the claims file itself, so a claim that starts naming a new key
# brings it in or reddens — a pin nobody can forget to add. A reword anywhere
# else stays quiet, which is the point.
#
# Measured when it was written: all five of its reds bite — a reworded claim
# sentence, a pin no claim names, a claim naming an unpinned key, a pinned key
# gone from the list — and a reword of a sentence no claim leans on does not.
if [ -f scripts/check_claimed_sentences.py ]; then
  if OUT=$(python3 scripts/check_claimed_sentences.py 2>&1); then
    pass "G66 every sentence a claim leans on still says what the claim says — $OUT"
  else
    fail "G66 a sentence a claim in docs/CLAIMS.md leans on was reworded:"
    printf '%s\n' "$OUT" | sed 's/^/        /'
  fi
else
  skip "G66 every sentence a claim leans on still says what the claim says" "no checker yet"
fi

# ------------------------------------------------------------------ G55
# **No sentence carries a character nobody can see** — 19 October 2026.
#
# The lead, reading the ninety German values of 092's third sitting, found
# `deviceBoundProtection` drafted with a **soft hyphen** inside
# «Geräte­gebundener Schutz». Invisible in every editor, every diff and every
# review; written by the hand that drafted the value, caught by the hand that
# read it. One pair of eyes is not a method, so the class is refused where the
# sentences live: format, control, private-use and surrogate code points, in
# every value of every `lib/l10n/*.arb`.
#
# **The isolate marks are in that class and are not an exception.** `U+2068`
# and `U+2069` are needed — a word the person chose, quoted inside a sentence
# of ours, is isolated or the bidirectional algorithm takes the punctuation
# into it (G44, the owner's «ألماني 1») — and they live at the **call site**,
# which G44's own half over this file checks. The two gates together say the
# law exactly: the sentence carries the quotation marks, the caller carries the
# isolate. The other arrangement is already refused by the toolchain, because
# `gen-l10n` writes raw code points into the generated Dart and the analyzer
# flags each one in a file nobody can edit.
#
# A Python checker, because the question is about Unicode categories and a
# shell cannot ask it.
if [ -f scripts/check_no_invisible_sentence.py ]; then
  if OUT=$(python3 scripts/check_no_invisible_sentence.py 2>&1); then
    pass "G55 no sentence in the one list carries an invisible character — $OUT"
  else
    fail "G55 a sentence carries a character nobody can see:"
    printf '%s\n' "$OUT" | sed 's/^/        /'
  fi
else
  skip "G55 no sentence carries an invisible character" "no checker yet"
fi

# ------------------------------------------------------------------ G54
# **G53 on this branch until 093 landed**, which took that number for the
# Windows job — five checks of its own, and `G53_BAD` among its variables.
# Two gates under one number is a red that names two things, and two stanzas
# sharing a variable is a value one of them did not set.
# **One teardown for every test folder** — 19 October 2026, after a race that
# reddened three different guards in one file across three full runs.
#
# A test that gives the core a folder of its own used to delete it by hand:
# `if (here.existsSync()) here.deleteSync(recursive: true);`. That reads the
# folder, unlinks what it found, then removes the folder — and the core is a
# live Rust library in the same process. A file appearing between the reading
# and the removal (a session being sealed, `writing.lock`, the `zv.new` of an
# atomic replace) makes the last step fail with `ENOTEMPTY`, **the teardown
# throws**, and the test is reported as an error with its own claim already
# proved. Green alone, red in company, and a different guard each time.
#
# 133 lines in 57 files did it. They go through `removeWhenItLetsGo` now, and
# this gate is what stops the race coming back one file at a time: a new
# `deleteSync(recursive: true)` under `test/` is refused **by name**, because a
# sweep nobody guards is a sweep that has to be done again.
#
# The one place allowed is the helper itself, where the retry lives.
G54_ALLOWED='the_folder_lets_go.dart'
G54_BAD=$(grep -RnE 'deleteSync\(recursive: true\)' apps/flutter_app/test 2>/dev/null \
          | grep -vE ':[0-9]+:[[:space:]]*(//|///)' \
          | grep -v "$G54_ALLOWED" || true)
if [ -z "$G54_BAD" ]; then
  G54_USES=$(grep -RcE 'removeWhenItLetsGo\(' apps/flutter_app/test 2>/dev/null \
             | awk -F: '{s+=$2} END {print s+0}')
  pass "G54 every test folder goes through removeWhenItLetsGo ($G54_USES sites), and nothing deletes one by hand"
else
  fail "G54 a test folder is deleted by hand — the core can be writing into it, and the teardown reds a guard it is not about:"
  printf '%s\n' "$G54_BAD" | sed 's/^/        /'
fi

# ------------------------------------------------------------------ G52
# **The core is told where its files are, before there is a screen** — 18
# October 2026, and the gate exists because a build shipped without it.
#
# `set_data_dir` is the one call that gives the core its folder: the vault, the
# sessions and `settings.zcfg` all hang off it. It lived in the shell's
# `_start()`, behind `if (widget.ground == null)` — a **test** door, because a
# future created in `testWidgets`' zone never completes. 092 made the root hold
# the `Ground` so it could read the person's language, the shipped app began
# passing one, the condition read «a test gave me this», and the call stopped
# happening in the product. The core then has no folder; `VaultState` answers
# `Absent` for «no folder» exactly as for «no vault», and the owner was shown
# the first-run page over a 7938-byte vault that nothing had read. Four hundred
# and one Dart tests were green, because every one of them passes a folder.
#
# So the law is about **where the call stands**, not that it exists somewhere:
#
#   1. `lib/main.dart` calls it, and **before `runApp`** — there is no screen
#      yet, so no screen's parameters can decide it.
#   2. **Nothing branches in front of it.** An `if` between the top of `main()`
#      and that call is the exact shape of the fault; a `try` is not, because
#      catching the failure is how the sentence reaches the glass.
#   3. **Two callers in `lib/`, by name**: `main.dart` for the product and the
#      shell's own `_start()` for a test that brings its own folder. A third is
#      a second opinion about where a person's vault lives.
MAIN_DART=$FLUTTER_LIB/main.dart
G52_BAD=""
if [ ! -f "$MAIN_DART" ]; then
  G52_BAD="there is no $MAIN_DART"
else
  MAIN_AT=$(grep -nE '^Future<void> main\(' "$MAIN_DART" | head -1 | cut -d: -f1)
  RUNAPP_AT=$(grep -n 'runApp(' "$MAIN_DART" | head -1 | cut -d: -f1)
  SETDIR_AT=$(grep -n 'setDataDir(' "$MAIN_DART" | head -1 | cut -d: -f1)
  if [ -z "$SETDIR_AT" ]; then
    G52_BAD="$MAIN_DART never tells the core where its files are — the vault, the sessions and settings.zcfg all hang off set_data_dir"
  elif [ -z "$MAIN_AT" ] || [ -z "$RUNAPP_AT" ]; then
    G52_BAD="$MAIN_DART has no «Future<void> main(» or no «runApp(» for this gate to read"
  elif [ "$SETDIR_AT" -gt "$RUNAPP_AT" ]; then
    G52_BAD="$MAIN_DART calls set_data_dir at line $SETDIR_AT, after runApp at line $RUNAPP_AT — the first screen is drawn over a core with no folder"
  elif [ "$SETDIR_AT" -lt "$MAIN_AT" ]; then
    G52_BAD="$MAIN_DART calls set_data_dir at line $SETDIR_AT, outside main() at line $MAIN_AT"
  else
    BRANCH=$(sed -n "$((MAIN_AT + 1)),$((SETDIR_AT - 1))p" "$MAIN_DART" | grep -nE '^[[:space:]]*(if|} else)[[:space:]]*[({]' || true)
    if [ -n "$BRANCH" ]; then
      G52_BAD="$MAIN_DART branches before it says where the files are, which is the 18 October fault itself:
        $BRANCH"
    fi
  fi
fi
# The generated bridge declares the door; it decides nothing, and it is not
# written by hand — the same exclusion G32 and G38 make of `lib/l10n/`.
SETDIR_FILES=$(grep -rln 'setDataDir(' "$FLUTTER_LIB" 2>/dev/null | grep -v "^$FLUTTER_LIB/src/" | sort || true)
SETDIR_EXTRA=$(printf '%s\n' "$SETDIR_FILES" | grep -v -e "^$FLUTTER_LIB/main.dart$" -e "^$FLUTTER_LIB/screens/shell.dart$" || true)
if [ -n "$SETDIR_EXTRA" ]; then
  G52_BAD="$G52_BAD
        a third place says where a person's files live: $SETDIR_EXTRA"
fi
if [ -n "$G52_BAD" ]; then
  fail "G52 the core is not told where its files are before the first screen:"
  printf '        %s\n' "$G52_BAD"
else
  pass "G52 main.dart tells the core its folder at line $SETDIR_AT, before runApp at line $RUNAPP_AT, with nothing branching in front of it"
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
if [ "$WATCH_N" = "1" ] && grep -q 'screens/shell.dart' <<< "$WATCHERS"; then
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

if grep -q 'test_clock' <<< "$TEST_FEATURES"; then
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

  # G2b: **and every door that reaches a model names its text by a handle** —
  # rule 62, and the hole that let the deleted door through.
  #
  # G2 above reads `send*` and asks whether a text type appears. The door the
  # owner deleted was called `ask_model_directly`, so the name never matched —
  # and widening the name is not enough either, because `ask_model`'s own
  # signature carries `Option<String>` for a model id and `Vec<String>` for a
  # workspace's instructions, which are not a document. So the shape is asked
  # for instead of an absence: both verbs this contract reaches a model with
  # must take a `PayloadHandle`. A door with a `String` where the handle should
  # be has nothing to put in it.
  BAD=$(printf '%s\n' "$SIGS" | grep -E 'pub fn (send|ask)[a-z_]*[[:space:]]*\(' | grep -v 'PayloadHandle' || true)
  if [ -n "$BAD" ]; then
    fail "G2b $API: a door reaches a model without a handle:"; printf '        %s\n' "$BAD"
  else
    pass "G2b $API: every door that reaches a model names its text by a handle"
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
for t in Secret SafePayload DocumentView PayloadView RevealedValue Segment EntityRow EntityCard WorkspaceSnapshot VaultSnapshot TaughtValueRow AnswerSnapshot TurnRow; do
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
# No intermediate files: reading a document must never touch the disk, and each
# line that touches it at all carries a «G15-ok» comment above it so that the
# exemptions are countable.
#
# **What this crate may write, in full** — the independent attacker's note 12,
# 17 October 2026, and he was right: this gate's own sentence said «the vault»
# and «the settings» while the core had been writing two more kinds of file for
# days. A gate that names less than the program does is a gate a reader trusts
# for the wrong reason. The four, each by name:
#
#   * `vault.zv` — the sealed vault, the one file this program was written
#     around (G15's original subject).
#   * `settings.zcfg` — the settings, which are touched in `config.rs` and
#     nowhere else; that is G15b below, and the count is kept apart from the
#     vault's for exactly that reason.
#   * `sessions/N.zs` — one sealed file per session, since rule 54ج and 55ب:
#     the document in the preview is kept with its decisions, under the
#     session's own key.
#   * `writing.lock` — the lock one copy of the program holds while it writes,
#     since the attacker's م5: zero bytes, no secret in it, and the only reason
#     two copies cannot lose a write between them.
#
# A fifth kind is a change somebody makes on purpose, and the line that writes
# it needs its own «G15-ok» before this gate will pass it.
FS_HITS=$(grep -RnE '\b(std::fs::|File::create|File::open|temp_dir|tempfile|NamedTempFile|OpenOptions)' z_core/src 2>/dev/null \
  | grep -vE ':[0-9]+:[[:space:]]*//' || true)
FS_BAD=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  FILE=${line%%:*}
  REST=${line#*:}
  NUM=${REST%%:*}
  PREV=$((NUM - 1))
  if ( set +o pipefail; sed -n "${PREV}p" "$FILE" 2>/dev/null | grep -qE 'G15-ok|G15-cfg' ); then
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
  pass "G15 no filesystem in z_core/src except $VAULT_LINES lines for vault.zv, sessions/*.zs and writing.lock, and $CFG_LINES for settings.zcfg"
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
if ! ( set +o pipefail; rustup target list --installed 2>/dev/null | grep -qx "$WIN_TARGET" ); then
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

# ------------------------------------------------- the library this half speaks
# **The suite's library is built here, because the suite's library is part of
# the measurement** — 18 October 2026, and it is the second half of G7-lib's
# own lesson.
#
# `flutter build linux --debug` is the documented way to produce
# `bundle/lib/libz_bridge.so`, and it runs cargokit, which builds `z_bridge`
# with **no `--features` at all**: there is no `cargokit.yaml` beside the
# manifest, and cargokit's only feature knob is that file's `extra_flags`. So
# the library that recipe writes carries **no echo provider** — `fake_provider`
# is never a default feature, G1d forbids it — and every guard that asks a
# model goes red through it with `providerUnavailable(provider: fake)`.
#
# Measured: on the assembled tree of 18 October, all seven tests of
# `the_chat_is_the_third_part_test.dart` failed that way over sources that were
# correct, and the Dart count read 381 instead of 388. The remedy had been a
# hand-built library copied in by whoever knew — which is a measurement nobody
# can repeat from this script, and the one thing a judge must never be.
#
# So the features are this script's business: it builds the bridge with them
# and puts the result where the Dart half looks. The release package is
# untouched by this and cannot be reached from here — `package_linux.sh` runs
# its own `flutter build linux --release`, which writes a different directory
# (`build/linux/x64/release/bundle`) from the debug one named above.
#
# What it does change is the **debug** bundle beside it: after a gate run, the
# application in `build/linux/x64/debug/bundle` answers through a library with
# an echo provider in it. That is what a debug bundle is for, and it is said
# here rather than left to be discovered — a release carries no such provider,
# and G1d keeps `fake_provider` out of the default features so that no
# `--release` build can acquire one.
#
# Named with `z_core/` in front of each feature because they are **z_core's**:
# `z_bridge` declares none of its own, and `cargo build -p z_bridge --features
# fake_provider` would be refused by name rather than guessed at.
BRIDGE_FEATURES=$(printf '%s' "$TEST_FEATURES" | sed 's/^--features //' |
                  tr ',' '\n' | sed 's|^|z_core/|' | paste -sd, -)
if [ -d "$LIB" ] && command -v cargo >/dev/null 2>&1; then
  if cargo build -p z_bridge --features "$BRIDGE_FEATURES" --quiet >/tmp/g7b.$$ 2>&1 \
     && [ -f target/debug/libz_bridge.so ]; then
    cp target/debug/libz_bridge.so "$LIB/libz_bridge.so"
    pass "G7-build the library the Dart half speaks through is built here, with the test features ($BRIDGE_FEATURES)"
  else
    fail "G7-build the bridge would not build with the test features ($BRIDGE_FEATURES) — the Dart half would answer through whatever is in $LIB:"
    sed 's/^/        /' /tmp/g7b.$$ | tail -12
  fi
  rm -f /tmp/g7b.$$
elif [ ! -d "$LIB" ]; then
  skip "G7-build the library the Dart half speaks through" "no $LIB yet — run: cd apps/flutter_app && flutter build linux --debug"
else
  skip "G7-build the library the Dart half speaks through" "no cargo on this machine"
fi

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
elif ! LC_ALL=C grep -qa 'Echo (tests only)' "$LIB/libz_bridge.so"; then
  # **The date is not the whole of «the right library»** — the other half,
  # measured on 18 October. A library built by `flutter build linux --debug`
  # is as new as the tree and still cannot answer: it carries no echo
  # provider, so twenty guards go red with `providerUnavailable(provider:
  # fake)` and not one of them names the cause. The echo provider's own label
  # is the artefact's observable — `providers/fake.rs` is compiled only under
  # `fake_provider`, so the string is in the .so exactly when the feature is —
  # and refusing here means the suite is never run through a library that
  # cannot answer. The behaviour itself is measured where behaviour belongs,
  # by the guards that ask the fake provider a question.
  fail "G7-lib the library in $LIB carries no echo provider, so it was not built with the test features — the Dart half would red on every guard that asks a model, naming none of this. It is built by G7-build above; a library put there by hand or by «flutter build linux --debug» alone is not the one this suite measures through"
  skip "G7-dart contract callable from Dart" "the library cannot answer a guard that asks a model, so its answer would not be about this tree"
  DART_PASSED=""
else
  pass "G7-lib the library the Dart half speaks through was built from this tree, and carries the test features it must answer through"
  # **A red that says what failed.** The compact reporter rewrites one line, so
  # a log of it keeps only that line's last state: on 13 Oct seven failures came
  # back as one test's name and a RenderFlex dump from a file that had not
  # failed at all, and finding the seven took a second full run of the suite by
  # hand. `--file-reporter` writes every event beside it, and the log is kept
  # rather than deleted, because the evidence of a red is worth more than a
  # tidy /tmp.
  # **And the record stays on green too** — sitting five, item 4. Until today
  # the two files above were deleted the moment the suite passed, and the
  # argument written here for keeping a red's evidence is the same argument on
  # green: the number read out of this log is the number `MEASURED_ON_LINUX.txt`
  # is compared against, and a count nobody can re-examine is a claim, not a
  # measurement. 21 Oct a green round of mine reported «dart 408» with nothing
  # left on disk to check it by, in the same session in which the *kept* log of
  # a red had been the one thing that named a cause («errno = 39», an error and
  # not a failure).
  #
  # **A fixed place, and named in the PASS line.** `/tmp/gd-$$.json` moved with
  # every run: four rounds left four records and none of them said which tree or
  # which round it came from, so even a kept red was hunted for by date. One
  # place per worktree — `basename "$PWD"`, because two checkouts measuring at
  # once must not overwrite one another's evidence — and the gate prints the
  # path, so the next reader is told where it is instead of inferring it.
  DART_RECORD="${TMPDIR:-/tmp}/zprivacy-gates/$(basename "$PWD")"
  mkdir -p "$DART_RECORD" 2>/dev/null
  DART_LOG="$DART_RECORD/dart.log"
  DART_JSON="$DART_RECORD/dart-events.json"
  # Last round's record is replaced, not appended to: what is wanted is the
  # record **of this run**, and a file holding two runs answers neither.
  rm -f "$DART_LOG" "$DART_JSON"
  if (cd apps/flutter_app && LD_LIBRARY_PATH="$PWD/build/linux/x64/debug/bundle/lib" flutter test --concurrency=1 --reporter compact --file-reporter="json:$DART_JSON" >"$DART_LOG" 2>&1); then
    DART_GREEN=1
  else
    DART_GREEN=
  fi
  # The compact reporter's own running total, last word it says — read out of
  # the log itself, which is why the log is read before anything else is said.
  DART_PASSED=$(grep -oE '\+[0-9]+' "$DART_LOG" 2>/dev/null | tail -1 | tr -d '+')
  if [ -n "$DART_GREEN" ]; then
    pass "G7-dart the whole contract answers from Dart without a panic — ${DART_PASSED:-?} tests, and this run's own record is kept: $DART_JSON"
  else
    fail "G7-dart flutter test:"
    if [ -f scripts/dart_failures.py ] && [ -f "$DART_JSON" ]; then
      python3 scripts/dart_failures.py "$DART_JSON" | sed 's/^/        /'
    fi
    tail -20 "$DART_LOG" | sed 's/^/        /'
    printf '        the whole log: %s · every event: %s\n' "$DART_LOG" "$DART_JSON"
  fi
fi

# ---------------------------------------------------------------- G7-record
# **The guard on the line above**, because an item that says «the record is
# kept» and has nothing asking the question is a comment, not a measurement —
# and this one would go quiet in exactly the way its own subject describes: a
# `rm` added back anywhere below would leave every other gate green.
#
# It asks for both files, non-empty, after the suite has run, and prints the
# event file's size so that «kept» is a number and not an adjective. It is a
# skip and not a pass where the Dart suite never ran, because then there is
# honestly nothing to keep.
if [ -n "${DART_JSON:-}" ]; then
  if [ -s "$DART_JSON" ] && [ -s "$DART_LOG" ]; then
    pass "G7-record the Dart run's own record outlives the run, green or red — $(wc -c <"$DART_JSON" | tr -d ' ') bytes of events at $DART_JSON"
  else
    fail "G7-record the Dart suite ran but its record is gone or empty — $DART_JSON. The count this round reports is then unre-examinable, and it is the count MEASURED_ON_LINUX.txt is compared against"
  fi
else
  skip "G7-record the Dart run's own record" "the Dart suite did not run here, so there is nothing to keep"
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
     && ! ( set +o pipefail
            grep -nE '"/home/|g_get_home_dir' "$RUNNER" 2>/dev/null | grep -q . ); then
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
# **There is no direct door in this tree** — rule 62, the owner on 17 October,
# after the attacker's م1.
#
# This was «no fallback»: nothing may construct a direct body from a protected
# one, counted literally, because there were two bodies and the whole promise
# was that nothing turned one into the other. The owner then deleted the choice
# itself — «لا يرسل Z إلى الذكاء الاصطناعي إلا النص المحمي، من أي باب خرج» — so
# the promise is no longer about a path between two doors. It is about there
# being one.
#
# So the check reads the whole seam for the names that door had, in the core,
# in the bridge **and** in the generated Dart: a door deleted on the glass and
# left standing in the contract is the door that is re-opened tomorrow with
# nobody deciding anything. Comments may name it — this file's own prose does,
# and so does the code's — so a line that is a comment is not a door, which is
# the same reading the two checks below this one use.
#
# **The gateway knows no language.** A pack id or a language word inside
# `gateway.rs` would mean the door had started reading documents.
#
# **A provider is a file.** Adding one may not need the gateway: the check
# counts the providers and the gateway's mentions of them, which must stay at
# zero.
GW=z_core/src/gateway.rs
if [ -f "$GW" ]; then
  G62_FILES="z_core/src/api.rs z_core/src/gateway.rs"
  for f in z_core/src/ops/*.rs z_core/src/providers/*.rs bridges/native/z_bridge/src/*.rs; do
    G62_FILES="$G62_FILES $f"
  done
  G62_FILES="$G62_FILES $FLUTTER_LIB/src/rust/frb_generated.dart"
  G62_FILES="$G62_FILES $FLUTTER_LIB/src/rust/third_party/z_core/api.dart"
  # One name per thing the door was: the contract's function, the provider
  # call under it, the body type it travelled in, and the Dart the generator
  # writes from the contract.
  # `-H` so the filename is printed even if this list is ever one file: the
  # comment filter below reads «file:line:», and without it a single file would
  # print «line:» and every comment would be read as a door.
  G62_LEFT=$(grep -nHE 'ask_model_directly|ask_direct|Body::Direct|askModelDirectly' $G62_FILES 2>/dev/null \
    | grep -vE '^[^:]*:[0-9]+:[[:space:]]*(//|///|//!|#)' \
    | sed -E 's/^([^:]*):([0-9]+):.*/\1:\2/' | tr '\n' ' ' | sed 's/ $//')
  if [ -z "$G62_LEFT" ]; then
    pass "rule 62: no direct door in this tree — only the protected version is sent, whichever door it leaves by"
  else
    fail "rule 62: a door that sends the text as it stands is still here: $G62_LEFT"
  fi
  # And the one door that is left names its text by a handle. A `String` body
  # on this request is the same door under another name, so the shape is read
  # rather than the name: the request carries a `PayloadHandle` and the module
  # holds no `Zeroizing<String>` for a body to be put in.
  if grep -qE '^\s*pub payload: PayloadHandle,' "$GW" \
     && ! grep -qE 'Zeroizing<String>' "$GW"; then
    pass "  the gateway's one request names its text by a handle, and holds no text of its own"
  else
    fail "  the gateway's request no longer carries a handle, or carries text beside it: $GW"
  fi
  if ( set +o pipefail
       grep -nE '"(de|sv|en)"|German|Swedish|Deutsch' "$GW" \
         | grep -vE '^[0-9]+:\s*(//|///)|//!' | grep -q . ); then
    fail "the gateway names a language: $GW"
  else
    pass "  the gateway knows no language"
  fi
  if ( set +o pipefail
       grep -nE '\b(openai|anthropic)\b' "$GW" \
         | grep -vE '^[0-9]+:\s*(//|///)|//!' | grep -q . ); then
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
  # **And the release says which packs it has, by asking them** — the
  # attacker's ن13. `packaging/linux/README.txt` told whoever downloaded the
  # archive «the detection packs are German and English», which stopped being
  # true the day Swedish was offered (rule 56, 16 October) and nobody moved
  # that line. A sentence that names must ask what it names, so the names are
  # read out of the registry and looked for in the sentence.
  #
  # The interface line beside it is **not** checked against anything: it was
  # rule 56-أ («the first screen shows no Swedish until the screens are
  # translated»), and since paper 106 wrote the Swedish words it is the
  # sentence about what a **native speaker has read** — the owner's own round.
  # Either way «the interface is …» is a separate fact from the packs, with its
  # own owner.
  RELEASE_README=packaging/linux/README.txt
  if [ -f "$RELEASE_README" ] && [ -f "$PACKS/mod.rs" ]; then
    MISSING=""
    for pack in de:German sv:Swedish en:English; do
      code=${pack%%:*}
      word=${pack##*:}
      if grep -qE "\b$code::pack\(\)" "$PACKS/mod.rs" \
         && ! grep -q "$word" "$RELEASE_README"; then
        MISSING="$MISSING $word"
      fi
    done
    if [ -z "$MISSING" ]; then
      pass "  the release README names every pack the registry offers"
    else
      fail "  the release README does not name these packs the registry offers:$MISSING ($RELEASE_README)"
    fi
  else
    skip "  the release README's packs" "no packaging README or no registry on this branch"
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
  if ( set +o pipefail
       sed -n '/fn discover_names/,/^}/p' "$DISC" | grep -qE 'Confidence::|candidate\(' ); then
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
   && ! ( set +o pipefail
          grep -A6 'fn dictionary_names' z_core/src/scanner/packs/de.rs 2>/dev/null \
            | grep -q 'Confidence::Auto' ); then
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
# had a third honest answer: no file is offered at all. Rule 81 of 22 October
# ends that, and 103 puts the two files on three pages of their own.
#
# **The question does not change; where it is asked does.** It was asked of
# `site/*/index.html`, and that glob does not reach `site/en/download/` — so
# from the moment the section existed this read «the site offers no file»
# about a site offering two, and said PASS. A control that cannot bite is a
# finding in this house, so it now reads the pages the files are on.
#
# What it holds is the old intent: a page that offers a file says which build
# the file is, because «which build is this?» is the first thing a person who
# downloaded it cannot answer from the file's name — and no first screen
# offers a file, because the download has a page now. The per-artefact half —
# the build line is a commit this repository holds, the same one in all three
# languages — is `check_site_claims.py`'s, inside G59.
#
# The old «unfilled, so unpublishable» branch is gone with the `{{…}}` build
# values it read: a page with one of those in it is refused outright by
# `check_site.sh`'s first check, and the thing that branch was for — a section
# half-filled with values from the wrong build — is now the provisional
# markers, which keep the publishing run red until the real ones land.
if ls site/*/download/index.html >/dev/null 2>&1; then
  DL_NO_BUILD=$(grep -L 'data-built-from=' site/*/download/index.html 2>/dev/null | tr '\n' ' ')
  DL_ON_FRONT=$(grep -lE 'zprivacy-v1-[a-z0-9_.-]+\.(tar\.gz|exe)' site/*/index.html 2>/dev/null | tr '\n' ' ')
  if [ -n "$DL_NO_BUILD" ]; then
    fail "  a download page offers a file without naming the build it came from: $DL_NO_BUILD"
  elif [ -n "$DL_ON_FRONT" ]; then
    fail "  a first screen offers a file, and the download has a page of its own: $DL_ON_FRONT"
  else
    pass "  every download page names the build its files came from, and no first screen offers a file"
  fi
elif grep -rqE 'zprivacy-v1-[a-z0-9_.-]+\.(tar\.gz|exe)' site/*/index.html 2>/dev/null; then
  fail "  a page offers a file and there is no download page to name its build"
else
  pass "  the site offers no file, so there is no build for it to name"
fi

# ------------------------------------------------- nothing names this machine
# **A release says nothing about the machine that built it** — the independent
# attacker's خ3 and ن6, 17 October. `lib/libz_bridge.so` in the installed
# release carried 195 strings of `/home/<user>/.cargo/registry/src/…`, the GTK
# plugin carried this tree's build directory in its debug information, and
# `libapp.so` carried `file:///home/<user>/…/dart_plugin_registrant.dart`.
# None of them is a secret, and together they are one developer's machine and
# user name inside a file strangers are asked to trust.
#
# Two questions, because the archive is built rarely and the script that builds
# it is read every day: does the script still take this machine out of what it
# packs, and — when an archive is actually here — is it in fact out.
PKG=scripts/package_linux.sh
if [ -f "$PKG" ]; then
  MISSING=""
  grep -q 'remap-path-prefix' "$PKG" || MISSING="$MISSING remap-path-prefix"
  grep -q 'strip --strip-unneeded' "$PKG" || MISSING="$MISSING strip"
  grep -q 'redrawn' "$PKG" || MISSING="$MISSING the-snapshot-rewrite"
  grep -q 'the archive would carry paths from this machine' "$PKG" || MISSING="$MISSING its-own-refusal"
  if [ -z "$MISSING" ]; then
    pass "the packaging script takes this machine out of the binaries"
  else
    fail "the packaging script no longer does:$MISSING ($PKG)"
  fi
else
  fail "there is no packaging script ($PKG)"
fi
ARCHIVE=$(ls -t dist/zprivacy-v1-linux-*.tar.gz 2>/dev/null | head -1)
if [ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ]; then
  # Every byte of every file in it, read back out of the archive itself: the
  # binaries, the notices, BUILD-INFO, the crate list.
  if ( set +o pipefail; tar xzOf "$ARCHIVE" 2>/dev/null | grep -qa '/home/' ); then
    fail "  the archive carries a path from this machine ($ARCHIVE)"
  else
    pass "  no «/home/» anywhere in $(basename "$ARCHIVE")"
  fi
else
  skip "  no «/home/» anywhere in the archive" "no archive in dist/ on this machine"
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
#
# **Two names left this roster on 17 October, and they are the exception the
# roster is for.** `the_direct_door_takes_it_out` and
# `the_direct_door_writes_what_it_sent_as_it_sent_it` measured the door that
# sent a document as it stands; rule 62 deleted that door, so their invariant
# was not lost with them — it has no subject. The roster said so loudly first:
# both reds were read here before the names were taken out, which is the only
# way a name may leave a list that is not a wish list.
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
         the_door_back_reads_a_file_another_session_protected \
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
         a_hand_protection_after_forget_does_not_restore_the_automatic_one \
         an_empty_vault_file_is_not_a_vault_and_a_damaged_one_is_never_written_over \
         two_copies_never_lose_a_write \
         two_copies_never_lose_a_turn \
         a_reason_that_quotes_a_persons_word_isolates_it \
         a_document_that_arrives_with_the_vault_shut_has_no_session \
         a_refused_press_leaves_the_blocks_working \
         a_second_question_carries_the_turn_before_it_without_the_document \
         a_third_question_carries_only_the_exchange_before_it \
         the_copy_is_the_current_point_and_still_brings_home_a_name_from_the_first_turn \
         a_follow_up_question_leaves_without_the_document \
         a_follow_up_with_no_question_in_it_is_refused \
         a_chat_that_ended_is_not_carried_into_the_next_one \
         a_new_run_does_not_continue_the_chat_it_finds \
         entering_the_same_session_again_in_one_run_keeps_its_chat \
         the_chat_a_person_takes_away_is_what_would_leave_now \
         copying_the_chat_leaves_a_document_that_never_left_in_the_preview \
         the_chat_does_not_leave_while_a_word_waits \
         a_session_with_no_chat_in_it_has_nothing_to_take_out \
         a_format_five_file_reads_and_its_turns_belong_to_no_chat \
         an_answer_brought_back_by_hand_joins_the_open_chat \
         a_turn_carries_both_sides_coded_and_restored \
         a_turn_names_the_document_it_carried_after_the_copy_is_gone \
         an_answer_against_the_chats_own_copy_asks_nothing_new_and_restores_every_name \
         the_word_that_names_a_field_is_not_a_person \
         a_name_after_a_salutation_ends_with_the_sentence \
         the_exit_audit_does_not_count_a_value_inside_our_own_token \
         the_attackers_question_leaves_and_every_door_stays_open \
         a_label_a_walk_may_honestly_reach_is_still_not_a_name \
         a_zero_width_space_inside_a_name_does_not_hide_it \
         a_name_spelled_in_nfd_is_the_name \
         a_ligature_is_still_missed_and_that_is_written_down \
         the_post_office_box_is_a_finding \
         the_banks_own_name_is_offered_as_the_letterhead_company_is \
         nothing_the_model_found_is_still_in_the_clear \
         a_national_insurance_number_admits_its_letters \
         a_payment_card_is_found_by_its_own_arithmetic \
         sixteen_digits_that_fail_luhn_are_not_a_card \
         the_given_name_beside_a_protected_surname_is_taken_too \
         a_uk_address_line_is_an_address \
         a_hand_selection_in_the_request_takes_the_word \
         the_same_word_in_the_document_and_the_request_takes_one_token \
         a_hand_protection_in_the_request_can_be_undone \
         a_span_that_crosses_the_request_line_is_refused \
         a_column_act_in_the_request_is_refused_by_name \
         with_no_document_the_request_is_the_whole_original \
         the_snapshot_hands_the_one_text_with_the_requests_own_start \
         a_pasted_letter_with_no_document_leaves_by_the_manual_door \
         the_pdf_door_mints_its_answer_page_for_a_question_alone \
         the_model_door_still_takes_the_question_alone \
         an_empty_box_with_no_document_still_refuses_by_name \
         the_blocks_a_question_made_are_counted_on_its_own_surface \
         a_document_on_the_bench_still_answers_for_its_own_blocks \
         a_question_taken_out_with_no_document_is_born_into_a_session \
         a_question_sent_to_a_model_with_no_document_is_born_into_a_session \
         the_chat_of_a_question_only_session_carries_its_earlier_turns \
         the_room_shows_it_with_an_empty_kept_list_and_both_doors \
         a_question_that_never_leaves_is_born_into_nothing \
         ending_the_chat_starts_from_zero_without_a_second_birth \
         the_screens_own_birth_still_makes_one_session_and_not_two; do
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
#
# **Two names left this list on 17 October, and a name leaving it is as much a
# decision as a name joining it** (rule 70):
#
#   * «the chat door shows what will leave» — rule 60-أ's band, on the first
#     screen's chat. The screen is gone, the band with it, and the rule's other
#     half («the AI door opens the preview side») is two lines above.
#   * «not on Home» became «not on the three parts»: the same guard, asking
#     which screen a fresh device opens on, now that there is one screen.
#
# **And one left it when the chat replaced the answer panel:** «as the model
# wrote it» was the label of a tab over the whole panel, and rule 66 turned
# that around — the thread draws what travelled, coded, and the names come back
# in a bubble per answer. The phrase survived in a *comment* after the rename,
# which is a roster entry green for the wrong reason, so it was replaced by the
# property's new name rather than left to pass on a sentence nobody measures.
#
# The names that joined it are where this round's own shape is read: the way in
# at the top of the one screen with nothing open and with a document open, the
# absence of a way back, the two doors standing in two places, rule 69's line
# under a kept document — what it says, the handle that anchors it, and a
# follow-up answering for the chat its document began — and the chat itself:
# coded with the names one press away, a second question to the same door, an
# added answer with no question above it, the writing below the thread, the two
# tight windows, and an end that keeps what was said.
for t in "the core reports it" "the scan the core ran" "own two strings" "never the credential" \
         "not one Dart worked out" "Skip decides nothing" "does not touch what leaves" \
         "the manual door needs no key" "only the safe text arrives" \
         "the vault room" "say where they live" "in the language it is offering" \
         "not on the three parts" "word for word" "forgetting shows its cost first" \
         "clipboard untouched until confirmed" \
         "named a rescan, not scanned on import" \
         "offers Disconnect, not" "names both acts by their reach" \
         "says how much, and what to do" \
         "name the reach they would forget" "is the pack that is kept" \
         "display only, and Why lives" "its own next move" \
         "two edges in both columns" "moves the other, and Apart stops it" \
         "takes the reveal with it" "takes the revealed tokens with it" \
         "hides rather than keeps" "no longer in front" "gone from the screen" \
         "has no tokens to reveal, so the press is dead" \
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
         "no model is named in Dart" \
         "there is nothing else to choose" \
         "what it sends is the payload" \
         "offers no way to send the original" \
         "no door in this app carries a document to a model" \
         "takes that line, and the core says what is in it" \
         "protects that cell in every held line" \
         "between two columns says why" \
         "a wrapped row still presses the cell" \
         "carries the column act, so no press is wasted" \
         "another conversation says so, by name, above the answer" \
         "own answer restores with nothing said" \
         "puts nothing out while a word waits" \
         "every exit on the sheet is pressable while a word waits" \
         "the first waiting word in reading order" \
         "closes the sheet and says it where the word is" \
         "the AI door opens the preview side" \
         "a press on the AI door opens the Safe column" \
         "the side’s own door needs no opening" \
         "a session from before 080 is asked once" \
         "the way in at the top, and the three parts named" \
         "the way in is still at the top of the same screen" \
         "no way back is drawn, because there is nowhere to go back to" \
         "the way in and the way back are two presses, in two places" \
         "says a kept document was sent to AI and answered" \
         "the handle is the anchor, so two documents of one name are told apart" \
         "a follow-up question answers for the document its chat began with" \
         "opens the chat, coded, with the name only in the bubble" \
         "coded in the thread, and the names come back in its bubble" \
         "makes a second turn, to the same door" \
         "drawn with no question above it" \
         "the writing is below the thread, and against the bottom of the panel" \
         "the thread scrolls under a writing box that stays where it is" \
         "the chat is on the glass, acts and all" \
         "ending the chat asks nothing, ends it in the core, and keeps what was said" \
         "ending the chat empties all three parts, and keeps what was kept" \
         "with no document the box is there, and what is typed is what leaves" \
         "one box: a pasted letter is protected, and the second box is gone" \
         "removing the document empties the first part and keeps the copy" \
         "the settings open on Sessions, and a key door still opens on AI" \
         "a press outside closes the panel, lands on nothing, and the next press works" \
         "a kept document that comes back says «as it was kept», not three zeros" \
         "the chat shows the question above its answer, as it left" \
         "a host that answered nothing says so" \
         "the number this form promises is the number the core applies" \
         "no longer says that each question is asked alone"; do
  if grep -Rqs -- "$t" apps/flutter_app/test 2>/dev/null; then
    pass "  screen test present: $t"
  else
    skip "  screen test present: $t" "not written yet"
  fi
done

# ---------------------------------------------------------------- G59
# **The site is measured with the product** — the lead's ruling of 20 October
# 2026, and the argument for it is six days long.
#
# `scripts/check_site.sh` is thorough and it was green the last time a person
# ran it. Two rounds then walked past it:
#
#   * **092** moved three sentences out of the app — «Not sensitive» on 14
#     October, «Review what will leave» on 17, «As the model wrote it» on 18 —
#     and the site went on teaching all three to visitors as the app's own
#     words, in three languages, plus one as a step of the path diagram.
#   * **094** moved `rustls` to 0.23.46 in `Cargo.lock` and corrected the two
#     READMEs, while the notices page went on naming 0.23.45.
#
# Six published claims about this product, false, each caught in a second by a
# script nobody ran. A guard that is not in the one command is a guard that is
# not in the round.
#
# `--tree-only`, so the outward links are not asked of the network here: an
# offline machine is not a fault in the tree, and the links are asked when a
# person runs the script to publish, which is the moment the answer matters.
if [ -f scripts/check_site.sh ]; then
  if SITE_OUT=$(bash scripts/check_site.sh --tree-only 2>&1); then
    SITE_PAGES=$(printf '%s' "$SITE_OUT" | grep -oE 'the same [0-9]+ pages' | grep -oE '[0-9]+' | head -1)
    pass "G59 the site says nothing about this product that the tree does not — ${SITE_PAGES:-?} pages"
  else
    fail "G59 the site says something this tree does not:"
    printf '%s\n' "$SITE_OUT" | grep -E '^  FAIL' | cut -c1-150 | sed 's/^/      /'
  fi
else
  skip "G59 the site is measured with the product" "no scripts/check_site.sh in this tree"
fi

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
