// **Which folder is this vault in?** — 098, item 2.
//
// The owner met a Windows machine on 20 October where the installed build
// asked him to create a new vault, with his own vault sitting on the same
// disc. Two installs can hold two vaults there: a package installed from the
// `.msix` has its `%LOCALAPPDATA%` redirected into the package's own data
// folder, so `data_dir.rs`'s one answer lands in two places, and the person
// sees only the one they are in — with nothing on any screen naming it.
//
// The measurement that says which path each install really uses belongs to a
// Windows machine (`docs/INBOX/to-windows.md`), and no path is decided here.
// What is decided here is that **the app can be asked**, by the one list the
// Settings room already reads, and that what it answers is the folder it is
// **using** — not the folder it would have chosen.
//
// **That difference is the whole test.** `default_data_dir()` answers what
// this machine's variables say; `set_data_dir` is what the application
// actually called, twice over (`main.dart` and the shell, the second with a
// folder a guard may hand it). A screen that printed the default would be
// right on Linux, right on the installer build, and **wrong on exactly the
// install the owner met** — the shape «a gate green for the wrong reason», in
// a sentence a person is asked to trust.
//
// One test, deliberately: the folder is global to this process, and two tests
// setting their own would race each other into measuring the other's.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

use z_core::api::*;

#[test]
fn the_one_list_names_the_folder_the_app_is_using() {
    // Nothing is set yet in this process: the list may not invent a folder.
    let before = settings().expect("settings with no folder set").data_dir;
    assert_eq!(
        before, None,
        "the list named a folder «{before:?}» before anything set one — \
         «no folder this run» and «this folder» are two states, and one value \
         may not mean both"
    );

    let dir = std::env::temp_dir().join(format!("zprivacy-which-folder-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    let chosen = dir.to_string_lossy().to_string();
    set_data_dir(chosen.clone()).expect("the folder the application chose");

    // 1 · the read door
    let said = settings().expect("settings").data_dir;
    assert_eq!(
        said.as_deref(),
        Some(chosen.as_str()),
        "the list says «{said:?}» and the application is using «{chosen}»; a \
         person reading the Settings room would be told about a folder nobody \
         opened — which is what the MSIX install does to the default"
    );

    // 2 · and the write door answers with the same folder, from the same
    //     source — one fact, one source, or the room would show one path after
    //     a save and another after a re-read.
    let current = settings().expect("settings");
    let back = save_settings(Settings { reveal_seconds: 7, ..current }).expect("save");
    assert_eq!(
        back.data_dir.as_deref(),
        Some(chosen.as_str()),
        "the save door answered «{:?}» while the read door answered «{chosen}»",
        back.data_dir
    );

    // 3 · a vault is not what makes the folder knowable. The incident's own
    //     state — a folder with no vault in it — is the one where the sentence
    //     matters most, because «create a new vault» is the screen the owner
    //     was looking at.
    assert_eq!(
        vault_state(),
        Ok(VaultState::Absent),
        "this folder is empty, so there is no vault in it yet"
    );
    assert!(
        settings().expect("settings").data_dir.is_some(),
        "the folder went quiet as soon as there was no vault in it — and that \
         is the only screen where a person needs to read it"
    );

    let _ = std::fs::remove_dir_all(&dir);
}
