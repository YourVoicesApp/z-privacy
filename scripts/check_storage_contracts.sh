#!/usr/bin/env bash
# The six promises Z Privacy makes about the file its vault lives in — and a
# gate that checks each one is **measured on the platform you are standing on**,
# not merely written somewhere.
#
# Why this exists. The first Windows run came back green: the workspace
# compiles, and every test that ran, passed. 245 of them. On Linux the same 24
# binaries run 251. The six missing ones were not skipped and not ignored —
# they are `#[cfg(unix)]`, so on Windows they do not exist to be run. Every one
# of the six is a guard on the vault file itself.
#
# A suite that shrinks by six on a platform and still reports «ok» is telling
# the truth about what it ran and a lie about what is safe. This gate closes
# that gap: it asks for the contracts by name, and a platform that cannot show
# one is red until it can.
#
# It is deliberately NOT a count. Counts drift as tests are added; these six are
# the storage protection layer, and they are named, one line each.
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
)

case "$(uname -s 2>/dev/null || echo unknown)" in
  Linux*)   PLATFORM="Linux" ;;
  Darwin*)  PLATFORM="macOS" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="Windows" ;;
  *)        PLATFORM="$(uname -s 2>/dev/null || echo unknown)" ;;
esac

echo "Storage protection contracts — on $PLATFORM"
echo

LISTED=$(cargo test -p z_core --test vault_layer --features fake_provider -- --list 2>/dev/null \
         | sed 's/: test$//')
if [ -z "$LISTED" ]; then
  echo "  FAIL  the vault_layer test binary did not build or list its tests."
  echo "        Nothing about storage protection is measured here."
  echo
  echo "STORAGE PROTECTION NOT MEASURED ON $PLATFORM"
  exit 1
fi

MISSING=0
for entry in "${CONTRACTS[@]}"; do
  name=${entry%%:*}
  what=${entry#*:}
  if printf '%s\n' "$LISTED" | grep -qx "$name"; then
    printf '  \033[32mPASS\033[0m  %s\n' "$what"
  else
    printf '  \033[31mFAIL\033[0m  %s\n' "$what"
    printf '        no test named %s exists on this platform\n' "$name"
    MISSING=$((MISSING + 1))
  fi
done

echo
if [ "$MISSING" -eq 0 ]; then
  echo "all six storage contracts are measured on $PLATFORM"
  exit 0
fi

cat <<EOF
STORAGE PROTECTION NOT MEASURED ON $PLATFORM — $MISSING of 6 contracts have no test here

This is not a test that failed. It is a promise nobody checked.

The vault still encrypts, still locks, still opens with the passphrase: the
logic of Z Privacy carries over. What does not carry over is the layer that
keeps the vault's own file from being swapped, followed, or left half-written
underneath it — that layer is \`#[cfg(unix)]\`, and so are the tests for it.

The way out is not to delete these lines. It is to give this platform its own
guard and its own test under the same name, so that one contract has one name
and each platform proves it in its own terms.
EOF
exit 1
