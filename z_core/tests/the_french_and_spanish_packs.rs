//! **French and Spanish** — paper 120, 2 November 2026: the numbers that
//! matter, each by its check, and names by their shape, only ever offered.
//!
//! Measured on two invented letters written for this paper — `Lettre_Dupont.txt`
//! (FR-1) and `Carta_Garcia.txt` (ES-1) — whose people are invented and whose
//! numbers were made valid by their own checks. No owner document and no owner
//! vault is read anywhere here.
//!
//! ```text
//!     FR-1 under «fr»     7 auto · 9 waiting
//!     ES-1 under «es»     7 auto · 9 waiting
//! ```
//!
//! Every name in either count is in the waiting half, and that is the paper's
//! line: there is no French or Spanish name list behind these packs, so a name
//! is a question. The waiting half of ES-1 includes «Seguridad Social», which
//! Spanish writes with capitals and the shape rule cannot tell from a person —
//! the cost of the owner's rule, measured and left in the open.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};
use z_core::api::*;

const FR1: &str = include_str!("fixtures/Lettre_Dupont.txt");
const ES1: &str = include_str!("fixtures/Carta_Garcia.txt");

const PASS: &str = "un mot de passe assez long pour le coffre de ces essais";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

struct Ground(std::path::PathBuf);

impl Ground {
    fn fresh(tag: &str) -> Self {
        let _ = vault_lock();
        let dir = std::env::temp_dir().join(format!("zprivacy-120-{tag}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
        Self(dir)
    }
}

impl Drop for Ground {
    fn drop(&mut self) {
        let _ = vault_lock();
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

struct Found {
    text: String,
    state: MarkState,
    kind: Kind,
    source: Source,
    reason: String,
}

/// Every finding of one scan, as the text it points at (read through UTF-16
/// offsets, which is what a span counts).
fn found_in(pack: &str, text: &str) -> Vec<Found> {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, text.to_string()).expect("import");
    scan(session).expect("scan");
    let units: Vec<u16> = text.encode_utf16().collect();
    let out = list_findings(session)
        .expect("findings")
        .into_iter()
        .map(|f| Found {
            text: String::from_utf16_lossy(&units[f.span.start as usize..f.span.end as usize]),
            state: f.state,
            kind: f.kind,
            source: f.source,
            reason: f.reason,
        })
        .collect();
    let _ = close_session(session);
    out
}

fn counts(pack: &str, text: &str) -> (u32, u32) {
    let session = open_session(None, pack.to_string()).expect("open");
    import_text(session, text.to_string()).expect("import");
    let report = scan(session).expect("scan");
    let _ = close_session(session);
    (report.auto, report.suggested)
}

fn show(found: &[Found]) -> String {
    found.iter().map(|f| format!("«{}» {:?} {:?}", f.text, f.kind, f.state)).collect::<Vec<_>>().join(" · ")
}

/// The one finding that is exactly `value`, if any.
fn the<'a>(found: &'a [Found], value: &str) -> Option<&'a Found> {
    found.iter().find(|f| f.text == value)
}

/// Is any part of `value` inside a finding of `kind`?
fn touched(found: &[Found], line: &str, value: &str, kind: Kind) -> bool {
    let at = line.find(value).expect("the line holds its value");
    let (from, to) = (line[..at].chars().count(), line[..at + value.len()].chars().count());
    found.iter().any(|f| {
        f.kind == kind && {
            let start = line.find(&f.text).map(|b| line[..b].chars().count()).unwrap_or(usize::MAX);
            let end = start.saturating_add(f.text.chars().count());
            start < to && from < end
        }
    })
}

/// One row of the table: the value in a line of the language's own, found as
/// `kind` and `state`; and the same line with one digit changed, not found as
/// that kind at all.
fn row(pack: &str, line: &str, value: &str, kind: Kind, state: MarkState, broken: &str) {
    let found = found_in(pack, line);
    let hit = the(&found, value).unwrap_or_else(|| panic!("«{value}» was not found in «{line}»: {}", show(&found)));
    assert_eq!(hit.kind, kind, "«{value}» was found as the wrong kind: {}", show(&found));
    assert_eq!(hit.state, state, "«{value}» was found in the wrong state: {}", show(&found));
    assert_eq!(hit.source, Source::LanguagePack, "«{value}» was not found by the {pack} pack");

    let line2 = line.replace(value, broken);
    assert_ne!(line, line2, "the broken value is not in the line");
    let found2 = found_in(pack, &line2);
    assert!(
        !touched(&found2, &line2, broken, kind),
        "«{broken}» fails its check and was found anyway: {}",
        show(&found2)
    );
}

// --------------------------------------------------------------- 1 · numbers

/// **Every French row of the table is found when its check comes out**, and
/// not when one digit of it is changed.
#[test]
fn every_french_number_is_found_by_its_check_and_not_one_digit_off() {
    let _g = serial();
    let _ground = Ground::fresh("fr-rows");
    use Kind::*;
    use MarkState::*;
    // NIR — and Corsica, whose department is «2A» and is counted as 19.
    row("fr", "N° de sécurité sociale : 2 91 06 75 118 042 18.", "2 91 06 75 118 042 18", SocialInsuranceNo, Protected, "2 91 06 75 118 043 18");
    row("fr", "Assuré : 1 72 05 2A 004 123 14", "1 72 05 2A 004 123 14", SocialInsuranceNo, Protected, "1 72 05 2A 004 124 14");
    // SIREN — nine digits after the word that names them.
    row("fr", "SIREN 512 479 361, inscrite au registre.", "512 479 361", TaxId, Protected, "512 479 362");
    // SIRET — and the digit is changed inside the SIREN, because a SIRET
    // changed in its last five is a valid SIREN followed by five digits, and
    // that SIREN is rightly found.
    row("fr", "Établissement 512 479 361 00028 à Lyon.", "512 479 361 00028", TaxId, Protected, "512 479 371 00028");
    // La Poste: its SIRET does not pass Luhn, and the published exception
    // does. Its SIREN is one for every establishment and passes Luhn, so the
    // broken value is measured whole: the SIREN in it is rightly offered, and
    // the fourteen digits are not a SIRET.
    let poste = found_in("fr", "Bureau 356 000 000 00010 à Lyon.");
    let it = the(&poste, "356 000 000 00010").unwrap_or_else(|| panic!("La Poste's SIRET: {}", show(&poste)));
    assert_eq!((it.kind, it.state), (TaxId, Protected));
    let broken = found_in("fr", "Bureau 356 000 000 00011 à Lyon.");
    assert!(the(&broken, "356 000 000 00011").is_none(), "a SIRET whose digit sum fails was found: {}", show(&broken));
    let siren = the(&broken, "356 000 000").expect("the SIREN inside it");
    assert_eq!((siren.kind, siren.state), (TaxId, Suggested));
    // VAT — the key is checked against the SIREN.
    row("fr", "TVA : FR26512479361", "FR26512479361", TaxId, Protected, "FR27512479361");
    row("fr", "TVA : FR 26 512479361", "FR 26 512479361", TaxId, Protected, "FR 26 512479362");
}

/// **The numéro fiscal has no public check**, so it is a shape and a label:
/// protected after the words that name it, offered without them, and nothing
/// at all when its first digit is not 0–3.
#[test]
fn a_french_tax_number_has_no_check_and_is_offered_without_its_label() {
    let _g = serial();
    let _ground = Ground::fresh("fr-spi");
    let labelled = found_in("fr", "Numéro fiscal : 24 17 593 820 416");
    let it = the(&labelled, "24 17 593 820 416").expect("the labelled numéro fiscal");
    assert_eq!((it.kind, it.state), (Kind::TaxId, MarkState::Protected), "{}", show(&labelled));

    let plain = found_in("fr", "Référence 2417593820416 du dossier.");
    let it = the(&plain, "2417593820416").expect("the plain numéro fiscal");
    assert_eq!((it.kind, it.state), (Kind::TaxId, MarkState::Suggested), "{}", show(&plain));

    let not = found_in("fr", "Référence 5417593820416 du dossier.");
    assert!(not.is_empty(), "thirteen digits starting 5 are no numéro fiscal: {}", show(&not));
}

/// **A French telephone number is the pack's when its shape is France's**: the
/// general rule already protects any `+…` number, and the pack agrees with it
/// only when what follows +33 is a French number.
#[test]
fn a_french_telephone_number_is_read_by_the_pack_only_in_its_own_shape() {
    let _g = serial();
    let _ground = Ground::fresh("fr-phone");
    let good = found_in("fr", "Tél. +33 4 72 18 39 50");
    let it = the(&good, "+33 4 72 18 39 50").expect("the number");
    assert_eq!((it.kind, it.state), (Kind::Phone, MarkState::Protected));
    assert!(it.reason.contains("fr:phone"), "the French pack did not agree: {}", it.reason);

    // In five pairs, the way France writes a number: protected by the pack,
    // where the general rule alone only offers a local number.
    let pairs = found_in("fr", "Appelez le 04 72 18 39 51 demain.");
    let it = the(&pairs, "04 72 18 39 51").expect("the number in pairs");
    assert_eq!((it.kind, it.state, it.source), (Kind::Phone, MarkState::Protected, Source::LanguagePack));
    // «00» opens no French number; the general rule's own question is all
    // that is left of it, exactly as before this paper.
    let zeros = found_in("fr", "Appelez le 00 72 18 39 51 demain.");
    let it = the(&zeros, "00 72 18 39 51").expect("the general rule's question");
    assert_eq!((it.state, it.source), (MarkState::Suggested, Source::GeneralRule), "{}", it.reason);

    let off = found_in("fr", "Tél. +33 0 72 18 39 50");
    assert!(off.iter().all(|f| !f.reason.contains("fr:phone") && !f.reason.contains("French telephone")), "+33 then 0 is no French number: {}", off.iter().map(|f| f.reason.as_str()).collect::<Vec<_>>().join(" | "));
}

/// **Every Spanish row of the table is found when its check comes out**, and
/// not when one character of it is changed.
#[test]
fn every_spanish_number_is_found_by_its_check_and_not_one_digit_off() {
    let _g = serial();
    let _ground = Ground::fresh("es-rows");
    use Kind::*;
    use MarkState::*;
    row("es", "Con DNI 47392815G, vecino de Madrid.", "47392815G", IdCard, Protected, "47392816G");
    row("es", "Con DNI 47392815-G.", "47392815-G", IdCard, Protected, "47392815-H");
    row("es", "Titular del NIE Y4827361C.", "Y4827361C", IdCard, Protected, "Y4827362C");
    // A CIF whose control is a digit, and one whose control must be a letter.
    row("es", "Empresa con CIF B64819378.", "B64819378", TaxId, Protected, "B64819379");
    row("es", "Entidad con CIF Q2826004J.", "Q2826004J", TaxId, Protected, "Q2826004A");
    row("es", "NIF-IVA: ESB64819378", "ESB64819378", TaxId, Protected, "ESB64819478");
    row("es", "NIF-IVA: ES47392815G", "ES47392815G", TaxId, Protected, "ES47392815Z");
    // Seguridad Social — and the published exception for a middle number
    // below 10 000 000.
    row("es", "Afiliación 28/51739246/65 en vigor.", "28/51739246/65", SocialInsuranceNo, Protected, "28/51739246/66");
    row("es", "Afiliación 08 01234567 74 en vigor.", "08 01234567 74", SocialInsuranceNo, Protected, "08 01234567 75");
}

/// **A Spanish telephone number is the pack's when what follows +34 starts 6,
/// 7, 8 or 9.**
#[test]
fn a_spanish_telephone_number_is_read_by_the_pack_only_in_its_own_shape() {
    let _g = serial();
    let _ground = Ground::fresh("es-phone");
    let good = found_in("es", "Teléfono: +34 691 284 735");
    let it = the(&good, "+34 691 284 735").expect("the number");
    assert_eq!((it.kind, it.state), (Kind::Phone, MarkState::Protected));
    assert!(it.reason.contains("es:phone"), "the Spanish pack did not agree: {}", it.reason);

    let off = found_in("es", "Teléfono: +34 591 284 735");
    assert!(off.iter().all(|f| !f.reason.contains("es:phone") && !f.reason.contains("Spanish telephone")), "+34 then 5 is no Spanish number");
}

/// **Twelve digits in one piece are offered, not protected**: the check comes
/// out for one ordinary number in ninety-seven.
#[test]
fn a_social_security_number_in_one_piece_is_offered() {
    let _g = serial();
    let _ground = Ground::fresh("es-ss-plain");
    let plain = found_in("es", "Referencia 285173924665 del expediente.");
    let it = the(&plain, "285173924665").expect("the number");
    assert_eq!((it.kind, it.state), (Kind::SocialInsuranceNo, MarkState::Suggested), "{}", show(&plain));
}

// ------------------------------------------------ 2 · postal codes and IBAN

/// **A postal code is not found, and an IBAN is found by the general rule as
/// before** — in both languages.
#[test]
fn a_postal_code_is_not_found_and_an_iban_is_the_general_rules() {
    let _g = serial();
    let _ground = Ground::fresh("postal");
    for (pack, line, postal, iban) in [
        ("fr", "69002 Lyon — compte FR76 3000 6000 0112 3456 7890 189", "69002", "FR76 3000 6000 0112 3456 7890 189"),
        ("es", "28013 Madrid — cuenta ES91 2100 0418 4502 0005 1332", "28013", "ES91 2100 0418 4502 0005 1332"),
    ] {
        let found = found_in(pack, line);
        assert!(found.iter().all(|f| !f.text.contains(postal)), "a postal code was found under «{pack}»: {}", show(&found));
        let it = the(&found, iban).unwrap_or_else(|| panic!("the IBAN was lost under «{pack}»: {}", show(&found)));
        assert_eq!((it.kind, it.source, it.state), (Kind::Iban, Source::GeneralRule, MarkState::Protected));
    }
}

// ------------------------------------------------------------- 3 · 4 · names

/// **«Madame Dupont», «Juan García», «Sra. López» are offered as people**, and
/// the title stays in the clear.
#[test]
fn a_name_by_its_shape_is_offered_as_a_person() {
    let _g = serial();
    let _ground = Ground::fresh("names");
    for (pack, line, names) in [
        ("fr", "Nous avons reçu la lettre de Madame Dupont hier.", &["Dupont"][..]),
        ("es", "Hemos hablado con Juan García esta mañana.", &["Juan", "García"][..]),
        ("es", "Hemos recibido la carta de la Sra. López ayer.", &["López"][..]),
    ] {
        let found = found_in(pack, line);
        for name in names {
            let it = the(&found, name).unwrap_or_else(|| panic!("«{name}» was not offered in «{line}»: {}", show(&found)));
            assert_eq!((it.kind, it.state), (Kind::Person, MarkState::Suggested), "«{name}»");
        }
        assert!(
            found.iter().all(|f| !f.text.contains("Madame") && !f.text.contains("Sra")),
            "a title was taken for a name: {}",
            show(&found)
        );
    }
}

/// **A capital that opens a sentence is no name, and a month or a nationality
/// is written small** — «Le», «Lundi», «janvier», «français» find nothing.
#[test]
fn a_word_that_opens_a_sentence_or_names_a_month_is_no_name() {
    let _g = serial();
    let _ground = Ground::fresh("not-names");
    for (pack, line) in [
        ("fr", "Le Dossier est complet."),
        ("fr", "Lundi Prochain, nous verrons."),
        ("fr", "Le dossier arrivé en janvier est rédigé en français."),
        ("fr", "Lundi prochain, rien ne change."),
        ("es", "El Expediente está completo."),
        ("es", "Lunes Próximo, veremos."),
        ("es", "El expediente llegó en enero y está escrito en español."),
        ("fr", "Notre client Atelier Moreau SARL a payé."),
    ] {
        let found = found_in(pack, line);
        assert!(
            found.iter().all(|f| f.kind != Kind::Person),
            "«{line}» offered a person: {}",
            show(&found)
        );
    }
}

/// **Nothing these packs say about a person is ever protected alone** — not by
/// the shape, not by a title, not on either letter.
#[test]
fn no_name_in_these_packs_is_ever_protected_alone() {
    let _g = serial();
    let _ground = Ground::fresh("never-auto");
    for (pack, text) in [
        ("fr", FR1),
        ("es", ES1),
        ("fr", "Monsieur Jean Martin, Docteur Paul Petit, Maître Anne Leroy et Mme Durand."),
        ("es", "Señor Pedro Ruiz, Doctora Elena Sanz, D. Luis Gil y Dña. Rosa Vidal."),
    ] {
        let found = found_in(pack, text);
        let people: Vec<&Found> = found.iter().filter(|f| f.kind == Kind::Person).collect();
        assert!(!people.is_empty(), "no person at all under «{pack}» — this guard measures nothing");
        for p in people {
            assert_eq!(p.state, MarkState::Suggested, "«{}» was protected alone under «{pack}»: {}", p.text, p.reason);
        }
    }
}

// --------------------------------------------------------------- 5 · vault

/// **A French name the person accepts is kept in the vault, and the next
/// document protects it** — by the library path every accepted name already
/// takes; nothing new was built for it.
#[test]
fn an_accepted_french_name_is_protected_in_the_next_document() {
    let _g = serial();
    let _ground = Ground::fresh("vault");
    vault_create_with_passphrase(PASS.to_string()).expect("vault");

    let first = "Nous avons reçu la lettre de Madame Dupont hier.";
    let s = open_session(None, "fr".to_string()).expect("open");
    import_text(s, first.to_string()).expect("import");
    scan(s).expect("scan");
    let units: Vec<u16> = first.encode_utf16().collect();
    let offered = list_findings(s)
        .expect("findings")
        .into_iter()
        .find(|f| String::from_utf16_lossy(&units[f.span.start as usize..f.span.end as usize]) == "Dupont")
        .expect("«Dupont» is offered");
    assert_eq!(offered.state, MarkState::Suggested);
    answer_finding(s, offered.id, FindingAnswer::Protect).expect("accept");
    close_session(s).expect("close");

    let later = "Dupont a rappelé ce matin.";
    let found = found_in("fr", later);
    let it = the(&found, "Dupont").unwrap_or_else(|| panic!("the accepted name was not found: {}", show(&found)));
    assert_eq!((it.source, it.state), (Source::Vault, MarkState::Protected), "{}", it.reason);
}

// ---------------------------------------------------------- the two letters

/// **The two letters, counted** — the numbers the head of this file states.
#[test]
fn the_two_letters_are_counted() {
    let _g = serial();
    let _ground = Ground::fresh("letters");
    assert_eq!(counts("fr", FR1), (7, 9), "FR-1: {}", show(&found_in("fr", FR1)));
    assert_eq!(counts("es", ES1), (7, 9), "ES-1: {}", show(&found_in("es", ES1)));
}

/// **The French and Spanish rules run only when asked for**: the same letter
/// under German finds none of their numbers.
#[test]
fn the_french_and_spanish_rules_run_only_when_asked_for() {
    let _g = serial();
    let _ground = Ground::fresh("only-when-asked");
    let found = found_in("de", ES1);
    assert!(found.iter().all(|f| f.kind != Kind::IdCard), "a DNI was read under German: {}", show(&found));
    let found = found_in("de", FR1);
    assert!(
        found.iter().all(|f| f.kind != Kind::SocialInsuranceNo),
        "a NIR was read under German: {}",
        show(&found)
    );
}

// ----------------------------------------------- 6 · the other four, as they were

/// **English, German, Swedish and Arabic count what they counted before this
/// paper** — measured on 01bb6b6 with this same function, and the engine half
/// of paper 120 is behind a pack field the four leave at `false`.
#[test]
fn the_other_four_languages_count_what_they_counted() {
    let _g = serial();
    let _ground = Ground::fresh("other-four");
    for (pack, file, text, before) in [
        ("de", "Brief_Weber", include_str!("fixtures/Brief_Weber.txt"), BEFORE_DE),
        ("sv", "Brev_Lindqvist", include_str!("fixtures/Brev_Lindqvist.txt"), BEFORE_SV),
        ("en", "Grievance_Whitaker", include_str!("fixtures/Grievance_Whitaker.txt"), BEFORE_EN),
        ("ar", "Risala_Alharbi", include_str!("fixtures/Risala_Alharbi.txt"), BEFORE_AR),
    ] {
        assert_eq!(counts(pack, text), before, "{file} under «{pack}» moved");
    }
}

const BEFORE_DE: (u32, u32) = (29, 8);
const BEFORE_SV: (u32, u32) = (14, 6);
const BEFORE_EN: (u32, u32) = (13, 7);
const BEFORE_AR: (u32, u32) = (19, 5);
