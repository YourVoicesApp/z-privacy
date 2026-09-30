use std::fs;
use z_core::api::{self, EntityKind, Kind, Policy};

fn main() {
    let root = "/tmp/zprivacy-rollback-proof";
    let _ = fs::remove_dir_all(root);
    fs::create_dir_all(root).unwrap();
    api::set_data_dir(root.into()).unwrap();
    api::vault_create_with_passphrase("ZXQ-rollback-passphrase".into()).unwrap();
    let old = fs::read(format!("{root}/vault.zv")).unwrap();
    let id = api::create_entity(EntityKind::Client, "ZXQ-ROLLBACK-ENTITY-44772".into(), None).unwrap();
    api::set_value(id, None, Kind::Company, "ZXQ-ROLLBACK-VALUE-55883".into(), Policy::Always).unwrap();
    println!("COUNTS_BEFORE={:?}", api::vault_lock());
    fs::write(format!("{root}/vault.zv"), old).unwrap();
    api::set_data_dir(root.into()).unwrap();
    println!("UNLOCK_OLD={:?}", api::vault_unlock_with_passphrase("ZXQ-rollback-passphrase".into()));
    println!("ENTITIES_AFTER={:?}", api::entities(None));
}
