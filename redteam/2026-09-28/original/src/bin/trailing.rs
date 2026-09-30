use std::fs;
use z_core::api;

fn main() {
    let root = "/tmp/zprivacy-trailing-proof";
    let _ = fs::remove_dir_all(root);
    fs::create_dir_all(root).unwrap();
    api::set_data_dir(root.into()).unwrap();
    api::vault_create_with_passphrase("ZXQ-trailing-passphrase".into()).unwrap();
    api::vault_lock().unwrap();
    let path = format!("{root}/vault.zv");
    let mut bytes = fs::read(&path).unwrap();
    bytes.extend_from_slice(b"ZXQ-UNAUTHENTICATED-TRAILER-99221");
    fs::write(&path, bytes).unwrap();
    api::set_data_dir(root.into()).unwrap();
    println!("UNLOCK_WITH_TRAILER={:?}", api::vault_unlock_with_passphrase("ZXQ-trailing-passphrase".into()));
}
