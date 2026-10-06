// 041-D · the names a person builds themselves.
//
// The owner is preparing Swedish and German lists for a demonstration. What he
// needs is small and must be exact: type a name in, read a file of them in, see
// what this device knows because he said so, and take one back.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use z_core::api::*;

/// One vault, and one test.
///
/// The core is one process-wide thing: a data directory, a vault, a lock. Two
/// `#[test]`s run in two threads and share all three, so a test that locks the
/// vault locks another test's vault — which is exactly what happened when this
/// file was six tests, and why the gateway's tests were made one journey
/// before it. The steps below are in the order a person would do them.
fn a_vault(name: &str) {
    let dir = std::env::temp_dir().join(format!("zprivacy-own-names-{name}-{}", std::process::id()));
    let _ = std::fs::remove_dir_all(&dir);
    set_data_dir(dir.to_string_lossy().to_string()).expect("data dir");
    vault_create_with_passphrase("ein gutes Passwort".to_string()).expect("vault");
}

#[test]
fn the_names_a_person_builds_themselves() {
    a_list_that_is_off_is_not_a_list_that_was_forgotten();
    a_list_is_imported_and_forgotten();
    a_word_goes_to_the_dictionary_and_a_company_to_the_vault();
    always_is_one_row_and_one_forget();
    a_list_comes_back_counted();
    a_file_without_a_type_column_is_refused_with_a_sentence();
    everything_here_needs_an_open_vault();
    a_semicolon_file_reads_the_same();
}

fn a_word_goes_to_the_dictionary_and_a_company_to_the_vault() {
    a_vault("one");
    let given = add_user_name("Anneli".to_string(), UserNameKind::Given, false, None, "de".to_string()).expect("given");
    let family = add_user_name("Lindqvist".to_string(), UserNameKind::Family, false, None, "de".to_string()).expect("family");
    add_user_name("Nordstern Consulting GmbH".to_string(), UserNameKind::Company, true, None, "de".to_string()).expect("company");

    let rows = user_names(None).expect("rows");
    assert_eq!(rows.len(), 3, "{rows:?}");

    let word = rows.iter().find(|r| r.text == "Lindqvist").expect("the family name");
    assert_eq!(word.kind, UserNameKind::Family);
    assert_eq!(word.entity_id, None, "a word was kept as a vault value");
    assert_eq!(word.id, family);
    assert!(!word.always, "a name taught as a suggestion is protected on sight");

    let company = rows.iter().find(|r| r.text == "Nordstern Consulting GmbH").expect("the company");
    assert_eq!(company.kind, UserNameKind::Company);
    assert!(company.entity_id.is_some(), "a company was kept as a word");
    assert!(company.always);

    // And the dictionary really has the word: the taught-name list is the same
    // store the packs sit beside.
    let taught = taught_names().expect("taught");
    assert_eq!(taught.len(), 2, "{taught:?}");
    assert!(taught.iter().any(|t| t.id == given && t.text == "Anneli" && !t.family));
}

/// One row on the screen is one name: a word taught as «always» is both a word
/// and a value, and one press takes the whole of it back.
fn always_is_one_row_and_one_forget() {
    a_vault("two");
    let id = add_user_name("Lindqvist".to_string(), UserNameKind::Family, true, None, "de".to_string()).expect("family");

    let rows = user_names(None).expect("rows");
    assert_eq!(rows.len(), 1, "an «always» word shows twice: {rows:?}");
    assert!(rows[0].always, "the row does not say it is always");
    assert_eq!(rows[0].entity_id, None);

    forget_user_name(id, None).expect("forget");
    assert!(user_names(None).expect("rows").is_empty(), "the value outlived the word");
    assert!(taught_names().expect("taught").is_empty());
}

fn a_list_comes_back_counted() {
    a_vault("three");
    add_user_name("Lindqvist".to_string(), UserNameKind::Family, false, None, "de".to_string()).expect("already there");

    let csv = "name,type,source,licence\n\
               Anneli,given,SCB 2024,CC0\n\
               Lindqvist,family,SCB 2024,CC0\n\
               Nordstern Consulting GmbH,company,,\n\
               ,given,,\n\
               Olle Berg,given,,\n\
               Svensson,surname,,\n";
    let report = import_user_names(csv.to_string(), None, "de".to_string()).expect("import");

    assert_eq!(report.added, 2, "{report:?}");
    assert_eq!(report.already_known, 1, "{report:?}");
    assert_eq!(report.refused, 3, "{report:?}");
    assert_eq!(report.reasons.len(), 3);
    assert!(report.reasons[0].contains("line 5"), "{:?}", report.reasons);
    assert!(report.reasons[1].contains("two words"), "{:?}", report.reasons);
    assert!(report.reasons[2].contains("given, family, person and company"), "{:?}", report.reasons);

    // What was added is there, and the provenance came with it — kept, not shown.
    let rows = user_names(None).expect("rows");
    assert_eq!(rows.len(), 3, "{rows:?}");
    assert!(rows.iter().any(|r| r.text == "Anneli" && r.kind == UserNameKind::Given));
}

fn a_file_without_a_type_column_is_refused_with_a_sentence() {
    a_vault("four");
    let bad = import_user_names("name\nAnneli\nLindqvist\n".to_string(), None, "de".to_string());
    match bad {
        Err(ApiError::InputRefused { reason }) => {
            assert!(reason.contains("type"), "the sentence does not name the missing column: {reason}");
        }
        other => panic!("a file with no type column was not refused: {other:?}"),
    }
    assert!(user_names(None).expect("rows").is_empty(), "a refused file wrote something");
}

/// A locked vault says so, and nothing is half-written.
fn everything_here_needs_an_open_vault() {
    a_vault("five");
    vault_lock().expect("lock");
    assert!(matches!(
        add_user_name("Anneli".to_string(), UserNameKind::Given, false, None, "de".to_string()),
        Err(ApiError::VaultLocked)
    ));
    assert!(matches!(user_names(None), Err(ApiError::VaultLocked)));
    assert!(matches!(
        import_user_names("name,type\nAnneli,given\n".to_string(), None, "de".to_string()),
        Err(ApiError::VaultLocked)
    ));
}

/// A German spreadsheet writes its CSV with semicolons, and the owner's lists
/// are German and Swedish.
fn a_semicolon_file_reads_the_same() {
    a_vault("six");
    let report = import_user_names("name;type\nAnneli;given\nLindqvist;family\n".to_string(), None, "de".to_string()).expect("import");
    assert_eq!((report.added, report.already_known, report.refused), (2, 0, 0), "{report:?}");
}

// ------------------------------------------------- the lists (041-I)

/// The owner, 6 October: «the language list is what establishes the word lists
/// inside the vault: if you choose Arabic an Arabic list is made, then if you
/// move to another language and so on — but one list per language».
///
/// So a list **is** a language, and the switch is the whole claim: turning one
/// off stops its names being used **without forgetting one of them**, so a
/// person can read the same document with a dictionary and without it and see
/// what the dictionary did.
fn a_list_that_is_off_is_not_a_list_that_was_forgotten() {
    a_vault("lists");
    // Two languages, each with the surname of somebody the packs do not know.
    // «ar» has no pack in this build at all, and that is the point: a person
    // builds their Arabic list by hand long before an Arabic pack exists.
    add_user_name("Okonkwo".to_string(), UserNameKind::Family, false, None, "ar".to_string())
        .expect("one");
    add_user_name("Lindqvist".to_string(), UserNameKind::Family, false, None, "sv".to_string())
        .expect("two");
    // And a list is a language this build has heard of, installed or planned.
    assert!(
        matches!(
            add_user_name("Nobody".to_string(), UserNameKind::Family, false, None, "My names".to_string()),
            Err(ApiError::InputRefused { .. })
        ),
        "a list was invented out of free text"
    );

    let lists = user_lists().expect("lists");
    // Two, because a list exists when its first name does and not before.
    assert_eq!(lists.len(), 2, "{lists:?}");
    assert!(lists.iter().all(|l| l.enabled && l.names == 1), "{lists:?}");

    // The document both of them are in. Neither surname is in any pack, and
    // both given names are: the pair rule needs the taught half.
    let doc = "Die Unterlagen kamen von Sophie Okonkwo und von Thomas Lindqvist.";
    let people = |text: &str| -> Vec<String> {
        let session = open_session(None, "de".to_string()).expect("open");
        import_text(session, text.to_string()).expect("import");
        scan(session).expect("scan");
        let units: Vec<u16> = text.encode_utf16().collect();
        list_findings(session)
            .expect("findings")
            .into_iter()
            .filter(|f| f.kind == Kind::Person)
            .map(|f| {
                String::from_utf16_lossy(
                    units.get(f.span.start as usize..f.span.end as usize).unwrap_or_default(),
                )
            })
            .collect()
    };
    let both = people(doc);
    assert!(both.iter().any(|t| t == "Sophie Okonkwo"), "{both:?}");
    assert!(both.iter().any(|t| t == "Thomas Lindqvist"), "{both:?}");

    // Off: the names are still here, and the scanner is not told about them.
    set_user_list_enabled("ar".to_string(), false).expect("off");
    let after = people(doc);
    assert!(
        !after.iter().any(|t| t == "Sophie Okonkwo"),
        "a list that is off still protected its name: {after:?}"
    );
    assert!(
        after.iter().any(|t| t == "Thomas Lindqvist"),
        "turning one list off took another list's name with it: {after:?}"
    );
    assert_eq!(
        user_names(None).expect("names").len(),
        2,
        "a name was forgotten by a switch"
    );

    // And on again, with nothing taught twice.
    set_user_list_enabled("ar".to_string(), true).expect("on");
    assert!(people(doc).iter().any(|t| t == "Sophie Okonkwo"), "the switch does not come back");
}

/// Imported into a language's list, and forgotten — with the cost said first,
/// the way forgetting a value says it.
fn a_list_is_imported_and_forgotten() {
    a_vault("lists-two");
    let report = import_user_names(
        "name,type\nAnneli,given\nLindqvist,family\nOkonkwo,family\n".to_string(),
        None,
        "sv".to_string(),
    )
    .expect("import");
    assert_eq!(report.added, 3, "{report:?}");

    let lists = user_lists().expect("lists");
    let imported = lists.iter().find(|l| l.name == "sv").expect("the list");
    assert_eq!(imported.names, 3, "the file's names are not in the language's list");

    // One name in another language, to prove forgetting takes only its own.
    add_user_name("Haddad".to_string(), UserNameKind::Family, false, None, "ar".to_string())
        .expect("one more");

    // What it costs, before it is done.
    assert_eq!(user_list_plan("sv".to_string()).expect("plan"), 3);
    assert_eq!(forget_user_list("sv".to_string()).expect("forget"), 3);
    let left = user_names(None).expect("names");
    assert_eq!(left.len(), 1, "forgetting a list took more than its own: {left:?}");
    assert_eq!(left[0].text, "Haddad");
    assert!(
        user_lists().expect("lists").iter().all(|l| l.name != "sv"),
        "the list outlived its names"
    );
}
