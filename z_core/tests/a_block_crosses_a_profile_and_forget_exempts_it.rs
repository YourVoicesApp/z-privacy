// Rules 58 and 59 — the owner's two answers of 16 October 2026, measured.
//
//   58. «البلوك يعبر من ملف عميل إلى ملف عميل. كلمة حُميت عند العميل A تُحمى
//       عند العميل B، فالبلوك في خزنة المستخدم لا في ملف العميل. والجملة على
//       الشاشة لا تذكر أين حُميت الكلمة أول مرة ولا متى.»
//   59. «Forget يُعفي بلوكات تلك الكلمة من العمل ولا يمسحها.»
//
// Both answer a collision this tree reported rather than resolved: 089 rule 1
// made every protected word a block in the person's vault, and rule 55 made
// every reading write one — so a block met two laws written before it (079's
// «a value in another profile is not loaded» and 056's «Forget, and a new
// document does not know it»). Ten guards were parked with `#[ignore]` naming
// the question; they are back in the suite, each flipped where it stands.
//
// **What is new here, and what is not.** The flipped guards hold the old laws'
// half. This file holds the new law's own half: that a block crosses, that the
// card it puts on the glass says neither where nor when (rule 58's condition),
// that «Forget» exempts and never deletes, and that every door which takes a
// word out of the vault's knowledge goes through one hand.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein genügend langes kennwort für die blöcke zweier mandanten";

/// A codename no pack and no rule can find. That is the whole point: when it
/// comes back protected in another client's document, the block is the only
/// thing that could have done it.
const WORD: &str = "Wintermond";
const DOC: &str = "Das Projekt Wintermond läuft weiter.";
const LATER: &str = "Zu Wintermond gibt es Neues.";

/// What a block names itself where an identity would stand. A taught value
/// names the identity it came from; a block names nobody, because nobody
/// taught it — which is how these guards tell rule 58 from a leak.
const A_BLOCK: &str = "a word you protected";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

struct Ground(std::path::PathBuf);

impl Ground {
    fn fresh(name: &str) -> Self {
        // **Locked first, always.** The core's vault is one per process and an
        // earlier test in this binary leaves one open; creating over it
        // refuses, and a harness that refuses measures nothing.
        let _ = vault_lock();
        let dir = std::env::temp_dir().join(format!("zprivacy-58-59-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
        vault_create_with_passphrase(PASS.to_string()).expect("vault");
        Self(dir)
    }
}

impl Drop for Ground {
    fn drop(&mut self) {
        let _ = vault_lock();
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

fn blocks() -> u32 {
    vault_snapshot().expect("snapshot").block_count
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("the fixture does not hold its own needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

/// Protect the codename by hand in a document of this client's, and leave.
/// A hand selection is the plainest way a word becomes a block: no pack, no
/// rule, nobody taught anything.
fn protect_it_for(profile: Option<&str>) {
    let s = open_session(profile.map(str::to_string), "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, span_of(DOC, WORD), Scope::Once, Kind::Project).expect("protect by hand");
    close_session(s).expect("close");
}

/// Read a fresh document in a client's profile and report what claimed the
/// codename: its source, and every identity named beside it.
fn who_claims_it(profile: Option<&str>) -> Option<(Source, Vec<String>)> {
    let s = open_session(profile.map(str::to_string), "de".to_string()).expect("session");
    import_text(s, LATER.to_string()).expect("import");
    scan(s).expect("scan");
    let got = span_of(LATER, WORD);
    let answer = list_findings(s)
        .expect("findings")
        .into_iter()
        .find(|f| f.span.start < got.end && got.start < f.span.end)
        .map(|f| (f.source, f.entities));
    close_session(s).expect("close");
    answer
}

/// Is the codename protected at all in a fresh document under this profile?
fn protected_again(profile: Option<&str>) -> bool {
    who_claims_it(profile).is_some()
}

// ---------------------------------------------------------------- rule 58

/// **A word protected for one client is protected for the next** — rule 58.
///
/// The block lives in the person's vault, so it is not a fact about client A
/// that client B is being told: it is the person's own decision about a word,
/// arriving wherever they read it. What stays client A's is the knowledge —
/// the identity, the label, the other spellings — and the finding below names
/// no identity at all.
#[test]
fn a_block_crosses_from_one_client_to_another() {
    let _g = serial();
    let _ground = Ground::fresh("crosses");
    let a = create_profile("Client A".to_string(), None).expect("a");
    let b = create_profile("Client B".to_string(), None).expect("b");

    // Control: before anything is protected, nothing in this build finds the
    // codename — so «it came back» below cannot be a pack's doing.
    assert!(
        !protected_again(Some(&b)),
        "a pack or a rule finds this codename, so this guard would measure nothing"
    );

    protect_it_for(Some(&a));
    let (source, named) = who_claims_it(Some(&b)).expect("rule 58: the word did not cross to client B");
    assert_eq!(source, Source::Vault, "it came back, but not from the vault layer");
    assert_eq!(
        named,
        vec![A_BLOCK.to_string()],
        "the word crossed carrying a client's knowledge with it"
    );

    // And in no client at all, which is the reading the person does most.
    assert!(protected_again(None), "the word did not come back with no client selected");
}

/// **Rule 58's condition: the sentence says neither where nor when.**
///
/// The owner's own clause — «والجملة على الشاشة لا تذكر أين حُميت الكلمة أول
/// مرة ولا متى» — is a promise about the Why card, which is the one place a
/// protection explains itself. So every part of that card is asked here: the
/// headline, every line of «because», the reach, and the date row the glass
/// draws only when there is a date (`why_sheet.dart`, `learnedAt > 0`).
///
/// It is read against the facts a card must not carry: the profile the word
/// was first protected in, the session it was protected in, and the day.
#[test]
fn a_blocks_card_says_no_where_and_no_when() {
    let _g = serial();
    let _ground = Ground::fresh("card");
    let a = create_profile("Nordstern".to_string(), None).expect("a");
    let b = create_profile("Südwind".to_string(), None).expect("b");
    protect_it_for(Some(&a));

    let s = open_session(Some(b.clone()), "de".to_string()).expect("session");
    import_text(s, LATER.to_string()).expect("import");
    scan(s).expect("scan");
    let why = explain(s, span_of(LATER, WORD)).expect("the why card");

    let said = format!("{} · {} · {}", why.headline, why.because.join(" · "), why.applies);
    assert!(
        why.headline.contains("protected this word before"),
        "a block's card does not say what it is: {}",
        why.headline
    );
    // Where. Neither client's name, and neither client's id — a profile id is
    // a slug of the name, which is the client's own word.
    for forbidden in ["Nordstern", "Südwind", a.as_str(), b.as_str()] {
        assert!(
            !said.contains(forbidden),
            "the card says where the word was first protected («{forbidden}»): {said}"
        );
    }
    // When. The date row is drawn from `learned_at`, and a block has no
    // «taught on»: nobody taught it.
    assert_eq!(
        why.learned_at, 0,
        "the card carries a date for a word nobody taught, and the glass draws it"
    );
    assert!(
        why.taught_reach.is_none() && why.entity.is_none(),
        "the card offers a «Forget» for knowledge that does not exist"
    );
    // Which session. The first protection happened in another session, and its
    // number is a fact the card has no business carrying.
    for digit in ['1', '2', '3'] {
        assert!(
            !why.headline.contains(digit),
            "the card names a session number: {}",
            why.headline
        );
    }
    close_session(s).expect("close");
}

// ---------------------------------------------------------------- rule 59

/// **«Forget everywhere» exempts the word's blocks — and keeps them** — rule
/// 59.
///
/// Two halves, and the second is the one 089 rule 2 is about: after the act
/// the word is not protected in a new document in any profile, and the block
/// is still in the vault, so z-pdf reads it back out of a document protected
/// before the act (rule 50). The count is the measurement, never the value.
#[test]
fn forget_everywhere_exempts_every_profile_and_keeps_the_block() {
    let _g = serial();
    let _ground = Ground::fresh("forget-all");
    let a = create_profile("Client A".to_string(), None).expect("a");
    let b = create_profile("Client B".to_string(), None).expect("b");

    // Taught **and** protected, which is what «always» is: the word is both
    // knowledge and a block, and «Forget» is asked about the knowledge.
    let s = open_session(Some(a.clone()), "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, span_of(DOC, WORD), Scope::Always, Kind::Project).expect("always");
    close_session(s).expect("close");
    let held = blocks();
    assert!(held >= 1, "the word did not become a block, so there is nothing to exempt");
    assert!(protected_again(Some(&b)), "the control: it crosses before it is forgotten");

    let known = search_vault(WORD.to_string()).expect("search");
    assert_eq!(known.len(), 1, "the word was not taught, so «Forget» has no subject");
    let card = entity(known[0].id).expect("card");
    forget_value(known[0].id, card.values[0].id, true).expect("forget everywhere");

    assert!(search_vault(WORD.to_string()).expect("search").is_empty(), "the knowledge stayed");
    assert_eq!(blocks(), held, "a block was deleted, and rule 50 says a block never disappears");
    for client in [Some(a.as_str()), Some(b.as_str()), None] {
        assert!(
            !protected_again(client),
            "a new document still protected the forgotten word in {client:?}"
        );
    }
}

/// **«Forget from this profile» exempts that client's reading only** — rule
/// 59's second sentence, and rule 58 still standing beside it: the block is
/// the person's, so the client who did not forget it still gets it back.
#[test]
fn forget_from_this_profile_exempts_that_client_only() {
    let _g = serial();
    let _ground = Ground::fresh("forget-one");
    let a = create_profile("Client A".to_string(), None).expect("a");
    let b = create_profile("Client B".to_string(), None).expect("b");

    let s = open_session(Some(a.clone()), "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, span_of(DOC, WORD), Scope::Profile, Kind::Project).expect("this client");
    close_session(s).expect("close");
    let held = blocks();

    let known = search_vault(WORD.to_string()).expect("search");
    let card = entity(known[0].id).expect("card");
    forget_value(known[0].id, card.values[0].id, false).expect("forget from this profile");

    assert_eq!(blocks(), held, "a block was deleted");
    assert!(
        !protected_again(Some(&a)),
        "the client who forgot the word still had it protected"
    );
    assert!(
        protected_again(Some(&b)),
        "«from this profile» reached a client it was not asked about (rule 58)"
    );
    assert!(
        protected_again(None),
        "«from this profile» reached a reading that belongs to no client"
    );
}

/// **A forgotten word still comes back out of an old document** — rule 59's
/// third sentence, which is rule 50 read from the other side: the block is
/// exempt from *work*, and the way back is not work, it is memory.
#[test]
fn a_forgotten_word_still_comes_back_from_an_old_document() {
    let _g = serial();
    let _ground = Ground::fresh("the-way-back");
    let a = create_profile("Client A".to_string(), None).expect("a");

    let s = open_session(Some(a.clone()), "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, span_of(DOC, WORD), Scope::Always, Kind::Project).expect("always");
    // The document as it left: the codename is a token in it.
    let taken = payload_to_take_out(s).expect("take out");
    assert!(!taken.text.contains(WORD), "the word left in the clear");
    close_session(s).expect("close");

    let known = search_vault(WORD.to_string()).expect("search");
    let card = entity(known[0].id).expect("card");
    forget_value(known[0].id, card.values[0].id, true).expect("forget everywhere");
    assert!(!protected_again(Some(&a)), "the exemption did not take");

    // And the old document, read back after the act, still names its own word.
    let came_back = read_a_document_that_came_back(taken.text.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("read back");
    let whole: String = came_back.restored.iter().map(|seg| seg.text.as_str()).collect();
    assert!(
        whole.contains(WORD),
        "a document protected before the «Forget» could not be read back: {whole}"
    );
}

/// **Every door that takes a word out of the vault's knowledge exempts its
/// blocks** — and the doors are enumerated from what they do, not from what
/// this round remembered.
///
/// This house's most expensive trap is a law written at one door out of
/// several: 083a's three exits, 080's two language doors, 089 rule 9's missing
/// fourth. So the doors are listed here with the act each one is, and the
/// gate (G40) reads the same enumeration out of the source.
///
/// **A fifth was added on 17 October, by the independent attacker (م6):**
/// «Delete this identity». It removed the identity and left its blocks
/// working, while the dialog promised «the next document will not recognise
/// these values again» — and the attacker measured the next document
/// protecting the name on its own. One identity can hold several values and
/// each value several spellings, so this door forgets more words in one press
/// than any of the other four.
#[test]
fn every_door_that_forgets_a_word_exempts_its_blocks() {
    let _g = serial();

    // Each door is the act a person makes: the word is already a block (one
    // hand selection, no knowledge at all), the door's own knowledge about it
    // is taught, and then the door's own button is pressed. What must follow
    // is the same in all four: the block is still there, and the word is no
    // longer protected in a new document.
    type Door = fn(&str) -> ();
    let doors: [(&str, Door); 5] = [
        ("Forget everywhere", |profile| {
            let who = create_entity(EntityKind::Client, "Akte".to_string(), Some(profile.to_string()))
                .expect("entity");
            let value = set_value(who, None, Kind::Project, WORD.to_string(), Policy::Always).expect("value");
            forget_value(who, value, true).expect("forget everywhere");
        }),
        ("the vault room's delete of one value", |profile| {
            let who = create_entity(EntityKind::Client, "Akte".to_string(), Some(profile.to_string()))
                .expect("entity");
            let value = set_value(who, None, Kind::Project, WORD.to_string(), Policy::Always).expect("value");
            delete_value(who, value).expect("delete the value");
        }),
        ("the vault room's delete of one spelling", |profile| {
            // A spelling is its own word and took its own token, so forgetting
            // one of them is the same act one word narrower.
            let who = create_entity(EntityKind::Client, "Akte".to_string(), Some(profile.to_string()))
                .expect("entity");
            let value = set_value(who, None, Kind::Project, "Wintermond-Akte".to_string(), Policy::Always)
                .expect("value");
            add_value_alias(who, value, WORD.to_string()).expect("alias");
            remove_value_alias(who, value, WORD.to_string()).expect("forget the spelling");
        }),
        ("«Forget» on a name you taught", |profile| {
            let id = teach_name(WORD.to_string(), false, Some(profile.to_string()), None).expect("teach");
            forget_name(id).expect("forget the name");
        }),
        // **The attacker's own press, م6.** Two values on one identity, so
        // this measures what the door really takes: every word the identity
        // taught, not the first one found.
        ("«Delete this identity» in the vault room", |profile| {
            let who = create_entity(EntityKind::Client, "Akte".to_string(), Some(profile.to_string()))
                .expect("entity");
            set_value(who, None, Kind::Project, WORD.to_string(), Policy::Always).expect("value");
            set_value(who, None, Kind::Project, "Sommerwind".to_string(), Policy::Always)
                .expect("a second value, so one spelling cannot stand for the identity");
            delete_entity(who).expect("delete the identity");
        }),
    ];

    for (which, press) in doors {
        // A vault of this door's own, so one door cannot pass on another's act.
        let _ground = Ground::fresh("door");
        let profile = create_profile("Client A".to_string(), None).expect("profile");
        protect_it_for(Some(&profile));
        let held = blocks();
        assert!(held >= 1, "«{which}»: the word did not become a block");
        assert!(
            protected_again(Some(&profile)),
            "«{which}»: the control failed — the word was not coming back even before the act"
        );

        press(&profile);

        assert_eq!(blocks(), held, "«{which}» deleted a block (rule 50)");
        assert!(
            !protected_again(Some(&profile)),
            "«{which}» left the word protected in a new document (rule 59)"
        );
    }
}

/// **Nothing short of teaching it again undoes a «Forget»** — measured because
/// the trap is one line away, and because the edge is a decision this round
/// had to make.
///
/// Two acts could write over an exemption, and neither may:
///
/// * **A rescan of the document that was open.** «Forget» does not reach into
///   it (the owner, 28 September), so it keeps its tokens and its words are
///   still the words its bench named — and every settle hands those words to
///   `remember_block`.
/// * **A hand selection somewhere else.** That protects the word *there*,
///   which is rule 11 and the person's own doing; it mints a new token, so the
///   block really is written again. What it may not do is start the automatic
///   protection the person switched off.
///
/// The way back is the way in: the act that taught the word teaches it again,
/// and then it is knowledge, not a block, that protects it. An exemption is
/// exempt from **work**, never from the person's hand — which is also why the
/// old document still reads its own names back (rule 50).
#[test]
fn nothing_short_of_teaching_it_again_undoes_a_forget() {
    let _g = serial();
    let _ground = Ground::fresh("rescan");
    let profile = create_profile("Client A".to_string(), None).expect("a");

    let open = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(open, DOC.to_string()).expect("import");
    scan(open).expect("scan");
    protect(open, span_of(DOC, WORD), Scope::Always, Kind::Project).expect("always");

    let known = search_vault(WORD.to_string()).expect("search");
    let card = entity(known[0].id).expect("card");
    forget_value(known[0].id, card.values[0].id, true).expect("forget everywhere");

    // 1 · the document that was open keeps its protection, and a rescan of it
    // is the moment the exemption could be written over.
    scan(open).expect("rescan the document that was open");
    assert!(
        !list_tokens(open).expect("tokens").is_empty(),
        "the open document lost its tokens to a «Forget»"
    );
    assert!(
        !protected_again(Some(&profile)),
        "a rescan of the open document undid the «Forget»"
    );
    close_session(open).expect("close");

    // 2 · a hand selection in another **session** protects it there, under a
    // name that session minted itself — and the next document is still not
    // asked to find the word by itself.
    //
    // The session is begun by hand on purpose. A bench opened while a session
    // is open joins it, so the word would be named by the same key and the
    // token would be the one the block already holds — nothing would be
    // written, and this half would pass by measuring nothing.
    let by_hand = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    conversation_begin("another session".to_string(), Some(by_hand)).expect("a session of its own");
    import_text(by_hand, LATER.to_string()).expect("import");
    scan(by_hand).expect("scan");
    protect(by_hand, span_of(LATER, WORD), Scope::Once, Kind::Project).expect("by hand");
    assert!(
        !list_tokens(by_hand).expect("tokens").is_empty(),
        "a hand selection did not protect the word in the document it was made in (rule 11)"
    );
    close_session(by_hand).expect("close");
    assert!(
        !protected_again(Some(&profile)),
        "one hand selection revived a word the person had forgotten everywhere"
    );

    // 3 · and the way back.
    let s = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(s, DOC.to_string()).expect("import");
    scan(s).expect("scan");
    protect(s, span_of(DOC, WORD), Scope::Always, Kind::Project).expect("always again");
    close_session(s).expect("close");
    assert!(
        protected_again(Some(&profile)),
        "teaching the word again did not bring the protection back"
    );
}

/// **A refused press writes nothing** — the lead's finding on `623f9b7`, and
/// the reason an exemption is the one mark in this file that must wait for the
/// act to succeed.
///
/// `Vault::with_open_mut` does not roll the vault back when its closure
/// returns `Err`: the change stays in memory and the next successful write
/// seals it. An exemption written above a refusal is therefore permanent — and
/// `remove_value_alias` wrote it first, where an unknown identity reads as
/// `home = None`, which is `Everywhere`, the **widest** of the three reaches.
/// So a press that was refused would have quietly stopped protecting the word
/// in every profile, with no way back but teaching it again.
#[test]
fn a_refused_press_leaves_the_blocks_working() {
    let _g = serial();
    let _ground = Ground::fresh("refused");
    let profile = create_profile("Client A".to_string(), None).expect("a");
    protect_it_for(Some(&profile));
    let held = blocks();
    assert!(
        protected_again(Some(&profile)),
        "the control failed: the word was not coming back even before the refusal"
    );

    // A value whose own spelling is the word, and **`Manual`** — kept in the
    // vault so its spellings and token stay stable, hunted by nobody. That is
    // what makes this guard measure the block: with an `Always` value the word
    // would be protected by the knowledge whatever happened to the block, and
    // the guard would pass for the wrong reason. It did, on the first writing
    // of it.
    let who = create_entity(EntityKind::Client, "Akte".to_string(), Some(profile.clone()))
        .expect("entity");
    let value = set_value(who, None, Kind::Project, WORD.to_string(), Policy::Manual).expect("value");
    assert!(
        matches!(
            remove_value_alias(who, value, WORD.to_string()),
            Err(ApiError::UnknownToken)
        ),
        "the refusal this guard is about did not happen, so it measures nothing"
    );
    // An unknown identity, the other refusal — and the one that reads as the
    // widest reach of the three, because an identity that is not there has no
    // profile and «no profile» means «everywhere».
    assert!(matches!(
        remove_value_alias(9_999, value, WORD.to_string()),
        Err(ApiError::UnknownToken)
    ));

    // A write that succeeds, which is what seals whatever the refusals left
    // behind in memory.
    teach_name("Sommer".to_string(), false, Some(profile.clone()), None).expect("teach a name");
    assert_eq!(blocks(), held, "a refused press made or deleted a block");
    assert!(
        protected_again(Some(&profile)),
        "a refused press exempted the word's block in this client, and nothing takes an exemption back"
    );
    assert!(
        protected_again(None),
        "a refused press about an identity that does not exist exempted the word everywhere"
    );
    // And after a restart, because the question is about what reached the file.
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert!(
        protected_again(Some(&profile)) && protected_again(None),
        "the exemption a refused press wrote was sealed into the vault"
    );
}

// --------------------------------------------------------------- rule 59-أ

/// **A hand protection after «Forget» does not bring the automatic one back**
/// — rule 59-أ, the owner's word of 17 October.
///
/// This is the edge this round proposed and he ruled on, and he ruled «no» on
/// the opposite reading: the only act that lifts an exemption is teaching the
/// word in the vault again. A hand selection protects the word **where the
/// hand was** — rule 11, the person's own doing — and that is the whole of
/// what it does.
///
/// The two acts cannot be one because they are not the same size. A hand
/// selection is a fact about one document. Automatic protection is a standing
/// instruction about every document that comes after, and «Forget» is the act
/// that withdrew it. Nothing but giving the instruction again gives it back —
/// and reading a hand selection as «he wants it everywhere once more» would
/// take a decision back on the person's behalf, in the one direction that
/// **uncovers** nothing and **covers** what he uncovered on purpose.
///
/// `nothing_short_of_teaching_it_again_undoes_a_forget` measures the same
/// edge against a rescan and a hand in another session. What is added here is
/// the owner's own sequence, by name, and **the restart**: the question his
/// «no» answers is what the file says tomorrow, not what memory says now.
#[test]
fn a_hand_protection_after_forget_does_not_restore_the_automatic_one() {
    let _g = serial();
    let _ground = Ground::fresh("by-hand-after-forget");
    let profile = create_profile("Client A".to_string(), None).expect("a");

    // 1 · the standing instruction, given the way a person gives it: a word
    // protected «everywhere» from inside a document.
    let taught = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(taught, DOC.to_string()).expect("import");
    scan(taught).expect("scan");
    protect(taught, span_of(DOC, WORD), Scope::Always, Kind::Project).expect("always");
    close_session(taught).expect("close");
    assert!(
        protected_again(Some(&profile)),
        "the control failed: the word was not protected automatically even before the «Forget»"
    );
    let held = blocks();

    // 2 · «Forget everywhere», and the law of rule 59: a new document does not
    // know the word any more.
    let known = search_vault(WORD.to_string()).expect("search");
    let card = entity(known[0].id).expect("card");
    forget_value(known[0].id, card.values[0].id, true).expect("forget everywhere");
    assert!(
        !protected_again(Some(&profile)),
        "«Forget everywhere» left the automatic protection standing"
    );

    // 3 · the hand, in a session of its own — begun by hand on purpose,
    // because a bench opened while a session is open joins it and would mint
    // the token the block already holds, so nothing would be written and this
    // guard would pass by measuring nothing.
    let by_hand = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    conversation_begin("a session after the forget".to_string(), Some(by_hand))
        .expect("a session of its own");
    import_text(by_hand, LATER.to_string()).expect("import");
    scan(by_hand).expect("scan");
    protect(by_hand, span_of(LATER, WORD), Scope::Once, Kind::Project).expect("by hand");
    assert!(
        !list_tokens(by_hand).expect("tokens").is_empty(),
        "the hand protected nothing in its own document, so rule 11 broke and 59-أ is unmeasured"
    );
    close_session(by_hand).expect("close");

    // 4 · rule 59-أ itself: the next document is still not asked to find the
    // word by itself.
    assert!(
        !protected_again(Some(&profile)),
        "a hand protection after «Forget» started the automatic protection again"
    );

    // 5 · and over a restart, because the exemption is a line in a file and
    // the hand's own act wrote to that same file.
    vault_lock().expect("lock");
    vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    assert!(
        !protected_again(Some(&profile)),
        "the vault came back from disk with the forgotten word hunting again"
    );
    assert!(
        blocks() >= held,
        "a block was deleted somewhere along this journey, and no act in it may delete one"
    );

    // 6 · the one way back, and it is the way in.
    let again = open_session(Some(profile.clone()), "de".to_string()).expect("session");
    import_text(again, DOC.to_string()).expect("import");
    scan(again).expect("scan");
    protect(again, span_of(DOC, WORD), Scope::Always, Kind::Project).expect("always again");
    close_session(again).expect("close");
    assert!(
        protected_again(Some(&profile)),
        "teaching the word in the vault again did not bring the automatic protection back"
    );
}
