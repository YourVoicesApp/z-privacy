//! The built-in rule sets, as rows.
//!
//! Adding a language is adding a file here and listing it in [`ALL`], plus a
//! golden test. **No scanner code changes.** That sentence is not a hope: the
//! test `a_rule_set_this_build_never_heard_of_still_works` builds a set that
//! exists nowhere in this folder and proves it detects.
//!
//! What may *not* be a row is arithmetic — an IBAN checksum, a national number
//! with a control digit. Those stay Rust, as `Validator`s, and a new country
//! that needs one adds a validator, never a scanner.

mod de;
mod en;
mod sv;
mod world;

use super::rules::LabelRule;

/// Every rule set this build carries, in the order the UI lists them.
pub(crate) fn all() -> Vec<RuleSet> {
    vec![de::set(), en::set(), sv::set()]
}

/// One language's worth of label knowledge.
pub(crate) struct RuleSet {
    pub id: &'static str,
    pub label: &'static str,
    /// Words this language puts between a label and a name.
    pub honorifics: Vec<String>,
    pub rules: Vec<LabelRule>,
}

/// The rules of every set named in `active`, flattened.
///
/// An unknown id contributes nothing rather than failing: a profile that names
/// a set a later build removed must still scan, with less knowledge and a
/// truthful list of what actually ran.
pub(crate) fn rules_for(active: &[String]) -> Vec<LabelRule> {
    // The rows that belong to no language run whatever language is chosen —
    // see `world.rs` for which, and for the measurement that put them there.
    let mut out = world::set().rules;
    for set in all() {
        if active.iter().any(|a| a == set.id) {
            out.extend(set.rules);
        }
    }
    out
}

/// The honorifics of every active set, flattened — one list for the engine.
pub(crate) fn honorifics_for(active: &[String]) -> Vec<String> {
    let mut out = Vec::new();
    for set in all() {
        if active.iter().any(|a| a == set.id) {
            out.extend(set.honorifics);
        }
    }
    out
}

/// Which of the requested sets this build actually has. The UI shows this, not
/// what was asked for — «active» must mean «ran», or it is another false fact.
pub(crate) fn known_of(active: &[String]) -> Vec<String> {
    all()
        .into_iter()
        .filter(|s| active.iter().any(|a| a == s.id))
        .map(|s| s.id.to_string())
        .collect()
}
