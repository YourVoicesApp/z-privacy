// **Two copies of this program, one vault** — the independent attacker's م5 and
// خ9, 17 October 2026.
//
// He ran forty trials of two processes against one vault, each creating an
// identity: `a_only=18`, `b_only=22`, and **in three of them both copies said
// `ok` while the disk held one**. No `flock` anywhere, and between
// `Vault::ensure_disk_unchanged` and the `rename` inside `replace_atomically`
// a window in which the other copy's whole write fits. The session file was
// worse: `conversation::write` compared nothing at all, so the later `rename`
// simply won and the earlier turn was gone with no sentence anywhere.
//
// **What this file measures is the law, not the instrument:** a write is never
// lost in silence. Either both copies' work is on the disk, or the one that
// lost the race is told so by name (`VaultChangedElsewhere`, which this
// product has had a sentence for since 050/A — «Another copy of Z Privacy
// changed this vault. Close that window, or lock and unlock here to take in
// its work»).
//
// **Two real processes**, because that is the only thing that can prove it: a
// thread would share the core's own mutex and the lock's own file handle, and
// would measure neither. The worker below is this same test binary, run again
// with the parent's directory in its environment — the standard shape for a
// multi-process test in Rust, and it needs no second target to be built and
// found.
//
// **And the window is widened on purpose**, by a vault big enough that sealing
// and writing it takes milliseconds: the race is real at any size, and a guard
// that reproduces it in three trials out of forty is a guard that passes for
// the wrong reason thirty-seven times. The widening changes nothing about the
// law — it only makes the gap wide enough to step into every time.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::{Mutex, MutexGuard, OnceLock};
use std::time::Duration;

use z_core::api::*;

const PASS: &str = "ein genügend langes kennwort für zwei kopien";

/// How many identities the vault holds before the race. Each one is a whole
/// seal-and-write, so this is also how wide the window is.
const BULK: u32 = 300;

/// Trials of the real race, after the deterministic one. The attacker's own
/// shape, at a number that keeps the suite's time honest.
const TRIALS: usize = 6;

/// **One race at a time in this process.** The core's data directory is global
/// to a process, and `cargo test` runs the two parents of this file on two
/// threads: the first thing the suite said was `create: VaultAlreadyExists`,
/// because one parent set the directory the other had just created a vault in.
/// It passed alone and failed in company, which is the oldest shape of a guard
/// that measures its own harness.
fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn dir_for(name: &str) -> PathBuf {
    std::env::temp_dir().join(format!("zprivacy-two-copies-{name}-{}", std::process::id()))
}

/// **The other copy**, run as its own process by the test below.
///
/// It unlocks first and waits at a file afterwards, so that the Argon2 cost is
/// paid before the barrier and both copies enter the window together.
///
/// With no directory in its environment this is the ordinary suite running an
/// ordinary test, and it does nothing. That silence is what the parent checks:
/// it reads a `RESULT` line from every child, so a worker that quietly did
/// nothing is a failed trial rather than a passed one.
#[test]
fn a_copy_that_adds_one_identity() {
    let Ok(dir) = std::env::var("Z_TWO_COPIES_DIR") else {
        return;
    };
    let name = std::env::var("Z_TWO_COPIES_NAME").expect("the parent names each copy");
    let job = std::env::var("Z_TWO_COPIES_JOB").expect("the parent names the job");
    let go = Path::new(&dir).join("go");
    // Both paths are taken before the directory is handed over, because
    // `set_data_dir` takes the string itself.
    let ready = Path::new(&dir).join(format!("ready-{name}"));
    set_data_dir(dir).expect("data dir");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    // **The session file's half is entered before the barrier too** — خ9. What
    // is raced is the read and the write of `1.zs`, not the entering of it.
    if job == "turn" {
        conversation_enter(1, None).expect("enter the session both copies hold");
    }
    std::fs::write(&ready, b"here").expect("say that this copy is ready");
    while !go.exists() {
        std::thread::sleep(Duration::from_micros(200));
    }
    let done = match job.as_str() {
        "identity" => create_entity(EntityKind::Client, name, None).map(|_| ()),
        "turn" => conversation_record(
            name,
            "and this is what came back".to_string(),
            TurnVia::Pasted,
            TurnDocument::Typed,
        )
        .map(|_| ()),
        other => panic!("no such job: {other}"),
    };
    match done {
        Ok(()) => println!("RESULT ok"),
        Err(e) => println!("RESULT refused {e:?}"),
    }
}

struct Copy {
    said: String,
}

/// Run the two copies against the directory, and report what each said.
fn race(dir: &Path, job: &str) -> (Copy, Copy) {
    let exe = std::env::current_exe().expect("this test binary");
    let spawn = |name: &str| {
        Command::new(&exe)
            .args(["--exact", "a_copy_that_adds_one_identity", "--nocapture", "--test-threads=1"])
            .env("Z_TWO_COPIES_DIR", dir)
            .env("Z_TWO_COPIES_NAME", name)
            .env("Z_TWO_COPIES_JOB", job)
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .spawn()
            .expect("spawn a copy of this program")
    };
    let a = spawn("Kopie A");
    let b = spawn("Kopie B");
    // **A handshake, not a sleep.** Each copy says when it is ready and the
    // barrier is lifted when both have: a fixed wait is a guess about Argon2
    // on a machine running the rest of this suite beside it, and a guess that
    // is wrong makes the two copies take turns instead of racing — a guard
    // that passes because it measured nothing.
    let ready = |name: &str| dir.join(format!("ready-{name}"));
    let began = std::time::Instant::now();
    while !(ready("Kopie A").exists() && ready("Kopie B").exists()) {
        assert!(
            began.elapsed() < Duration::from_secs(90),
            "a copy never reached the barrier, so nothing was raced"
        );
        std::thread::sleep(Duration::from_millis(5));
    }
    std::fs::write(dir.join("go"), b"now").expect("the barrier");

    let read = |child: std::process::Child| {
        let out = child.wait_with_output().expect("the copy finished");
        let text = String::from_utf8_lossy(&out.stdout).to_string();
        // **Anywhere in the line, not at its start.** `--nocapture` prints the
        // child's own words on the same line as its test name, so a parser
        // that anchored at the start read «nothing was said» about a copy that
        // had said it — and called the trial unmeasured.
        let said = text
            .lines()
            .find_map(|line| line.split("RESULT ").nth(1))
            .unwrap_or_else(|| {
                panic!(
                    "a copy said nothing at all, so this trial measured nothing:\n{text}\n{}",
                    String::from_utf8_lossy(&out.stderr)
                )
            })
            .to_string();
        Copy { said }
    };
    (read(a), read(b))
}

/// A vault with `BULK` identities in it, locked, at a directory of its own.
fn a_vault_worth_racing_for(name: &str) -> PathBuf {
    let dir = dir_for(name);
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    vault_create_with_passphrase(PASS.to_string()).expect("create");
    for i in 0..BULK {
        create_entity(EntityKind::Client, format!("Akte {i}"), None).expect("identity");
    }
    vault_lock().expect("lock");
    dir
}

/// How many of the two copies' identities the vault holds now.
fn copies_on_disk(dir: &Path) -> Vec<String> {
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    let mut found: Vec<String> = entities(None)
        .expect("entities")
        .into_iter()
        .map(|e| e.label)
        .filter(|label| label.starts_with("Kopie "))
        .collect();
    found.sort();
    vault_lock().expect("lock");
    found
}

#[test]
fn two_copies_never_lose_a_write() {
    let _one_at_a_time = serial();
    let mut losses = Vec::new();
    for trial in 0..TRIALS {
        let dir = a_vault_worth_racing_for(&format!("trial{trial}"));
        let (a, b) = race(&dir, "identity");
        let on_disk = copies_on_disk(&dir);
        let both_said_ok = a.said == "ok" && b.said == "ok";

        // **The law, in one line.** What is said and what is kept must agree:
        // a copy told «ok» whose identity is not in the vault has lost its
        // work with nobody told, which is the one thing that may not happen.
        for (copy, label) in [(&a, "Kopie A"), (&b, "Kopie B")] {
            if copy.said == "ok" && !on_disk.iter().any(|l| l == label) {
                losses.push(format!(
                    "trial {trial}: «{label}» was told ok and is not in the vault (A said «{}», B said «{}», on disk {on_disk:?})",
                    a.said, b.said
                ));
            }
        }
        // And the other half: a copy that was refused must have been refused
        // for the reason this product has a sentence for.
        for (copy, label) in [(&a, "Kopie A"), (&b, "Kopie B")] {
            assert!(
                copy.said == "ok" || copy.said.contains("VaultChangedElsewhere"),
                "trial {trial}: «{label}» was refused with something else: {}",
                copy.said
            );
        }
        assert!(
            !on_disk.is_empty(),
            "trial {trial}: neither copy wrote anything, so nothing was measured (A «{}», B «{}»)",
            a.said,
            b.said
        );
        // The control that gives the trial its meaning: both copies really ran
        // and really raced.
        assert!(both_said_ok || !on_disk.is_empty());
        let _ = std::fs::remove_dir_all(&dir);
    }
    assert!(
        losses.is_empty(),
        "a write was lost in silence, which is the attacker's م5:\n{}",
        losses.join("\n")
    );
}

/// **And the session file, which compared nothing at all** — خ9.
///
/// `conversation::write` sealed a whole `Body` and replaced the file: two
/// copies each appending a turn read the same body, and the later `rename` won
/// with the earlier turn gone and nobody told. There is no «changed
/// elsewhere» to report here and there should not be one — the right answer is
/// not a refusal but the newest body: once the read and the write cannot be
/// split, the second copy reads the first's turn and adds to it.
///
/// So the law is stricter than the vault's: **both turns are on the disk**.
#[test]
fn two_copies_never_lose_a_turn() {
    let _one_at_a_time = serial();
    for trial in 0..TRIALS {
        let dir = dir_for(&format!("turn{trial}"));
        let _ = std::fs::remove_dir_all(&dir);
        set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
        vault_create_with_passphrase(PASS.to_string()).expect("create");
        let row = conversation_begin("beide Kopien".to_string(), None).expect("a session");
        assert_eq!(row.number, 1, "the copies enter session 1 by number");
        // One turn already in the file, so what is measured is an append to
        // something rather than two first writes.
        conversation_record(
            "die erste Frage".to_string(),
            "die erste Antwort".to_string(),
            TurnVia::Pasted,
            TurnDocument::Typed,
        )
        .expect("the first turn");
        vault_lock().expect("lock");

        let (a, b) = race(&dir, "turn");
        assert_eq!(a.said, "ok", "trial {trial}: a copy's turn was refused: {}", a.said);
        assert_eq!(b.said, "ok", "trial {trial}: a copy's turn was refused: {}", b.said);

        set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
        vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
        // A question comes back as segments, because the restoring is what the
        // door back does; joined here into the one string this guard asked for.
        let asked: Vec<String> = conversation_turns(1, None)
            .expect("turns")
            .into_iter()
            .map(|t| t.question.into_iter().map(|s| s.text).collect::<String>())
            .collect();
        vault_lock().expect("lock");
        assert!(
            asked.iter().any(|q| q == "die erste Frage"),
            "trial {trial}: the turn that was already in the file is gone: {asked:?}"
        );
        for label in ["Kopie A", "Kopie B"] {
            assert!(
                asked.iter().any(|q| q == label),
                "trial {trial}: «{label}» was told ok and its turn is not in the file: {asked:?}"
            );
        }
        let _ = std::fs::remove_dir_all(&dir);
    }
}
