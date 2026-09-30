use z_core::api::{self, ProviderId};

fn main() {
    for url in [
        "http://127.0.0.1.evil.com:18081",
        "http://127.0.0.1@evil.com:18081",
        "http://evil.com@127.0.0.1:18081",
        "http://2130706433:18081",
        "http://0177.0.0.1:18081",
        "http://0x7f000001:18081",
        "http://127%2e0%2e0%2e1:18081",
        "http://[::ffff:127.0.0.1]:18081",
        "http://[0:0:0:0:0:0:0:1]:18081",
    ] {
        let result = api::connect_provider(
            ProviderId { id: "openai".into() },
            "key".into(), Some(url.into()), Some("model".into()),
        );
        println!("{url} => {result:?}");
    }
}
