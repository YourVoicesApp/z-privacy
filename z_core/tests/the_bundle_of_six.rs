// 046/H · the catalogue is a bundle of six, and not one of them is a guess.
//
// **The owner, 7 October:** the chat screen should carry a chosen list of
// models that will become a subscribable bundle — ChatGPT · Claude · Grok ·
// DeepSeek · Kimi · Gemini — and at this stage the model that has a key is
// drawn in a different colour.
//
// Four companies arrived as four files. **Not one of them has been called**,
// and this file is partly here to keep that true by measurement rather than by
// memory: a provider with no credential reports itself as needing one and as
// unavailable, which is what the screen draws as «Connect» rather than as
// ready. The owner's keys are for OpenAI and Anthropic and those are the only
// two this program has ever spoken to.
//
// And the rule every model id in this build obeys, which `openai.rs` records
// in its own comments because it was once broken: **an id comes from the
// company's own current documentation, read and quoted, never written from
// memory.** Each provider file names its page and the date it was read.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::collections::BTreeSet;

use z_core::api::*;

/// The six the owner named, by the id each file answers to, in the order a
/// person sees them.
const BUNDLE: &[&str] = &["openai", "anthropic", "xai", "deepseek", "moonshot", "google"];

/// The four that arrived in 046/H, and have never been called.
const AWAITING_A_KEY: &[&str] = &["xai", "deepseek", "moonshot", "google"];

fn rows() -> Vec<ProviderRow> {
    providers().expect("providers")
}

fn catalogue() -> Vec<ModelDescriptor> {
    models().expect("models")
}

// ---------------------------------------------------------------- 1 · the six

/// **The bundle the owner named, in the order he named it.**
#[test]
fn the_catalogue_carries_the_six() {
    let ids: Vec<String> = rows().into_iter().map(|p| p.id).collect();
    for want in BUNDLE {
        assert!(ids.iter().any(|id| id == want), "«{want}» is not in the catalogue: {ids:?}");
    }
    // The order is the catalogue's, and the screen groups by it rather than
    // sorting — so the order is a fact worth holding.
    let mine: Vec<&String> = ids.iter().filter(|id| BUNDLE.contains(&id.as_str())).collect();
    assert_eq!(
        mine,
        BUNDLE.iter().collect::<Vec<_>>(),
        "the six are not in the order the screen will draw them"
    );
}

/// Every one of the four names itself in words a person would recognise from
/// the owner's own sentence — the company, and the model family in brackets
/// where the two differ.
#[test]
fn each_new_provider_says_whose_it_is() {
    let want = [
        ("xai", "Grok"),
        ("deepseek", "DeepSeek"),
        ("moonshot", "Kimi"),
        ("google", "Gemini"),
    ];
    for (id, inside) in want {
        let row = rows().into_iter().find(|p| p.id == id).expect(id);
        assert!(
            row.label.contains(inside),
            "«{id}» is labelled «{}», which does not name {inside}",
            row.label
        );
    }
}

// ---------------------------------------------------------------- 2 · no guess

/// **Every model in the four new lists carries a context figure.**
///
/// `context_k` means thousands of tokens, so a `0` would be drawn as «0K» —
/// a number shaped like a fact, which is the one thing this product may never
/// print. The rule for this task was: one page per model, and a model whose
/// figure nobody published does not ship. So a zero here means a model was
/// added without its page being read.
#[test]
fn not_one_model_ships_without_its_number() {
    for model in catalogue() {
        if !AWAITING_A_KEY.contains(&model.provider_id.as_str()) {
            continue;
        }
        assert!(
            model.context_k > 0,
            "«{}» of «{}» has no context figure — the rule is that it does not ship until a page publishes one",
            model.model_id,
            model.provider_id
        );
    }
}

/// Each of the four offers something, so «in the catalogue» is not an empty
/// promise, and no id is claimed twice across the whole bundle.
#[test]
fn each_new_provider_offers_models_and_no_id_is_claimed_twice() {
    for id in AWAITING_A_KEY {
        let mine: Vec<ModelDescriptor> =
            catalogue().into_iter().filter(|m| m.provider_id == *id).collect();
        assert!(!mine.is_empty(), "«{id}» is in the catalogue and offers nothing");
    }
    let all: Vec<String> = catalogue().into_iter().map(|m| m.model_id).collect();
    let unique: BTreeSet<&String> = all.iter().collect();
    assert_eq!(
        all.len(),
        unique.len(),
        "a model id is claimed by two providers, so choosing one is ambiguous: {all:?}"
    );
}

/// The address each provider starts at is its own company's, over TLS, and not
/// an aggregator — the owner's rule since the second provider was added.
#[test]
fn each_new_provider_goes_to_its_own_company() {
    let want = [
        ("xai", "https://api.x.ai"),
        ("deepseek", "https://api.deepseek.com"),
        ("moonshot", "https://api.moonshot.ai"),
        ("google", "https://generativelanguage.googleapis.com"),
    ];
    for (id, host) in want {
        let row = rows().into_iter().find(|p| p.id == id).expect(id);
        assert!(
            row.base_url.starts_with(host),
            "«{id}» starts at «{}», which is not {host}",
            row.base_url
        );
    }
}

// ---------------------------------------------------------------- 3 · honesty

/// **Awaiting a key, and never presented as proven.**
///
/// This is the test that keeps the claim honest: with no credential, each of
/// the four says it needs one and that nothing of it is usable in this run.
/// `available` is what the screen reads to decide between a ready colour and
/// «Connect», so these two facts are the whole of the difference between
/// «we can speak to six companies» and «six are in the list, two have keys».
#[test]
fn the_four_say_they_are_waiting_for_a_key() {
    for id in AWAITING_A_KEY {
        let row = rows().into_iter().find(|p| &p.id == id).expect(id);
        assert!(
            row.credential_required,
            "«{id}» does not say it needs a key, so a screen could draw it as ready"
        );
        assert!(!row.connected, "«{id}» reports itself connected and it has never been called");
        for model in catalogue().into_iter().filter(|m| &m.provider_id == id) {
            assert!(
                !model.available,
                "«{}» of «{id}» reports itself usable in this run",
                model.model_id
            );
        }
    }
}

/// And the echo provider stays the only one a test can actually reach, so a
/// green suite is never evidence that a company was called.
#[test]
fn the_only_reachable_provider_in_a_test_build_is_the_echo() {
    let reachable: Vec<String> = catalogue()
        .into_iter()
        .filter(|m| m.available)
        .map(|m| m.provider_id)
        .collect();
    for id in &reachable {
        assert!(
            !BUNDLE.contains(&id.as_str()),
            "«{id}» is reachable with no credential stored, which no company's API is"
        );
    }
}
