// What a stranger holding the file can read out of it: nothing.
//
// The site publishes this sentence in the owner's own approved words — «Everything
// Z learns is kept in an encrypted vault on the user's own machine — even the
// vault file on disk contains no readable name» — and the privacy page names a
// file where each promise can be checked. For that one, there was no file.
//
// The vault is encrypted and `z_core/src/vault/crypto.rs` is a good reason to
// believe the sentence. A reason to believe is not a measurement. `zcfg_leak.rs`
// next door does this for the one file that is *not* encrypted; nothing did it
// for the vault itself, so a claim was on its way to a public page ahead of the
// test that holds it.
//
// Its shape is borrowed from that neighbour, including the half that matters
// most: **a search that finds nothing proves nothing until it is shown to find
// something.** The same five needles are written to a file beside the vault and
// the same finder is required to find every one of them there. If the control
// ever fails, this test says so instead of passing quietly.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

const PASS: &str = "ein langes Passwort das niemand sonst kennt";

/// What a stranger must not be able to read out of the folder: the client's
/// label, its value, a second spelling of it, a person, an account — and the
/// passphrase itself, which has no business being on the disk at all.
const NEEDLES: &[&str] = &[
    "Nordstern Consulting GmbH",
    "Nordstern",
    "Thomas Müller",
    "DE89370400440532013000",
    PASS,
];

fn holds(hay: &[u8], needle: &str) -> bool {
    let n = needle.as_bytes();
    hay.windows(n.len()).any(|w| w == n)
}

#[test]
fn the_vault_file_carries_no_readable_name() {
    let dir = std::env::temp_dir().join(format!("zprivacy-vault-says-nothing-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    let VaultUnlockOutcome::Unlocked { .. } = vault_create_with_passphrase(PASS.to_string()).expect("create");

    // A client taught by hand, with a second spelling, an account, and a person
    // beside it — the kinds of thing the vault exists to remember.
    let client = create_entity(EntityKind::Client, "Nordstern Consulting GmbH".to_string(), None).expect("entity");
    let value = set_value(
        client,
        None,
        Kind::Company,
        "Nordstern Consulting GmbH".to_string(),
        Policy::Always,
    )
    .expect("value");
    add_value_alias(client, value, "Nordstern".to_string()).expect("alias");
    set_value(client, None, Kind::Iban, "DE89370400440532013000".to_string(), Policy::Always).expect("iban");
    let person = create_entity(EntityKind::Person, "Thomas Müller".to_string(), None).expect("person");
    set_value(person, None, Kind::Person, "Thomas Müller".to_string(), Policy::Always).expect("person value");

    vault_lock().expect("lock");

    // The control first, written beside the vault with the same five needles in
    // it. Everything below depends on this finder working on a real file.
    let control = dir.join("control.bin");
    std::fs::write(&control, NEEDLES.join("\n").as_bytes()).expect("control");
    let plain = std::fs::read(&control).expect("read control");
    for needle in NEEDLES {
        assert!(
            holds(&plain, needle),
            "the finder cannot find «{needle}» in a file that plainly contains it, so this test proves nothing"
        );
    }

    // And now every file the core wrote into the folder.
    let mut looked = Vec::new();
    for entry in std::fs::read_dir(&dir).expect("read dir") {
        let path = entry.expect("entry").path();
        if path == control || !path.is_file() {
            continue;
        }
        let bytes = std::fs::read(&path).expect("read");
        for needle in NEEDLES {
            assert!(
                !holds(&bytes, needle),
                "{} carries «{needle}» in the clear, {} bytes in",
                path.display(),
                bytes.len()
            );
        }
        looked.push(format!("{} ({} bytes)", path.display(), bytes.len()));
    }
    assert!(
        !looked.is_empty(),
        "no file was written into {}, so nothing was searched",
        dir.display()
    );
    println!("searched: {}", looked.join(", "));
    let _ = std::fs::remove_dir_all(&dir);
}
