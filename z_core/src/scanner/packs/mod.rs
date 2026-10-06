//! Privacy packs: the habits of one language.
//!
//! A pack knows **forms** — that a word after «Frau» is usually a person, that a
//! run ending in «GmbH» is a company, that whatever follows «Kundennummer:» is a
//! customer number. It never contains a real person: that is the vault's job, and
//! the difference is why switching packs can leak nothing.
//!
//! A pack is not the language of the interface, and the screen says so in its
//! first line.

pub(crate) mod de;
pub(crate) mod pack;
pub(crate) mod people;
pub(crate) mod sv;
pub(crate) mod de_names;

use super::Candidate;

/// Run the pack named by `id`. An unknown id simply contributes nothing — a
/// missing pack must never be an error that stops a document from being scanned.
/// Every pack this build carries, by id.
///
/// One list, read by the dispatch and by the report. A pack that is not in it
/// contributes nothing rather than failing — the same rule the label sets
/// follow, and for the same reason: a profile that names a pack a later build
/// removed must still scan.
/// The languages this build does **not** carry yet, and says so.
///
/// A list of what is coming belongs where the packs themselves are, so that the
/// day one of these ships it moves up by being written once — a screen that
/// kept its own list would go on promising a language that had already arrived,
/// or promising one that was dropped.
///
pub(crate) fn installed_packs() -> Vec<pack::LanguagePack> {
    vec![de::pack(), sv::pack()]
}

fn pack_of(id: &str) -> Option<pack::LanguagePack> {
    installed_packs().into_iter().find(|p| p.id == id)
}

/// The names a document uses that no list knows, for whichever pack is active.
///
/// The rules are the pack contract's, so a language gets discovery by being
/// data — this is the function that makes «Find once → Teach once» a property
/// of the architecture rather than of German.
pub(crate) fn discover(
    text: &str,
    id: &str,
    taught: &dyn Fn(&str) -> bool,
) -> Vec<people::NameHint> {
    match pack_of(id) {
        Some(pack) => people::discover_names(text, &pack, taught),
        None => Vec::new(),
    }
}

pub(crate) fn scan(text: &str, id: &str, names: &[(String, bool)]) -> Vec<Candidate> {
    // One line, and it is the whole of what «German is not a special case»
    // means: the pack is looked up by id and the shared rules read it. The
    // names the person taught travel with the text, the way the taught label
    // rules and the vault's hints do — knowledge is an argument here, never a
    // global somebody could forget to pass.
    match pack_of(id) {
        Some(pack) => people::scan_with(text, &pack, names),
        None => Vec::new(),
    }
}

/// The packs this build carries. The label belongs to the pack, not to a screen:
/// a rules engine names itself, and the UI only draws what it is told (task 022).
pub(crate) fn installed() -> Vec<crate::api::PackRow> {
    // Read from the rule sets, never listed again here. Two lists of the same
    // fact drift, and this one already did: `en` shipped as a rule set on 29
    // September while this function still said German was the only pack, so
    // First Run offered a language it could not actually select.
    let packs = installed_packs();
    crate::scanner::sets::all()
        .into_iter()
        .map(|set| {
            let names = packs.iter().find(|p| p.id == set.id);
            let counts = names
                .map(|p| de_names::dictionary_of(p.locale, p.names).counts())
                .unwrap_or((0, 0));
            crate::api::PackRow {
                id: set.id.to_string(),
                label: set.label.to_string(),
                locale: names.map(|p| p.locale.to_string()).unwrap_or_default(),
                version: names.map(|p| p.version.to_string()).unwrap_or_default(),
                own_rules: names
                    .map(|p| p.extra.iter().map(|(name, _)| (*name).to_string()).collect())
                    .unwrap_or_default(),
                provenance: names.map(|p| p.provenance.to_string()).unwrap_or_default(),
                given: counts.0 as u32,
                family: counts.1 as u32,
            }
        })
        .collect()
}
