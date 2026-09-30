//! F-08 by the sharpest test there is: lock, DELETE the file from disk, then
//! unlock with the correct passphrase. If it opens, a cache survived the lock
//! and the word "Locked" does not mean what a person reads it to mean.
//! Also F-09's second half: the wording of a failed unlock.
use z_core::api;

fn main() {
    let dir = std::env::temp_dir().join(format!("zp-lockcache-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    api::set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    api::vault_create_with_passphrase("correct-horse-battery-staple".into()).expect("create");
    println!("CREATED={:?}", api::vault_state());

    api::vault_lock().expect("lock");
    let file = dir.join("vault.zv");
    std::fs::remove_file(&file).expect("remove the vault from disk");
    println!("FILE_ON_DISK={}", file.exists());
    println!("UNLOCK_AFTER_DELETE={:?}", api::vault_unlock_with_passphrase("correct-horse-battery-staple".into()));

    // F-09: the wording when a vault is present but the passphrase is wrong.
    std::fs::create_dir_all(&dir).unwrap();
    api::vault_create_with_passphrase("correct-horse-battery-staple".into()).ok();
    api::vault_lock().ok();
    println!("WRONG_PASSPHRASE={:?}", api::vault_unlock_with_passphrase("not-the-passphrase".into()));
    let _ = std::fs::remove_dir_all(&dir);
}
