// 038-B/2 · two Swedish signals — and the guard the lead asked for.
//
// A magazine supplement does two things a letter never does: it credits the
// photographer beside the picture, and it says what a person's part in the work
// is in the middle of a sentence. Both were measured on the owner's own Swedish
// supplement (SV-16) and both left people in the clear:
//
// ```text
// Foto: Gonzalo Irigoyen          in the clear
// Foto: Anja Callius              in the clear
// Projektledare är Cicek Cavdar   in the clear
// ```
//
// **And the second half of this file is the lead's own request:** a narrow
// column, invented, built so that 038-I's change — a name the page broke — is
// visible as a number here rather than staying green and inert. It also pins,
// with its number, the half of that defect 038-I did **not** fix, so 038-C
// starts from a measurement and not from a memory.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ett lösenord som är långt nog";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

fn fresh_vault(name: &str) {
    let _ = vault_lock();
    let dir = std::env::temp_dir().join(format!("zprivacy-column-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");
}

/// A column of a Swedish research supplement, invented line for line — narrow,
/// so that names wrap the way they wrap on a real page.
///
/// Every person in it is made up. The form feed is where page two begins.
const COLUMN: &str = "\
Framtidens forskning\n\
\n\
Foto: Gonzalo Irigoyen\n\
Bild: Stockholm\n\
Fotograf: Anja Callius\n\
\n\
Projektledare är Cicek Cavdar\n\
och arbetet fortsätter.\n\
\n\
Anna Nilsson, programchef\n\
berättar om satsningen.\n\
\n\
Rapporten skrevs av Anna\n\
Nilsson under hösten.\n\
\n\
Enligt Anders Yn-\n\
nerman är resultatet klart.\n\
\u{c}\
Johansson fortsatte arbetet.\n\
\n\
Sist talade Anna Nils-\n\
son om framtiden.\n";

fn scanned(doc: &str, pack: &str) -> SessionId {
    let s = open_session(None, pack.to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");
    scan(s).expect("scan");
    s
}

fn people(session: SessionId, doc: &str, state: MarkState) -> Vec<String> {
    let mut out: Vec<String> = list_findings(session)
        .expect("findings")
        .into_iter()
        .filter(|f| f.kind == Kind::Person && f.state == state)
        .map(|f| {
            doc.chars()
                .skip(f.span.start as usize)
                .take((f.span.end - f.span.start) as usize)
                .collect::<String>()
        })
        .collect();
    out.sort();
    out
}

// ---------------------------------------------------------------- 1 · the credit

/// **A photo credit is proof, and it protects without asking.**
#[test]
fn a_photo_credit_is_a_person_without_being_asked() {
    let _g = serial();
    fresh_vault("credit");
    let s = scanned(COLUMN, "sv");
    let protected = people(s, COLUMN, MarkState::Protected);
    for who in ["Gonzalo Irigoyen", "Anja Callius"] {
        assert!(
            protected.iter().any(|p| p == who),
            "«{who}» was credited and left in the clear: {protected:?}"
        );
    }
    close_session(s).ok();
}

/// **And the same three labels caption pictures.**
///
/// This is why the credit asks for a pair: `Validator::Name` would have taken
/// «Bild: Stockholm» and called a city a person, automatically and without
/// asking. The price of Auto is a given name **and** a surname.
#[test]
fn a_caption_is_not_a_credit() {
    let _g = serial();
    fresh_vault("caption");
    let s = scanned(COLUMN, "sv");
    let all: Vec<String> = people(s, COLUMN, MarkState::Protected)
        .into_iter()
        .chain(people(s, COLUMN, MarkState::Suggested))
        .collect();
    assert!(
        !all.iter().any(|p| p.contains("Stockholm")),
        "a city was taken as a person: {all:?}"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 2 · the role

/// **What a person does is a question, never an answer.**
///
/// Both shapes, and both only offered: a role is strong evidence and not proof.
/// «Cicek Cavdar» is in no Swedish list and ends like nothing — the sentence's
/// own verb is what carries it.
#[test]
fn a_role_beside_a_name_is_offered_not_decided() {
    let _g = serial();
    fresh_vault("role");
    let s = scanned(COLUMN, "sv");
    let offered = people(s, COLUMN, MarkState::Suggested);
    assert!(
        offered.iter().any(|p| p == "Cicek Cavdar"),
        "«Projektledare är Cicek Cavdar» was not offered: {offered:?}"
    );
    assert!(
        offered.iter().any(|p| p == "Anna Nilsson"),
        "«Anna Nilsson, programchef» was not offered: {offered:?}"
    );
    // Never protected on a role alone.
    let protected = people(s, COLUMN, MarkState::Protected);
    assert!(
        !protected.iter().any(|p| p == "Cicek Cavdar"),
        "a role decided for the person: {protected:?}"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 3 · the lead's guard

/// **038-I, made visible by a number instead of staying inert.**
///
/// Three shapes in one column: a pair the page wrapped with no hyphen, a value
/// the page broke at a hyphen, and a pair with a page boundary between its
/// halves. Before 038-I the first was refused for the line break alone.
#[test]
fn the_column_shows_what_the_page_did_to_the_names() {
    let _g = serial();
    fresh_vault("wrapped");
    // Taught, because 038-I's first rule is about a value the app was given.
    let e = create_entity(EntityKind::Person, "Forskare".to_string(), None).expect("entity");
    set_value(e, None, Kind::Person, "Ynnerman".to_string(), Policy::Always).expect("value");

    let s = scanned(COLUMN, "sv");
    let protected = people(s, COLUMN, MarkState::Protected);
    let offered = people(s, COLUMN, MarkState::Suggested);

    // (a) A pair the page wrapped, with no hyphen between the halves.
    assert!(
        offered.iter().any(|p| p == "Anna\nNilsson"),
        "the wrapped pair was not read across the line: {offered:?}"
    );

    // (b) A taught value the page broke at a hyphen — one mark, both halves.
    assert!(
        protected.iter().any(|p| p == "Yn-\nnerman"),
        "the broken surname was not taken whole: {protected:?}"
    );

    // (c) A page boundary is not a line break: «…är resultatet klart.\u{c}
    //     Johansson…» must not pair across it.
    for found in protected.iter().chain(offered.iter()) {
        assert!(
            !found.contains('\u{c}'),
            "a name was read across a page boundary: {found:?}"
        );
    }
    close_session(s).ok();
}

/// **The half 038-I did not fix, pinned with what it actually does.**
///
/// Discovery is blind to a break, and the measurement corrected what I expected
/// of it: «Anna Nils-\nson» produces **nothing at all**, not a half. The pair
/// rule asks for both halves to be known — a given name the lists carry **and**
/// a surname they carry or that ends like one — and «Nils-» is neither, because
/// the page cut it. So the name is missed rather than half-taken.
///
/// That is better than the shape I assumed, and it is worth having written down:
/// the half-protection in the owner's file was a token for the **given** name
/// with the whole broken surname standing beside it, not half of one protection.
///
/// 038-C is where this closes, with the normalised matching layer the owner
/// ruled for Arabic reading for Latin too. When it lands this test fails, and
/// that is what it is for.
#[test]
fn discovery_is_still_blind_to_a_break() {
    let _g = serial();
    fresh_vault("blind");
    let s = scanned(COLUMN, "sv");
    let offered = people(s, COLUMN, MarkState::Suggested);
    let protected = people(s, COLUMN, MarkState::Protected);
    let all: Vec<&String> = offered.iter().chain(protected.iter()).collect();

    // Nothing at all — neither the whole name nor a piece of it.
    for shape in ["Anna Nils-", "Anna Nils-\nson", "Nils-"] {
        assert!(
            !all.iter().any(|p| p.as_str() == shape),
            "«{shape}» is now found — if 038-C has landed, this test has done its \
             job and should be replaced by the whole name: {all:?}"
        );
    }
    // And the control: the same pair **unbroken** two paragraphs above is found,
    // so what is missing here is the break and nothing else.
    assert!(
        offered.iter().any(|p| p == "Anna\nNilsson"),
        "the unbroken pair is missing too, so this test proves nothing: {offered:?}"
    );
    close_session(s).ok();
}

// ---------------------------------------------------------------- 4 · the line

/// **German is left exactly where it was.**
///
/// Not by an `if` about German: the credit labels are rows in the Swedish rule
/// set, and the copula is Swedish pack data whose German list is empty. So the
/// shapes cannot fire there at all, and this test says so in the one way that
/// cannot drift — by running the same column through the German pack.
#[test]
fn the_german_pack_reads_none_of_this() {
    let _g = serial();
    fresh_vault("german");
    let s = scanned(COLUMN, "sv");
    let swedish = people(s, COLUMN, MarkState::Protected).len();
    close_session(s).ok();

    let g = scanned(COLUMN, "de");
    let german = people(g, COLUMN, MarkState::Protected);
    assert!(
        !german.iter().any(|p| p == "Gonzalo Irigoyen" || p == "Anja Callius"),
        "the German pack read a Swedish credit label: {german:?}"
    );
    let offered = people(g, COLUMN, MarkState::Suggested);
    assert!(
        !offered.iter().any(|p| p == "Cicek Cavdar"),
        "the German pack read «är» as a copula: {offered:?}"
    );
    assert!(swedish > german.len(), "the Swedish signals added nothing at all");
    close_session(g).ok();
}
