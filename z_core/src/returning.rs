//! **A document that comes back** — 079, the import side.
//!
//! A z-pdf leaves with the conversation's tokens standing where the values
//! stood, and an answer page whose top line is «Z-pdf : » and the session's own
//! token for «Zprivacy-svara». What comes back — the same pages with an answer
//! written on them, a reply typed under them, a model's rewrite — carries those
//! tokens, and this is the one place that reads them back into values.
//!
//! **One function, and no token store crosses it** (the lead's ruling of
//! 14 October). The caller hands in text and is handed back the text as this
//! machine can read it, the tokens that stay tokens **by name**, and which
//! conversations answered. Nothing else: not the store, not a token→value map,
//! not a key. The values are matched inside this module and never leave the
//! crate, which is the same boundary `ops::conversation::turns` keeps for a
//! stored turn — «what crosses the boundary is restored text, never a stored
//! token».
//!
//! ## How a token finds its conversation
//!
//! Every token says which conversation minted it: the namespace is four hex of
//! a key derived from that conversation's own 32 bytes (`Naming::of_session`).
//! So the tokens are **grouped by namespace** and each group is resolved
//! against its own conversation — by every namespace, not by the open one. A
//! document that came back from Monday's conversation while Friday's is open is
//! the ordinary case, and the owner's whole design is that Monday's names mean
//! nothing in Friday's conversation.
//!
//! A namespace no conversation of this vault names is **said by name** rather
//! than passed over. It is not an error: a document from another machine, or
//! from a conversation since forgotten, is a true thing to be told.
//!
//! ## What can be brought back, and what cannot
//!
//! Three sources, and they are the whole of it:
//!
//!   1. **The answer page's own word.** Known in advance (`ANSWER_PAGE_WORD`),
//!      so its name derives under any conversation's key with nothing stored.
//!      That makes it the fastest proof of origin — one derivation per
//!      conversation says «this page came from here» — and the lead's ruling is
//!      that it is the **fastest** proof and not the only key: everything below
//!      is resolved whether or not the page came with it.
//!   2. **A value the vault holds.** Every spelling is derived under that
//!      conversation's key and compared with the tail in the text. The
//!      derivation runs one way only — a value gives its name, a name gives no
//!      value — so this resolves exactly the values the person taught, and
//!      nothing is searched for in the document.
//!   3. **A bench of that conversation still in memory.** Its store holds this
//!      run's own tokens, including the ones nobody taught the vault and the
//!      random names a bench mints before a session exists.
//!
//! What is left is the cost the owner is weighing as this is written, and the
//! door's job is to **say** it rather than to hide it: a name the scanner
//! protected, in a conversation now closed, that the vault was never taught,
//! does not come back. The sentence on the glass is the owner's own.
//!
//! ## What the door may not do
//!
//! Read, and nothing else: **no turn is written, the vault is untouched,
//! nothing is protected.** The lead's words — if a later round offers «open
//! this conversation to bring back the rest», it is a button, not a side
//! effect.

use std::collections::BTreeMap;

use crate::api::{Piece, Segment};
use crate::session::Core;
use crate::tokens::{self, ANSWER_PAGE_WORD};

/// One conversation that answered, and what it brought back.
pub(crate) struct Answered {
    pub number: u32,
    pub name: String,
    pub brought_back: u32,
    pub unresolved: u32,
    pub answer_page: bool,
}

/// A returning document, as this machine can read it.
pub(crate) struct Returned {
    pub restored: Vec<Segment>,
    pub tokens: u32,
    pub vault: crate::api::VaultState,
    pub names: u32,
    pub brought_back: u32,
    pub unresolved: Vec<String>,
    pub conversations: Vec<Answered>,
    pub unknown_namespaces: Vec<String>,
}

/// What one namespace resolved to, and who it belongs to.
struct Group {
    conversation: Option<(u32, String)>,
    /// Token name → value, for the tokens of this namespace that stand in this
    /// text. Built here, read here, dropped here.
    values: BTreeMap<String, String>,
    answer_page: Option<String>,
}

/// **The seam** — text in, text out, and the names of what could not come back.
pub(crate) fn returning_document(core: &mut Core, text: &str) -> Returned {
    // **The vault answers first.** With none open, no conversation can be
    // named: the namespace is derived from a key this machine cannot reach, so
    // every namespace would be reported as one no conversation here holds —
    // which is false, and the cause is the lock. Carried out rather than
    // guessed at, the way `ScanReport::vault` is carried for the band's own
    // line: «a locked vault means the app cannot recognise your own people».
    let vault = core.vault.state();
    // Where the tokens stand. The shape test is `tokens::is_token`, through the
    // one walk that knows it, so a candidate that merely looks like a token is
    // text here exactly as it is everywhere else.
    let places = tokens::token_spans(text);
    if places.is_empty() {
        return Returned {
            restored: if text.is_empty() {
                Vec::new()
            } else {
                vec![Segment { text: text.to_string(), piece: Piece::Words }]
            },
            tokens: 0,
            vault,
            names: 0,
            brought_back: 0,
            unresolved: Vec::new(),
            conversations: Vec::new(),
            unknown_namespaces: Vec::new(),
        };
    }

    // Grouped by namespace, which is the part of a token that says whose it is.
    let mut by_namespace: BTreeMap<String, Vec<String>> = BTreeMap::new();
    for (start, end) in &places {
        let Some(token) = text.get(*start..*end) else { continue };
        let Some((namespace, _, _)) = tokens::parts_of(token) else { continue };
        let mine = by_namespace.entry(namespace.to_string()).or_default();
        if !mine.iter().any(|t| t == token) {
            mine.push(token.to_string());
        }
    }

    let groups: BTreeMap<String, Group> = by_namespace
        .iter()
        .map(|(namespace, wanted)| (namespace.clone(), resolve(core, namespace, wanted)))
        .collect();

    // ------------------------------------------------------------ the reading
    let mut restored: Vec<Segment> = Vec::new();
    let mut plain = String::new();
    // **Counted by name and not by place**, both of them, so that the two
    // numbers add up to the names in the document and a reader can tell at a
    // glance that nothing fell between them. An IBAN standing twice is one
    // name, and «one name did not come back» is the sentence a person can act
    // on — «two places did not come back» is a fact about our own text.
    let mut brought: Vec<String> = Vec::new();
    let mut unresolved: Vec<String> = Vec::new();
    let mut cursor = 0usize;
    let mut per_namespace: BTreeMap<String, (u32, u32)> = BTreeMap::new();
    for (start, end) in &places {
        let Some(token) = text.get(*start..*end) else { continue };
        if let Some(before) = text.get(cursor..*start) {
            plain.push_str(before);
        }
        cursor = *end;
        let namespace = tokens::parts_of(token).map(|(n, _, _)| n).unwrap_or_default();
        let value = groups.get(namespace).and_then(|g| g.values.get(token));
        match value {
            Some(value) => {
                if !plain.is_empty() {
                    restored.push(Segment { text: std::mem::take(&mut plain), piece: Piece::Words });
                }
                restored.push(Segment { text: value.clone(), piece: Piece::Restored });
                // **The answer page's own token is brought back and not
                // counted**, the same rule the export side wrote for the same
                // reason (`Session::rename_all`): the number this door says
                // aloud is about the person's own names, and the page's word is
                // ours. It is reported as the proof of origin instead.
                let ours = groups.get(namespace).and_then(|g| g.answer_page.as_deref()) == Some(token);
                if !ours && !brought.iter().any(|t| t == token) {
                    brought.push(token.to_string());
                    per_namespace.entry(namespace.to_string()).or_default().0 += 1;
                }
            }
            None => {
                if !plain.is_empty() {
                    restored.push(Segment { text: std::mem::take(&mut plain), piece: Piece::Words });
                }
                restored.push(Segment { text: token.to_string(), piece: Piece::Unresolved });
                if !unresolved.iter().any(|t| t == token) {
                    unresolved.push(token.to_string());
                    per_namespace.entry(namespace.to_string()).or_default().1 += 1;
                }
            }
        }
    }
    if let Some(tail) = text.get(cursor..) {
        plain.push_str(tail);
    }
    if !plain.is_empty() {
        restored.push(Segment { text: plain, piece: Piece::Words });
    }

    // ------------------------------------------------------------ who answered
    let mut conversations: Vec<Answered> = Vec::new();
    let mut unknown_namespaces: Vec<String> = Vec::new();
    for (namespace, group) in &groups {
        let (back, left) = per_namespace.get(namespace).copied().unwrap_or((0, 0));
        match &group.conversation {
            Some((number, name)) => conversations.push(Answered {
                number: *number,
                name: name.clone(),
                brought_back: back,
                unresolved: left,
                answer_page: group.answer_page.is_some(),
            }),
            // **«Matches nothing» needs something to match against.** With no
            // vault open there is no conversation to compare a namespace with
            // — the comparison is a key this machine cannot reach — so saying
            // «this vault does not hold it» would be a false fact written in
            // the core and read out by every screen. `vault` above says why
            // instead, and the list stays empty.
            None if vault == crate::api::VaultState::Unlocked => {
                unknown_namespaces.push(namespace.clone())
            }
            None => {}
        }
    }
    conversations.sort_by_key(|c| c.number);

    Returned {
        restored,
        tokens: places.len().min(u32::MAX as usize) as u32,
        vault,
        names: (brought.len() + unresolved.len()).min(u32::MAX as usize) as u32,
        brought_back: brought.len().min(u32::MAX as usize) as u32,
        unresolved,
        conversations,
        unknown_namespaces,
    }
}

/// One namespace: whose it is, and what of it this machine can read.
///
/// The three sources are asked in the order that resolves the most, and they
/// cannot disagree about a value: the store's own name for a value is the name
/// derived from it, which is the whole of `TokenMint::rename_all`.
fn resolve(core: &mut Core, namespace: &str, wanted: &[String]) -> Group {
    let mut values: BTreeMap<String, String> = BTreeMap::new();
    let mut answer_page = None;

    // 3. A bench of this conversation still in memory. First, because it holds
    //    the random names a bench mints before a session exists, which derive
    //    from nothing and can be read nowhere else.
    for bench in core.benches() {
        if bench.mint.namespace() != namespace {
            continue;
        }
        for token in wanted {
            if let Some(entry) = bench.tokens.get(token) {
                values.insert(token.clone(), entry.value.expose().to_string());
            }
        }
    }

    // Which conversation this namespace belongs to. Every one of them is asked,
    // because the open one is no more likely to be the answer than any other.
    let numbers: Vec<(u32, String)> =
        core.vault.conversations().into_iter().map(|(n, name, _)| (n, name)).collect();
    let mut conversation = None;
    for (number, name) in numbers {
        let Some(naming) = core.vault.naming_of(number) else { continue };
        if naming.namespace() != namespace {
            continue;
        }
        conversation = Some((number, name));

        // 1. The answer page's own word, under this conversation's key.
        if let Some(tail) = naming.tail(ANSWER_PAGE_WORD) {
            if let Some(token) = with_tail(wanted, &tail) {
                answer_page = Some(token.clone());
                values.entry(token).or_insert_with(|| ANSWER_PAGE_WORD.to_string());
            }
        }

        // 2. Every spelling the vault holds, derived and compared. One way
        //    only: a value gives its name, a name gives no value.
        for spelling in core.vault.every_spelling() {
            let Some(tail) = naming.tail(&spelling) else { continue };
            if let Some(token) = with_tail(wanted, &tail) {
                values.entry(token).or_insert(spelling);
            }
        }
        break;
    }

    Group { conversation, values, answer_page }
}

/// The token of this group that carries this tail, if one does.
///
/// The tail and not the whole name: the tail is a MAC over the value alone
/// (`Naming::tail`), so it is the value's own identity, while the kind in the
/// middle of the name is what the scanner thought the value was. A value taught
/// as a company and protected as a person is one value, and a door that
/// compared whole names would hand back «we could not bring this one back»
/// about a value it holds.
fn with_tail(wanted: &[String], tail: &str) -> Option<String> {
    wanted
        .iter()
        .find(|token| tokens::parts_of(token).is_some_and(|(_, _, t)| t == tail))
        .cloned()
}
