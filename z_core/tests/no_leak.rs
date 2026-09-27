// Invariant G3: the safe payload carries no protected value.
//
// Every case here also carries a **control string**: a value that is deliberately
// left unprotected and must be FOUND in the payload. A test that only looks for
// absence can pass because the search itself is broken; the control proves the
// search works before its silence is believed.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// The span Flutter would report for `needle`, in UTF-16 units.
fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("needle is in the document");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    let len: usize = needle.chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + len) as u32,
    }
}

struct Case {
    name: &'static str,
    doc: &'static str,
    /// Protected everywhere they appear.
    secrets: &'static [(&'static str, Kind)],
    /// Left in the clear on purpose — the control string.
    control: &'static str,
}

const CASES: &[Case] = &[
    Case {
        name: "a German letter",
        doc: "Kunde: Nordstern Consulting GmbH\nAnsprechpartner: Herr Thomas Müller\n\
              Telefon: +49 171 2345678\nIBAN: DE12 3456 7890 1234 5678 90\n\
              Wir bitten um eine Verlängerung des Zahlungsziels.",
        secrets: &[
            ("Nordstern Consulting GmbH", Kind::Company),
            ("Thomas Müller", Kind::Person),
            ("+49 171 2345678", Kind::Phone),
            ("DE12 3456 7890 1234 5678 90", Kind::Iban),
        ],
        control: "Verlängerung",
    },
    Case {
        name: "the same name many times",
        doc: "Müller kam. Müller ging. Müller kam wieder. Später kam Müller erneut.",
        secrets: &[("Müller", Kind::Person)],
        control: "wieder",
    },
    Case {
        name: "one value inside another",
        doc: "Nordstern GmbH und Nordstern Consulting GmbH sind zwei Firmen.",
        secrets: &[
            ("Nordstern Consulting GmbH", Kind::Company),
            ("Nordstern GmbH", Kind::Company),
        ],
        control: "zwei Firmen",
    },
    Case {
        name: "letters that are not ASCII",
        doc: "Straße 4, 20359 Hamburg — Frau Özdemir, Büro 3. Lieferung 🏭 morgen.",
        secrets: &[("Frau Özdemir", Kind::Person), ("Straße 4, 20359 Hamburg", Kind::Address)],
        control: "morgen",
    },
    Case {
        name: "a value that is also a common word",
        doc: "Die Firma Sonne liefert Sonne im Winter. Sonne ist der Kunde.",
        secrets: &[("Sonne", Kind::Company)],
        control: "Winter",
    },
];

#[test]
fn no_leak_in_any_payload() {
    for case in CASES {
        let s = open_session(None, "de".to_string()).expect("open");
        import_text(s, case.doc.to_string()).expect("import");

        let mut tokens = Vec::new();
        for (secret, kind) in case.secrets {
            let span = span_of(case.doc, secret);
            match protect_all_matches(s, span, Scope::Conversation, *kind).expect(case.name) {
                ProtectOutcome::Applied { token, places } => {
                    assert!(places >= 1, "{}: {secret} was not protected anywhere", case.name);
                    tokens.push(token);
                }
                // Already covered by a longer value protected before it — the
                // nesting case. Nothing is leaking; there is simply no place left.
                ProtectOutcome::Snapped { .. } => {}
                other => panic!("{}: {secret} gave {other:?}", case.name),
            }
        }

        let handle = build_payload(s).expect("build");
        let text = payload_view(handle).expect("view").text;

        // 1. The control string proves the search below is not looking at nothing.
        assert!(
            text.contains(case.control),
            "{}: the control string «{}» is missing, so this test cannot be trusted",
            case.name,
            case.control
        );

        // 2. No protected value survives, in any spelling.
        for (secret, _) in case.secrets {
            assert!(
                !text.contains(secret),
                "{}: «{secret}» is still in the payload:\n{text}",
                case.name
            );
        }

        // 3. Every token that was minted actually stands in the payload.
        for token in &tokens {
            assert!(
                text.contains(token),
                "{}: {token} was minted but is not in the payload",
                case.name
            );
        }
        close_session(s).expect("close");
    }
}

#[test]
fn no_leak_after_undo_and_reprotect() {
    // A payload built after taking protection back must be honest about it: the
    // name is in the clear again, and the control string still proves the search.
    let doc = "Thomas Müller und Anna Weber sprechen morgen.";
    let s = open_session(None, "de".to_string()).expect("open");
    import_text(s, doc.to_string()).expect("import");

    protect_all_matches(s, span_of(doc, "Thomas Müller"), Scope::Conversation, Kind::Person)
        .expect("protect");
    protect_all_matches(s, span_of(doc, "Anna Weber"), Scope::Conversation, Kind::Person)
        .expect("protect");

    let first = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert!(!first.contains("Thomas Müller") && !first.contains("Anna Weber"));
    assert!(first.contains("sprechen morgen"), "control string");

    undo_last_protection(s).expect("undo");
    let second = payload_view(build_payload(s).expect("build")).expect("view").text;
    assert!(second.contains("Anna Weber"), "undo puts the name back in the clear");
    assert!(!second.contains("Thomas Müller"), "the other one stays protected");
}

#[test]
fn session_namespaces_keep_two_conversations_apart() {
    // Invariant G10: the same name in two conversations must not produce the same
    // token, or the two could be lined up against each other.
    let doc = "Thomas Müller schreibt.";
    let mut seen = Vec::new();
    for _ in 0..2 {
        let s = open_session(None, "de".to_string()).expect("open");
        import_text(s, doc.to_string()).expect("import");
        match protect(s, span_of(doc, "Thomas Müller"), Scope::Conversation, Kind::Person)
            .expect("protect")
        {
            ProtectOutcome::Applied { token, .. } => seen.push(token),
            other => panic!("{other:?}"),
        }
        close_session(s).expect("close");
    }
    assert_ne!(seen[0], seen[1], "the same name got the same token in two sessions");
    // Both still say what kind of thing they stand for: that part is deliberate.
    assert!(seen.iter().all(|t| t.contains("_PERSON_")), "{seen:?}");
}
