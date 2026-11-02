//! French — the numbers that matter, and names by their shape (paper 120).
//!
//! The owner's ruling of 2 November 2026: «a pack needs no French or Spanish
//! names; what it needs is everything about the numbers — only the shapes of
//! the numbers that matter — and the names vault is a later update». So this
//! pack carries **no name list**. Its people come from the shared engine in
//! `people.rs`, reading only what that engine asks of a language: the words
//! that open a sentence and are no name, and the titles. Every person it finds
//! is **Suggested**, never protected alone (`names_by_shape`), and one the
//! person accepts is kept in Z's vault the way every accepted name is.
//!
//! **The numbers, and why each is `Auto` or `Suggest`.** The discipline is the
//! other packs': a value whose check passes *and* whose shape cannot be an
//! ordinary number is `Auto`; anything weaker asks. A failed check is never a
//! find.
//!
//! ```text
//!  NIR              13 digits + key 97 − (n mod 97); 2A/2B count as 19/18
//!                   grouped 1·2·2·2·3·3·2 or 13·2, or labelled   → Auto
//!                   fifteen digits in one piece, no label        → Suggest
//!  SIRET            14 digits, Luhn — or La Poste's: SIREN 356000000 and
//!                   the digit sum a multiple of 5
//!                   grouped 3·3·3·5 or 9·5, or labelled «SIRET»  → Auto
//!                   fourteen digits in one piece, no label       → Suggest
//!  SIREN            9 digits, Luhn
//!                   after «SIREN», «SIRET» or «RCS»              → Auto
//!                   otherwise (one 9-digit number in ten passes) → Suggest
//!  VAT              FR + key + SIREN, key = (12 + 3 · (SIREN mod 97)) mod 97
//!                   a numeric key that comes out                 → Auto
//!                   a key with a letter in it: the rule for it is
//!                   not public, so only the SIREN's Luhn is read → Suggest
//!  numéro fiscal    13 digits starting 0–3, in one piece or 2·2·3·3·3 — no
//!                   public check exists
//!                   after «fiscal» or «SPI»                      → Auto
//!                   otherwise                                    → Suggest
//!  telephone        +33 then 1–9 and eight digits                → Auto
//!                   0 then 1–9 and eight digits in five pairs    → Auto
//!                   ten digits in one piece                      → Suggest
//! ```
//!
//! **Not here, on purpose.** A postal code: five digits, which would protect
//! every ordinary number of five digits. An IBAN and a BIC: the general rules
//! read every country's. A SIRET can be fourteen digits that a Diners Club card
//! also is (prefix 36, 38, 39 or 300–305, Luhn); where both read a plain run,
//! the card rule's `Auto` keeps the finding and the value is protected either
//! way.

use super::numbers::{digits, luhn_ok, mod97, read_runs, Run, Verdict};
use super::pack::{LanguagePack, NameOrder, Word};
use crate::api::Kind;
use crate::scanner::{Candidate, Confidence};

/// «Madame Dupont», «M. Martin», «Maître Lefèvre» — the paper's list, and the
/// only form words this pack knows. A title stays in the clear; the name after
/// it is offered.
const TITLES: &[&str] = &[
    "Monsieur", "Madame", "Mademoiselle", "M.", "Mme", "Mme.", "Mlle", "Mlle.", "Maître", "Me", "Docteur",
    "Dr", "Dr.",
];

/// The words that open a French sentence with a capital and are no name:
/// articles, pronouns, determiners, the prepositions and conjunctions a
/// sentence starts with, what a letter opens and closes with, and the days and
/// months — which French writes in lower case inside a sentence and with a
/// capital only at its start.
const STOP_WORDS: &[&str] = &[
    "Le", "La", "Les", "Ce", "Cet", "Cette", "Ces", "Un", "Une", "Des", "Du", "De", "Il", "Elle",
    "Ils", "Elles", "Nous", "Vous", "Je", "On", "Mon", "Ma", "Mes", "Ton", "Ta", "Tes", "Son", "Sa",
    "Ses", "Notre", "Nos", "Votre", "Vos", "Leur", "Leurs", "Au", "Aux", "À", "Dans", "Pour", "Par", "Avec",
    "Sans", "Sur", "Sous", "Selon", "Chez", "Entre", "Depuis", "Après", "Avant", "Pendant", "Et", "Mais",
    "Ou", "Donc", "Or", "Ni", "Car", "Si", "Comme", "Quand", "Qui", "Que", "Quoi", "Tout", "Tous",
    "Toute", "Toutes", "Bonjour", "Bonsoir", "Merci", "Cher", "Chère", "Chers", "Chères", "Objet",
    "Veuillez", "Cordialement", "Lundi", "Mardi", "Mercredi", "Jeudi", "Vendredi", "Samedi", "Dimanche",
    "Janvier", "Février", "Mars", "Avril", "Mai", "Juin", "Juillet", "Août", "Septembre", "Octobre",
    "Novembre", "Décembre",
];

/// The same words inside a sentence, where they are written small.
const FUNCTION_WORDS: &[&str] = &[
    "le", "la", "les", "de", "du", "des", "et", "ou", "à", "au", "aux", "en", "pour", "par", "avec", "sur",
];

/// The legal forms a French company name ends with: «Atelier Moreau SARL» is a
/// company, and its words are no person's.
const COMPANY_FORMS: &[&str] = &["SA", "SAS", "SASU", "SARL", "EURL", "SCI", "SNC"];

pub(crate) fn pack() -> LanguagePack {
    LanguagePack {
        locale: "fr-FR",
        id: "fr",
        label: "Français (FR)",
        in_english: "French",
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
        provenance: "No name list: names are offered by their shape only (paper 120); a French names vault is a later update",
        names_by_shape: true,
        extra: &[
            ("social insurance numbers (NIR)", nir),
            ("company numbers (SIREN, SIRET)", siren_and_siret),
            ("VAT numbers", vat),
            ("tax numbers (numéro fiscal)", numero_fiscal),
            ("telephone numbers", phones),
        ],
    }
}

fn verdict(kind: Kind, sure: bool, rule: &'static str, reason: &str) -> Option<Verdict> {
    Some(Verdict {
        kind,
        confidence: if sure { Confidence::Auto } else { Confidence::Suggest },
        rule,
        reason: if sure {
            reason.to_string()
        } else {
            format!("{reason} — but written this way an ordinary number can look the same, so your word decides")
        },
    })
}

// --------------------------------------------------------------------- NIR

/// Does this compact NIR's key come out?
pub(crate) fn nir_ok(compact: &str) -> bool {
    let b = compact.as_bytes();
    if b.len() != 15 || !matches!(b.first(), Some(b'1' | b'2' | b'3' | b'4' | b'7' | b'8')) {
        return false;
    }
    // Corsica: the department is «2A» or «2B», and the key is computed with
    // 19 or 18 in its place (the published rule).
    let department = compact.get(5..7).unwrap_or_default();
    let number = match department {
        "2A" => format!("{}19{}", compact.get(..5).unwrap_or_default(), compact.get(7..13).unwrap_or_default()),
        "2B" => format!("{}18{}", compact.get(..5).unwrap_or_default(), compact.get(7..13).unwrap_or_default()),
        _ => compact.get(..13).unwrap_or_default().to_string(),
    };
    let key = compact.get(13..15).unwrap_or_default();
    if !digits(&number, 13) || !digits(key, 2) {
        return false;
    }
    let Some(rest) = mod97(&number) else { return false };
    key.parse::<u32>().is_ok_and(|k| k == 97 - rest)
}

fn nir(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        if !nir_ok(&run.compact) {
            return None;
        }
        let sure = run.grouped(&[&[1, 2, 2, 2, 3, 3, 2], &[13, 2]])
            || run.labelled(&["nir", "sécurité", "sociale", "insee", "sécu"]);
        verdict(
            Kind::SocialInsuranceNo,
            sure,
            "nir",
            "a French social insurance number (NIR): thirteen digits and a key that comes out",
        )
    });
}

// ----------------------------------------------------------- SIREN · SIRET

/// La Poste's establishments share one SIREN and their SIRET does not pass
/// Luhn; the published exception is the sum of its digits, a multiple of five.
pub(crate) fn siret_ok(compact: &str) -> bool {
    digits(compact, 14)
        && (luhn_ok(compact)
            || (compact.starts_with("356000000")
                && compact.bytes().map(|b| u32::from(b - b'0')).sum::<u32>().is_multiple_of(5)))
}

fn siren_and_siret(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        if siret_ok(&run.compact) {
            let sure = run.grouped(&[&[3, 3, 3, 5], &[9, 5]]) || run.labelled(&["siret"]);
            return verdict(
                Kind::TaxId,
                sure,
                "siret",
                "a French establishment number (SIRET): fourteen digits that pass their check",
            );
        }
        if digits(&run.compact, 9) && luhn_ok(&run.compact) && run.grouped(&[&[3, 3, 3], &[9]]) {
            let sure = run.labelled(&["siren", "siret", "rcs"]);
            return verdict(
                Kind::TaxId,
                sure,
                "siren",
                "a French company number (SIREN): nine digits that pass their check",
            );
        }
        None
    });
}

// --------------------------------------------------------------------- VAT

fn vat(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        let c = run.compact.as_str();
        let (Some("FR"), Some(key), Some(siren)) = (c.get(..2), c.get(2..4), c.get(4..)) else { return None };
        if !digits(siren, 9) {
            return None;
        }
        if digits(key, 2) {
            let wanted = (12 + 3 * mod97(siren)?) % 97;
            return (key.parse::<u32>().ok()? == wanted).then(|| Verdict {
                kind: Kind::TaxId,
                confidence: Confidence::Auto,
                rule: "vat",
                reason: "a French VAT number: FR, a key and a SIREN, and the key comes out".to_string(),
            });
        }
        // A key with a letter: the rule that computes it is not published, so
        // the SIREN's own check is all that can be read.
        let lettered = key.chars().all(|ch| ch.is_ascii_uppercase() || ch.is_ascii_digit());
        (lettered && luhn_ok(siren)).then(|| Verdict {
            kind: Kind::TaxId,
            confidence: Confidence::Suggest,
            rule: "vat",
            reason: "a French VAT number with a lettered key — its SIREN passes the check, and the key's own rule \
                     is not published, so your word decides"
                .to_string(),
        })
    });
}

// ----------------------------------------------------------- numéro fiscal

fn numero_fiscal(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        let starts = run.compact.bytes().next().is_some_and(|b| (b'0'..=b'3').contains(&b));
        if !(digits(&run.compact, 13) && starts && run.grouped(&[&[13], &[2, 2, 3, 3, 3]])) {
            return None;
        }
        let sure = run.labelled(&["fiscal", "spi"]);
        Some(Verdict {
            kind: Kind::TaxId,
            confidence: if sure { Confidence::Auto } else { Confidence::Suggest },
            rule: "numero-fiscal",
            reason: if sure {
                "a French tax number (numéro fiscal), after the words that name it".to_string()
            } else {
                "thirteen digits shaped like a French tax number (numéro fiscal) — it has no public check, so \
                 your word decides"
                    .to_string()
            },
        })
    });
}

// --------------------------------------------------------------- telephone

fn phones(words: &[Word<'_>], out: &mut Vec<Candidate>) {
    read_runs(words, &pack(), out, &|run: &Run| {
        let c = run.compact.as_str();
        let nine = |rest: &str| digits(rest, 9) && !rest.starts_with('0');
        if let Some(rest) = c.strip_prefix("+33") {
            return nine(rest).then(|| Verdict {
                kind: Kind::Phone,
                confidence: Confidence::Auto,
                rule: "phone",
                reason: "a French telephone number in international form (+33)".to_string(),
            });
        }
        let rest = c.strip_prefix('0')?;
        if !nine(rest) || !run.grouped(&[&[2, 2, 2, 2, 2], &[10]]) {
            return None;
        }
        if run.grouped(&[&[2, 2, 2, 2, 2]]) {
            verdict(Kind::Phone, true, "phone", "a French telephone number, written in five pairs the way France writes one")
        } else {
            verdict(Kind::Phone, false, "phone", "ten digits shaped like a French telephone number")
        }
    });
}
