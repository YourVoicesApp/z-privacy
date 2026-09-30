use std::fs;
use z_core::api;

fn main() {
    let root = "/tmp/zprivacy-kdf-proof";
    let _ = fs::remove_dir_all(root);
    fs::create_dir_all(root).unwrap();
    api::set_data_dir(root.into()).unwrap();
    api::vault_create_with_passphrase("ZXQ-kdf-passphrase".into()).unwrap();
    api::vault_lock().unwrap();
    let path = format!("{root}/vault.zv");
    let mut bytes = fs::read(&path).unwrap();
    bytes[7..11].copy_from_slice(&1_000_000u32.to_be_bytes());
    fs::write(&path, bytes).unwrap();
    api::set_data_dir(root.into()).unwrap();
    println!("UNLOCK={:?}", api::vault_unlock_with_passphrase("ZXQ-kdf-passphrase".into()));
}
