//! # z_web — the trial's door into the core (paper 122 part A)
//!
//! The page loads this as `z_web.js` + `z_web_bg.wasm` and calls fifteen
//! synchronous functions, each taking one JSON string and answering one. The
//! doors themselves live in [`doors`], as plain Rust, so that the parity test
//! can replay the browser's calls through the native core.
//!
//! What the module may ask of the page is checked by gate G1g, by name: the
//! two clocks, the browser's randomness, and wasm-bindgen's own glue.

pub mod doors;

#[cfg(target_arch = "wasm32")]
mod exports {
    use wasm_bindgen::prelude::wasm_bindgen;

    use crate::doors;

    macro_rules! export {
        ($($name:ident),* $(,)?) => {$(
            #[wasm_bindgen]
            pub fn $name(request: &str) -> String {
                doors::$name(request)
            }
        )*};
    }

    export!(
        z_open,
        z_import_text,
        z_scan,
        z_protect,
        z_unprotect,
        z_answer_finding,
        z_build_payload,
        z_payload_to_take_out,
        z_ingest_answer,
        z_restored_view,
        z_set_question,
        z_question_to_take_out,
        z_turns,
        z_end_the_chat,
        z_close,
    );
}
