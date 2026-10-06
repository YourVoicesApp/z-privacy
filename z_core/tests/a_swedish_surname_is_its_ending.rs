// 038-B/1 · «every word ending in son is a surname in Sweden».
//
// The owner, 6 October. A patronymic is not a dictionary entry — it is a
// pattern, and Sweden has a few million of them, so no list of names will ever
// hold them. The ending is a **signal** of exactly a dictionary hit's strength:
// it can make the scanner offer a name it would have walked past, and it can
// never protect one by itself.
//
// Pack data, not code: `family_suffixes` is a field of the pack contract, it is
// empty for German, and that is why no German number moved by one.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

fn people(doc: &str, pack: &str) -> Vec<(MarkState, String)> {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, doc.to_string()).expect("import");
    scan(session).expect("scan");
    let units: Vec<u16> = doc.encode_utf16().collect();
    list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person)
        .map(|f| {
            (
                f.state,
                String::from_utf16_lossy(
                    units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
                ),
            )
        })
        .collect()
}

/// A known given name and a word that ends like a surname is a pair, and the
/// surname needs to be in no list at all.
#[test]
fn a_given_name_and_an_ending_make_a_pair() {
    for who in ["Peter Holgersson", "Eva Ragnarsson", "Johan Marklund", "Göran Ekeberg"] {
        let doc = format!("Vi träffade {who} i tisdags.");
        let found = people(&doc, "sv");
        assert!(
            found.iter().any(|(_, text)| text == who),
            "«{who}» is not a person: {found:?}"
        );
        for (state, text) in &found {
            assert_eq!(*state, MarkState::Suggested, "«{text}» was protected by an ending");
        }
    }
}

/// The ending is read backwards too, where a list writes the surname first.
#[test]
fn the_reversed_pair_reads_the_ending_as_well() {
    let page = "Holgersson, Peter     070-123 45 67\n\
        Ragnarsson, Eva       08-123 45 99\n";
    let found = people(page, "sv");
    for who in ["Holgersson, Peter", "Ragnarsson, Eva"] {
        assert!(found.iter().any(|(_, text)| text == who), "«{who}» is not a person: {found:?}");
    }
}

/// The traps, named by the owner and by the language.
#[test]
fn what_an_ending_may_never_make_a_name() {
    for doc in [
        // «person» is a Swedish word, and a sentence may begin with it.
        "Varje person som deltar får ett intyg.",
        "Person som saknar legitimation kan inte delta.",
        // «Hilsen» closes a Danish letter. This is the Swedish pack, and it
        // carries no «-sen» — a Dane's surname is 038-B's later work.
        "Med venlig hilsen Lars",
        "Hilsen fra København.",
        // The nouns that cost `-ling` its place in the list.
        "Vår AI-utveckling fortsätter under 2026.",
        "Bröstcancerbehandling diskuterades på mötet.",
        // A city is not a surname, which is what cost `-holm` its place.
        "Kontoret ligger i Stockholm sedan 2019.",
    ] {
        let found = people(doc, "sv");
        assert!(found.is_empty(), "«{doc}» named a person: {found:?}");
    }
}

/// And a word standing alone is never a person, whatever it ends with: the
/// evidence is the given name beside it.
#[test]
fn an_ending_alone_names_nobody() {
    for doc in ["Holgersson deltog i mötet.", "Rapporten skrevs av Wallerstedt."] {
        let found = people(doc, "sv");
        assert!(found.is_empty(), "«{doc}» named a person from one word: {found:?}");
    }
}

/// German is the control: the field is empty there, so an ending proves
/// nothing — «Lindenberg» and «Petersson» are words like any other until a
/// dictionary or a rule says otherwise.
#[test]
fn german_has_no_endings_and_nothing_german_moved() {
    // «Quellenberg» and «Wiesenlund» are not in the German name bank — checked,
    // so what this test measures is the ending and not the dictionary.
    for doc in ["Wir trafen Thomas Quellenberg am Dienstag.", "Anna Wiesenlund hat angerufen."] {
        let found = people(doc, "de");
        assert!(
            found.is_empty(),
            "a German word was read as a surname by its ending, in «{doc}»: {found:?}"
        );
    }
}
