//! Spanish — the numbers that matter, and names by their shape (paper 120).
//!
//! The same ruling as `fr.rs`, and the same shape: **no name list**, people
//! from the shared engine in `people.rs` with only what it asks of a language
//! (the words that open a sentence and are no name, and the titles), and every
//! person **Suggested** (`names_by_shape`).
//!
//! **The numbers, and why each is `Auto` or `Suggest`.** A value whose check
//! passes *and* whose shape cannot be an ordinary number is `Auto`; anything
//! weaker asks. A failed check is never a find. Three of the six carry a
//! letter that their own arithmetic computes, which no ordinary number does,
//! so those are `Auto` however they are grouped.
//!
//! ```text
//!  DNI                 8 digits + letter, TRWAGMYFPDXBNJZSQVHLCKE[n mod 23]  → Auto
//!  NIE                 X/Y/Z (as 0/1/2) + 7 digits + the same letter          → Auto
//!  CIF / NIF company   a letter of ABCDEFGHJNPQRSUVW + 7 digits + control:
//!                      odd places doubled and their digits summed, even
//!                      places added, c = (10 − sum mod 10) mod 10; written
//!                      as c, or as JABCDEFGHI[c] — a letter only after
//!                      K P Q R S N W, a digit only after A B E H              → Auto
//!  VAT                 ES + a DNI, NIE or CIF that passes as above            → Auto
//!  Seguridad Social    12 digits: province 01–53, then 8, then 2 that are
//!                      (first ten mod 97) — when the middle eight are below
//!                      10 000 000 the published rule reads province · 10⁷
//!                      + middle instead
//!                      grouped 2·8·2, or labelled                             → Auto
//!                      twelve digits in one piece, no label                   → Suggest
//!  telephone           +34 then 6, 7, 8 or 9 and eight digits                 → Auto
//! ```
//!
//! **Not here, on purpose.** A postal code (five digits); an IBAN or a BIC (the
//! general rules read every country's); a Spanish number written without its
//! `+34` (nine digits starting 6–9 are also how an amount or a reference is
//! written — the table this pack answers to names only the international
//! form).

use super::numbers::{digits, mod97, read_runs, Run, Verdict};
use super::pack::{LanguagePack, NameOrder, Word};
use crate::api::Kind;
use crate::scanner::{Candidate, Confidence};

/// «Sra. López», «D. Juan García», «Doctora Ruiz» — the paper's list.
const TITLES: &[&str] = &[
    "Señor", "Señora", "Señorita", "Sr.", "Sr", "Sra.", "Sra", "Srta.", "Srta", "Don", "Doña", "D.", "Dña.",
    "Doctor", "Doctora", "Dr.", "Dra.",
];

/// The words that open a Spanish sentence with a capital and are no name —
/// articles, pronouns, determiners, the prepositions and conjunctions a
/// sentence starts with, what a letter opens with, and the days and months,
/// which Spanish writes in lower case inside a sentence.
const STOP_WORDS: &[&str] = &[
    "El", "La", "Los", "Las", "Lo", "Este", "Esta", "Esto", "Estos", "Estas", "Ese", "Esa", "Eso", "Esos",
    "Esas", "Aquel", "Aquella", "Un", "Una", "Unos", "Unas", "Yo", "Tú", "Él", "Ella", "Nosotros",
    "Nosotras", "Vosotros", "Vosotras", "Ellos", "Ellas", "Usted", "Ustedes", "Mi", "Mis", "Tu", "Tus",
    "Su", "Sus", "Nuestro", "Nuestra", "Nuestros", "Nuestras", "Al", "Del", "De", "En", "Con", "Por",
    "Para", "Sin", "Sobre", "Según", "Desde", "Hasta", "Entre", "Tras", "Y", "E", "Pero", "O", "U", "Si",
    "Como", "Cuando", "Que", "Quien", "Todo", "Toda", "Todos", "Todas", "Hola", "Gracias", "Estimado",
    "Estimada", "Estimados", "Querido", "Querida", "Atentamente", "Asunto", "Lunes", "Martes", "Miércoles",
    "Jueves", "Viernes", "Sábado", "Domingo", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Setiembre", "Octubre", "Noviembre", "Diciembre",
];

/// The same words inside a sentence, where they are written small.
const FUNCTION_WORDS: &[&str] = &[
    "el", "la", "los", "las", "de", "del", "y", "e", "o", "u", "a", "al", "en", "con", "por", "para",
];

/// The legal forms a Spanish company name ends with.
const COMPANY_FORMS: &[&str] = &["S.A.", "S.L.", "S.L.U.", "S.A.U.", "SA", "SL", "SLU", "SAU"];

pub(crate) fn pack() -> LanguagePack {
    LanguagePack {
        locale: "es-ES",
        id: "es",
        label: "Español (ES)",
        in_english: "Spanish",
        version: "1",
        salutations: &[],
        greetings: &[],
        titles: TITLES,
        title_parts: &[],
        degrees: &[],
        function_words: FUNCTION_WORDS,
        stop_words: STOP_WORDS,
        closings: &[],
        roles: &[],
        copulas: &[],
        company_forms: COMPANY_FORMS,
        conjunctions: &[],
        family_suffixes: &[],
        order: NameOrder::GivenThenFamily,
        names: "",
        provenance: "No name list: names are offered by their shape only (paper 120); a Spanish names vault is a later update",
        names_by_shape: true,
        extra: &[
            ("identity numbers (DNI, NIE)", dni_and_nie),
            ("company tax numbers (CIF/NIF)", cif),
            ("VAT numbers", vat),
            ("social security numbers (Seguridad Social)", seguridad_social),
            ("telephone numbers", phones),
        ],
    }
}

const LETTERS: &[u8; 23] = b"TRWAGMYFPDXBNJZSQVHLCKE";

/// The letter of a DNI or a NIE, over its number.
fn control_letter(number: u32) -> Option<u8> {
    LETTERS.get((number % 23) as usize).copied()
}

pub(crate) fn dni_ok(compact: &str) -> bool {
    let (Some(number), Some(letter)) = (compact.get(..8), compact.get(8..)) else { return false };
    digits(number, 8)
        && letter.len() == 1
        && number.parse::<u32>().ok().and_then(control_letter).is_some_and(|l| letter.as_bytes() == [l])
}

pub(crate) fn nie_ok(compact: &str) -> bool {
    let (Some(lead), Some(number), Some(letter)) = (compact.get(..1), compact.get(1..8), compact.get(8..)) else {
        return false;
    };
    let worth = match lead {
        "X" => 0,
        "Y" => 1,
        "Z" => 2,
        _ => return false,
    };
    digits(number, 7)
        && letter.len() == 1
        && number
            .parse::<u32>()
            .ok()
            .and_then(|n| control_letter(worth * 10_000_000 + n))
            .is_some_and(|l| letter.as_bytes() == [l])
}

pub(crate) fn cif_ok(compact: &str) -> bool {
    let b = compact.as_bytes();
    let (Some(&lead), Some(body), Some(&control)) = (b.first(), b.get(1..8), b.get(8)) else { return false };
    if b.len() != 9 || !b"ABCDEFGHJNPQRSUVW".contains(&lead) || !body.iter().all(u8::is_ascii_digit) {
        return false;
    }
    let mut sum = 0u32;
    for (place, d) in body.iter().enumerate() {
        let d = u32::from(d - b'0');
        // Places 1, 3, 5, 7 (counted from one) are doubled.
        sum += if place % 2 == 0 { (d * 2) / 10 + (d * 2) % 10 } else { d };
    }
    let c = (10 - sum % 10) % 10;
    let as_digit = control == b'0' + c as u8;
    let as_letter = b"JABCDEFGHI".get(c as usize) == Some(&control);
    match lead {
        b'K' | b'P' | b'Q' | b'R' | b'S' | b'N' | b'W' => as_letter,
        b'A' | b'B' | b'E' | b'H' => as_digit,
        _ => as_digit || as_letter,
    }
}

fn sure(kind: Kind, rule: &'static str, reason: &str) -> Option<Verdict> {
    Some(Verdict { kind, confidence: Confidence::Auto, rule, reason: reason.to_string() })
}

fn dni_and_nie(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        if dni_ok(&run.compact) {
            return sure(Kind::IdCard, "dni", "a Spanish identity number (DNI): eight digits and the letter they compute");
        }
        if nie_ok(&run.compact) {
            return sure(
                Kind::IdCard,
                "nie",
                "a Spanish foreigner's identity number (NIE): X, Y or Z, seven digits and the letter they compute",
            );
        }
        None
    });
}

fn cif(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        cif_ok(&run.compact).then_some(())?;
        sure(Kind::TaxId, "cif", "a Spanish company tax number (CIF/NIF): a letter, seven digits and their control")
    });
}

fn vat(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        let rest = run.compact.strip_prefix("ES")?;
        (dni_ok(rest) || nie_ok(rest) || cif_ok(rest)).then_some(())?;
        sure(Kind::TaxId, "vat", "a Spanish VAT number: ES and a tax number whose own check comes out")
    });
}

pub(crate) fn seguridad_social_ok(compact: &str) -> bool {
    let (Some(province), Some(middle), Some(key)) = (compact.get(..2), compact.get(2..10), compact.get(10..)) else {
        return false;
    };
    if !(digits(province, 2) && digits(middle, 8) && digits(key, 2)) {
        return false;
    }
    let (Ok(p), Ok(m), Ok(k)) = (province.parse::<u64>(), middle.parse::<u64>(), key.parse::<u64>()) else {
        return false;
    };
    if !(1..=53).contains(&p) {
        return false;
    }
    let n = if m < 10_000_000 { p * 10_000_000 + m } else { p * 100_000_000 + m };
    mod97(&n.to_string()).is_some_and(|r| u64::from(r) == k)
}

fn seguridad_social(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        if !(digits(&run.compact, 12) && seguridad_social_ok(&run.compact)) {
            return None;
        }
        let grouped = run.grouped(&[&[2, 8, 2]]);
        let labelled = run.labelled(&["social", "nuss", "naf", "afiliación"]);
        if !grouped && !run.grouped(&[&[12]]) {
            return None;
        }
        let auto = grouped || labelled;
        Some(Verdict {
            kind: Kind::SocialInsuranceNo,
            confidence: if auto { Confidence::Auto } else { Confidence::Suggest },
            rule: "seguridad-social",
            reason: if auto {
                "a Spanish social security number: twelve digits whose last two are the check of the first ten"
                    .to_string()
            } else {
                "twelve digits whose last two are the check of the first ten, the shape of a Spanish social \
                 security number — but an ordinary number can pass it too, so your word decides"
                    .to_string()
            },
        })
    });
}

fn phones(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        let rest = run.compact.strip_prefix("+34")?;
        (digits(rest, 9) && rest.starts_with(['6', '7', '8', '9'])).then_some(())?;
        sure(Kind::Phone, "phone", "a Spanish telephone number in international form (+34)")
    });
}
