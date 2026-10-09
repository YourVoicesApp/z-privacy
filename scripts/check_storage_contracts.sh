#!/usr/bin/env bash
# The promises Z Privacy makes about the files its vault lives in — and a gate
# that checks each one is **measured on the platform you are standing on**, not
# merely written somewhere.
#
# Why this exists. The first Windows run came back green: the workspace
# compiles, and every test that ran, passed. The ones that did not run were not
# skipped and not ignored — they are `#[cfg(unix)]`, so on Windows they do not
# exist to be run. Every one of them is a guard on the vault's own file.
#
# A suite that shrinks on a platform and still reports «ok» is telling the truth
# about what it ran and a lie about what is safe. This gate closes that gap: it
# asks for the contracts by name, and a platform that cannot show one is red
# until it can.
#
# It is deliberately NOT a count of tests. Counts drift as tests are added;
# these are the storage protection layer, and they are named, one line each.
# (The Linux and Windows totals that used to be quoted here were a month stale
# within a month — the live ones are in `docs/MEASURED_ON_LINUX.txt`.)
#
# It was six until October, and six was wrong twice over. 058 added three more
# guards on the **folder** the vault sits in, and they are `#[cfg(unix)]` like
# the rest — so Windows was missing nine while this file said «all six are
# measured». And they live in `z_core/src/secure_file.rs`, not in the
# `vault_layer` test binary, so listing one target could never have found them
# on any platform. Both halves are asked for below.
#
# Run it from anywhere:  bash scripts/check_storage_contracts.sh
# Exit status is the verdict: 0 = this platform measures all six.

set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

# contract name : what it promises
CONTRACTS=(
  "local_files_are_private_on_fresh_install:the files we create are not readable by other users"
  "vault_temp_symlink_is_refused_and_victim_is_unchanged:a symlink in the vault's place is refused, and what it points at is left alone"
  "settings_temp_symlink_is_refused_and_victim_is_unchanged:the same, for the settings file"
  "final_vault_symlink_is_not_read_as_a_vault:a symlink is never followed and read as if it were the vault"
  "normal_secure_vault_and_config_writes_still_work:and with all of that, an ordinary write still succeeds"
  "failed_secure_writes_leave_old_files_intact:a write that fails does not damage the file that was already there"
  # 058, the folder the two files sit in. Narrow in silence, never widen in
  # silence — and never hand yourself back a permission the person removed.
  "a_folder_the_person_locked_is_left_exactly_as_it_was:a folder the person locked is left exactly as it was, and the write is refused in words"
  "a_folder_wider_than_it_should_be_is_narrowed_without_a_word:a folder wider than it should be is narrowed without a word"
  "a_folder_already_right_is_left_alone:a folder already right is not touched at all"
)

# **Debts are declared, not left as a standing red.** The lead's ruling, 9 Oct:
# a red whose cause everyone already knows is the mirror of a false green — a
# reader learns to step over it, and steps over the next real one with it. So a
# contract that *cannot* hold on a platform yet is named here, with the paper
# that owes it and the reason, and this prints it as a debt rather than a
# failure. It still bites both ways: a test appearing under an owed name is a
# failure (the debt was paid and the list was not struck in the commit that
# paid it), and a contract missing without being named here fails as before.
# Same shape as the OWED roster in `gates.sh`, from 064b.
#
# name : platform : paper : why it cannot hold there yet
OWED=(
  "a_folder_wider_than_it_should_be_is_narrowed_without_a_word:Windows:074/W4b:there is no mode to narrow until the folder's own access list is written"
  "a_folder_already_right_is_left_alone:Windows:074/W4b:«already right» has no meaning until that same list exists"
)

case "$(uname -s 2>/dev/null || echo unknown)" in
  Linux*)   PLATFORM="Linux" ;;
  Darwin*)  PLATFORM="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows" ;;
  *)        PLATFORM="$(uname -s 2>/dev/null || echo unknown)" ;;
esac

echo "Storage protection contracts — on $PLATFORM"
echo

FEATURES="--features fake_provider,test_clock"
LAYER=$(cargo test -p z_core --test vault_layer $FEATURES -- --list 2>/dev/null | sed 's/: test$//')
UNITS=$(cargo test -p z_core --lib $FEATURES -- --list 2>/dev/null | sed 's/: test$//')

# Two preconditions, two sentences. A gate that cannot tell «the binary did not
# build» from «the contract is missing» reds for a reason that is not the one.
if [ -z "$LAYER" ]; then
  echo "  FAIL  the vault_layer test binary did not build or list its tests."
  echo "        Nothing about the vault's own file is measured here."
  echo
  echo "STORAGE PROTECTION NOT MEASURED ON $PLATFORM"
  exit 1
fi
if [ -z "$UNITS" ]; then
  echo "  FAIL  z_core's unit tests did not build or list themselves."
  echo "        Nothing about the folder the vault sits in is measured here."
  echo
  echo "STORAGE PROTECTION NOT MEASURED ON $PLATFORM"
  exit 1
fi
LISTED=$(printf '%s\n%s\n' "$LAYER" "$UNITS")

MISSING=0
OWED_HERE=0
MEASURED=0
for entry in "${CONTRACTS[@]}"; do
  name=${entry%%:*}
  what=${entry#*:}

  # Declared as owed on this platform?
  owed_paper=""
  owed_why=""
  for debt in "${OWED[@]}"; do
    debt_name=${debt%%:*}
    rest=${debt#*:}
    debt_platform=${rest%%:*}
    rest=${rest#*:}
    debt_paper=${rest%%:*}
    debt_why=${rest#*:}
    if [ "$debt_name" = "$name" ] && [ "$debt_platform" = "$PLATFORM" ]; then
      owed_paper=$debt_paper
      owed_why=$debt_why
    fi
  done
  # An integration test lists as its bare name, a unit test as
  # `secure_file::tests::<name>` — one contract, one name, either spelling.
  if printf '%s\n' "$LISTED" | grep -qE "(^|::)${name}\$"; then
    if [ -n "$owed_paper" ]; then
      # The debt was paid. Good news, and still a failure: a list that keeps
      # naming a debt somebody settled is a list nobody reads.
      printf '  \033[31mFAIL\033[0m  %s\n' "$what"
      printf '        %s exists here now — strike it from OWED in the commit that wrote it (%s)\n' "$name" "$owed_paper"
      MISSING=$((MISSING + 1))
    else
      printf '  \033[32mPASS\033[0m  %s\n' "$what"
      MEASURED=$((MEASURED + 1))
    fi
  elif [ -n "$owed_paper" ]; then
    printf '  \033[33mOWED\033[0m  %s\n' "$what"
    printf '        owed by %s on %s: %s\n' "$owed_paper" "$PLATFORM" "$owed_why"
    OWED_HERE=$((OWED_HERE + 1))
  else
    printf '  \033[31mFAIL\033[0m  %s\n' "$what"
    printf '        no test named %s exists on this platform\n' "$name"
    MISSING=$((MISSING + 1))
  fi
done

echo
HOW_MANY=${#CONTRACTS[@]}
if [ "$MISSING" -eq 0 ]; then
  if [ "$OWED_HERE" -eq 0 ]; then
    echo "all $HOW_MANY storage contracts are measured on $PLATFORM"
  else
    echo "$MEASURED of $HOW_MANY storage contracts are measured on $PLATFORM, $OWED_HERE owed by name"
  fi
  exit 0
fi

cat <<EOF
STORAGE PROTECTION NOT MEASURED ON $PLATFORM — $MISSING of $HOW_MANY contracts failed here
($MEASURED measured; $OWED_HERE owed by name and not counted against this.)
A failure is one of two things: a contract with no test on this platform, or a
debt that was paid and left on the OWED list — the lines above say which.

This is not a test that failed. It is a promise nobody checked.

The vault still encrypts, still locks, still opens with the passphrase: the
logic of Z Privacy carries over. What does not carry over is the layer that
keeps the vault's own file from being swapped, followed, or left half-written
underneath it — and the folder it sits in from being quietly re-opened after
the person narrowed it. That layer is \`#[cfg(unix)]\`, and so are its tests.

The way out is not to delete these lines. It is to give this platform its own
guard and its own test under the same name, so that one contract has one name
and each platform proves it in its own terms. 058's folder refusal was done
that way on 9 October: Unix reads the folder's mode before writing, Windows
learns the same fact when the write comes back ERROR_ACCESS_DENIED, and both
return `StoragePermissionsKept` naming the file.

The ones above are different from the two in OWED, which is why they fail here
instead of being declared: Windows **does** keep those promises —
`secure_file/windows.rs` writes an owner-only access list with inheritance cut
and refuses a reparse point rather than following it — and what is missing is
the test that measures it there. An implemented promise nobody measures is the
thing this script exists to refuse. 074/W4c, once the workflow runs and can
answer.
EOF
exit 1
