//! Privacy packs: the habits of one language.
//!
//! A pack knows **forms** — that a word after «Frau» is usually a person, that a
//! run ending in «GmbH» is a company, that whatever follows «Kundennummer:» is a
//! customer number. It never contains a real person: that is the vault's job, and
//! the difference is why switching packs can leak nothing.
//!
//! A pack is not the language of the interface, and the screen says so in its
//! first line.

pub(crate) mod ar;
pub(crate) mod de;
pub(crate) mod en;
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
    // **Arabic since paper 115**, and last in the list for no reason but the
    // order they were written: `pack_of` finds by id and nothing here is
    // ordered knowledge.
    vec![de::pack(), sv::pack(), en::pack(), ar::pack()]
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
    //
    // **And it drifted the other way on 25 October 2026.** Paper 115 shipped
    // Arabic as a name pack with three rules of its own and **no rule set** —
    // a label set is a `Name:`-style table and Arabic's knowledge is not that
    // shape. So `ar` had everything a session needs and appeared in no row:
    // `ground.packs` is what the app-language card, the session room and the
    // bar's own list are drawn from, and 116 could put the whole interface
    // into Arabic that nobody could choose. The first screen offered it (it
    // reads `offeredLanguages`) and Settings did not, which is the same law at
    // two doors with two answers.
    //
    // So a language is a row if this build carries **either** kind of
    // knowledge for it. `LanguagePack::label` was written for exactly this —
    // «kept for the day a pack ships without a rule set beside it» — and the
    // sets keep their order and their labels, because a set's label is the one
    // a person chose to see.
    let packs = installed_packs();
    let sets = crate::scanner::sets::all();
    let mut rows: Vec<crate::api::PackRow> =
        sets.iter().map(|set| row(set.id, set.label, &packs)).collect();
    for pack in &packs {
        if !sets.iter().any(|set| set.id == pack.id) {
            rows.push(row(pack.id, pack.label, &packs));
        }
    }
    rows
}

/// One row, from whichever of the two registers named the language.
fn row(id: &str, label: &str, packs: &[pack::LanguagePack]) -> crate::api::PackRow {
    let names = packs.iter().find(|p| p.id == id);
    let counts = names
        .map(|p| de_names::dictionary_of(p.locale, p.names).counts())
        .unwrap_or((0, 0));
    crate::api::PackRow {
        id: id.to_string(),
        label: label.to_string(),
        locale: names.map(|p| p.locale.to_string()).unwrap_or_default(),
        version: names.map(|p| p.version.to_string()).unwrap_or_default(),
        own_rules: names
            .map(|p| p.extra.iter().map(|(name, _)| (*name).to_string()).collect())
            .unwrap_or_default(),
        provenance: names.map(|p| p.provenance.to_string()).unwrap_or_default(),
        given: counts.0 as u32,
        family: counts.1 as u32,
    }
}
