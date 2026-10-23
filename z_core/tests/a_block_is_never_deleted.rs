// 089 rules 1–8 · **a block is never deleted** — the owner's rule of 15 October
// 2026, measured.
//
//   «كل كلمة يأخذ رمزاً… هي بلوك غير قابل للحذف من خزنة المستخدم… والبلوك قيمة
//   ثابتة لا تمسح، يمكن أن تُعفى من العمل ولكن لا تختفي.»
//   «منذ هذه اللحظة متى قُرئت هذه الكلمة داخل التطبيق في مكان، حتى لو بعد سنة،
//   يجب أن تأخذ كود.»
//
// The round this reverses is 083e/079's trade — «this conversation's own names
// are kept only while it is open» — which the owner tested across two days and
// rejected: «أعتقد أنني كنت واضحاً أن الحماية ستكون دائمة». Its guards are
// flipped where they stand, in
// `a_document_that_comes_back_is_translated.rs`; what is here is everything the
// new rule adds.
//
// **What is measured, and nothing else:** the blocks **by count, never by
// value** (the one door that reads a block's word is the door back, where a
// token in the person's own document asked for it), and the bytes of `vault.zv`
// before and after, because «kept for ever» is a promise about a file.
#![allow(clippy::unwrap_used, clippy::expect_used, clippy::panic, clippy::indexing_slicing)]

use std::sync::{Mutex, MutexGuard, OnceLock};

use z_core::api::*;

const PASS: &str = "ein genügend langes kennwort für die blöcke";

/// Two names and an identifier, in one line of ordinary German. Small on
/// purpose: these guards are about a word's **life**, and the owner's whole
/// letter is measured by the four guards in the file this one reverses.
const LINE: &str = "Kundennummer 8841-2270 für Herrn Stefan Keller, Nordstern Consulting GmbH.";

/// A second document that shares exactly one word with the first — the only
/// thing rule 3 is about: a block's word takes a token **somewhere else**.
const ELSEWHERE: &str = "Wir haben Stefan Keller heute zurückgerufen.";

/// A third, and the subject of rules 3 and 6 below: **the identifier with no
/// label in front of it.**
///
/// `Kundennummer` is what makes `8841-2270` findable in `LINE` (046/M: an
/// identifier is found by its label or by its shape). Here there is no label
/// and no shape to go by, so nothing in this build finds this number — which
/// makes it the one subject where «it is protected» can only mean «the block
/// did it». The two guards below are each other's control on exactly that: the
/// exempted conversation finds nothing at all over it, and the other one finds
/// it protected from the vault.
const AGAIN: &str = "Rechnung zu 8841-2270 liegt dem Brief bei.";

/// The word those two guards are about.
const NUMBER: &str = "8841-2270";

fn serial() -> MutexGuard<'static, ()> {
    static LOCK: OnceLock<Mutex<()>> = OnceLock::new();
    match LOCK.get_or_init(|| Mutex::new(())).lock() {
        Ok(g) => g,
        Err(p) => p.into_inner(),
    }
}

struct Ground(std::path::PathBuf);

impl Ground {
    /// A vault of its own, in a directory of its own.
    fn fresh(name: &str) -> Self {
        let _ = vault_lock();
        let dir =
            std::env::temp_dir().join(format!("zprivacy-089-blocks-{name}-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        set_data_dir(dir.to_string_lossy().to_string()).expect("dir");
        vault_create_with_passphrase(PASS.to_string()).expect("vault");
        Self(dir)
    }

    /// The bytes of `vault.zv` right now. «Kept for ever» is a promise about a
    /// file, so the file is what is asked.
    fn vault_bytes(&self) -> u64 {
        std::fs::metadata(self.0.join("vault.zv")).map(|m| m.len()).unwrap_or(0)
    }

    /// **A restart, as far as anything stored can tell.** Every bench is gone,
    /// the vault is locked, and it is opened again — which re-reads the file
    /// from the disk and decodes it, so what answers afterwards answers from
    /// the bytes and not from this run's memory.
    fn restart(&self) {
        vault_lock().expect("lock");
        vault_unlock_with_passphrase(PASS.to_string()).expect("unlock");
    }
}

impl Drop for Ground {
    fn drop(&mut self) {
        let _ = vault_lock();
        let _ = std::fs::remove_dir_all(&self.0);
    }
}

/// A bench that closes itself even when a test panics.
struct Bench(SessionId);

impl Drop for Bench {
    fn drop(&mut self) {
        close_session(self.0).ok();
    }
}

fn blocks() -> u32 {
    vault_snapshot().expect("the vault snapshot").block_count
}

fn span_of(doc: &str, needle: &str) -> Span {
    let byte = doc.find(needle).expect("the fixture does not contain its own needle");
    let start: usize = doc[..byte].chars().map(char::len_utf16).sum();
    Span {
        start: start as u32,
        end: (start + needle.chars().map(char::len_utf16).sum::<usize>()) as u32,
    }
}

fn read(segments: &[Segment]) -> String {
    segments.iter().map(|s| s.text.as_str()).collect()
}

/// Say «protect» to every word that waits, so the exit's own law opens.
fn answer_everything(bench: SessionId) {
    let waiting: Vec<u32> = list_findings(bench)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .map(|f| f.id)
        .collect();
    for id in waiting {
        answer_finding(bench, id, FindingAnswer::Protect).expect("answer");
    }
}

/// One line on a bench, every word answered, born into a conversation named
/// `name`, and the text that would leave it.
fn a_line_that_has_left(name: &str, text: &str) -> (Bench, u32, String) {
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, text.to_string()).expect("import");
    answer_everything(held.0);
    conversation_begin(name.to_string(), Some(held.0)).expect("begin");
    let number = conversation_open().expect("open").expect("a session is open");
    let taken = payload_to_take_out(held.0).expect("nothing waits, so the exit opens");
    (held, number, taken.text)
}

/// **A restart changes nothing: every name still comes back** — rule 4.
///
/// The bench is gone, the vault is locked and opened again, and the z-pdf door
/// reads the file with no bench of its own. Nothing in this run's memory can
/// answer; what answers is `vault.zv`.
#[test]
fn every_name_comes_back_after_a_restart() {
    let _guard = serial();
    let ground = Ground::fresh("restart");
    let empty = ground.vault_bytes();
    assert_eq!(blocks(), 0, "a new vault holds blocks nobody made");

    let (held, _number, safe) = a_line_that_has_left("die Mahnung", LINE);
    let made = blocks();
    assert!(made >= 3, "the line protected three words and made {made} blocks");
    let grown = ground.vault_bytes();
    assert!(grown > empty, "the blocks were never written to the file: {empty} → {grown} bytes");

    // The bench dies and the vault shuts behind it. This is the owner's own
    // test from 15 October: «Close the app and open it again.»
    drop(held);
    ground.restart();
    assert_eq!(blocks(), made, "the blocks did not survive the file: {} of {made}", blocks());

    let seen = read_a_document_that_came_back(safe.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("the door back reads the file");
    assert!(seen.tokens >= 3, "the file holds {} token places", seen.tokens);
    assert_eq!(
        seen.brought_back, seen.names,
        "{} of {} names came back after a restart: {:?}",
        seen.brought_back, seen.names, seen.unresolved
    );
    let text = read(&seen.restored);
    assert!(text.contains("Stefan Keller"), "the name did not come back");
    assert!(text.contains("8841-2270"), "the identifier did not come back");
    assert!(text.contains("Nordstern Consulting GmbH"), "the company did not come back");
    assert!(!text.contains("__Z_"), "a token is still standing in the reading");
}

/// **Un-protect every place, forget the conversation: the block stands, and
/// the door still reads it back** — rules 2 and 6.
///
/// This is the hardest half of rule 2, and the reason the token is **written
/// down** rather than derived: forgetting a conversation destroys its 32 bytes
/// (`Conversation::key`), so after this nothing on this machine could derive
/// that name from that value ever again. The lookup still answers.
#[test]
fn nothing_deletes_a_block() {
    let _guard = serial();
    let ground = Ground::fresh("never");
    let (held, number, safe) = a_line_that_has_left("die Mahnung", LINE);
    let made = blocks();
    let size = ground.vault_bytes();

    // «In this conversation» — the second of the two un-protect options.
    let undone = unprotect_every_place(held.0, span_of(LINE, "Stefan Keller")).expect("unprotect");
    assert!(
        matches!(undone, UndoOutcome::Undone { .. }),
        "the un-protect did nothing, so nothing was exempted either: {undone:?}"
    );
    assert_eq!(blocks(), made, "un-protecting deleted a block");

    // And forgetting the conversation, which destroys the key every one of
    // these names was derived from.
    let gone = conversation_forget(number).expect("forget");
    assert_eq!(gone, "die Mahnung");
    assert_eq!(blocks(), made, "forgetting a conversation deleted its blocks");
    // **The file is smaller, and that is right:** forgetting a conversation
    // destroys its own record — the name, the 32 bytes, the document hash —
    // which is the whole of what the owner's warning on that screen promises.
    // What may not shrink is the blocks, and the count above is what says so.
    // Measured rather than asserted away: it shrank by 127 bytes when this was
    // first run, which is one `Conversation` row and not one block.
    let after = ground.vault_bytes();
    assert!(after > 0, "the vault file is gone");
    assert!(
        size.saturating_sub(after) < 512,
        "the vault lost {} bytes, which is more than one conversation's record",
        size.saturating_sub(after)
    );

    drop(held);
    ground.restart();
    assert_eq!(blocks(), made, "the blocks did not survive the forgetting");

    // The conversation cannot be named any more — its key is destroyed — and
    // every name still comes back, which no derivation could do.
    let seen = read_a_document_that_came_back(safe.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("the door back reads the file");
    assert!(
        seen.conversations.is_empty(),
        "a forgotten conversation was named: {:?}",
        seen.conversations
    );
    assert_eq!(
        seen.brought_back, seen.names,
        "{} of {} names came back from the blocks alone: {:?}",
        seen.brought_back, seen.names, seen.unresolved
    );
    let text = read(&seen.restored);
    assert!(text.contains("Stefan Keller"), "the un-protected word did not come back");
    assert!(text.contains("8841-2270"), "the identifier did not come back");
    assert!(!text.contains("__Z_"), "a token is still standing in the reading");
}

/// **«Leave it» makes no block** — rule 5.
///
/// A word left in the clear never took a token, and the blocks are made from
/// the words that did: the bench's own token store is the list, so this is true
/// by construction rather than by a rule somebody wrote at the dismissal door.
/// Measured all the same, because «by construction» is a claim.
#[test]
fn leave_it_makes_no_block() {
    let _guard = serial();
    let _ground = Ground::fresh("leaveit");
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, LINE.to_string()).expect("import");

    // One word is left and the rest are protected, in one document, so the
    // control is in the same run: the blocks that **are** made prove the door
    // works, and the count says the left one is not among them.
    let waiting: Vec<Finding> = list_findings(held.0)
        .expect("findings")
        .into_iter()
        .filter(|f| f.state == MarkState::Suggested)
        .collect();
    assert!(!waiting.is_empty(), "this line leaves nothing waiting, so nothing can be left");
    let left = waiting[0].clone();
    let word = LINE
        .get(..)
        .and_then(|t| {
            let (from, to) = (left.span.start as usize, left.span.end as usize);
            let units: Vec<u16> = t.encode_utf16().collect();
            String::from_utf16(units.get(from..to)?).ok()
        })
        .expect("the finding's own words");
    answer_finding(held.0, left.id, FindingAnswer::NotSensitive).expect("leave it");
    for finding in waiting.into_iter().skip(1) {
        answer_finding(held.0, finding.id, FindingAnswer::Protect).ok();
    }
    conversation_begin("die Mahnung".to_string(), Some(held.0)).expect("begin");
    let made = blocks();
    assert!(made > 0, "nothing at all became a block, so this guard measures nothing");

    // The word that was left is in the clear in the text that leaves, and it is
    // not a block: a token for it would have put it in the vault.
    let taken = payload_to_take_out(held.0).expect("take out");
    assert!(
        taken.text.contains(&word),
        "«{word}» was left in the clear and did not leave in the clear"
    );
    let seen = read_a_document_that_came_back(taken.text.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("read back");
    assert_eq!(
        seen.brought_back, seen.names,
        "the words that were protected did not all come back: {:?}",
        seen.unresolved
    );
    // And the count is the one measurement a report may carry: one word left,
    // so one fewer block than there were findings.
    assert_eq!(blocks(), made, "a block appeared with nothing protected");
}

/// **A block's word is protected in another conversation, on import** — rule 3,
/// the «Markus» case the owner tested on two days.
///
/// Nothing is taught to the vault here: one word is protected in the first
/// conversation and the second conversation has never seen it. It arrives
/// protected and not offered, because the person already answered about it.
#[test]
fn a_block_is_protected_in_another_conversation() {
    let _guard = serial();
    let ground = Ground::fresh("across");
    let (first, _number, _safe) = a_line_that_has_left("die erste", LINE);
    let made = blocks();
    drop(first);
    ground.restart();

    // A new bench, a new conversation, and a document that shares one word.
    let next = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(next.0, ELSEWHERE.to_string()).expect("import");
    conversation_begin("die zweite".to_string(), Some(next.0)).expect("begin");
    let second = conversation_open().expect("open").expect("a session is open");

    let over = |needle: &str| {
        list_findings(next.0)
            .expect("findings")
            .into_iter()
            .find(|f| {
                let got = span_of(ELSEWHERE, needle);
                f.span.start < got.end && got.start < f.span.end
            })
            .unwrap_or_else(|| panic!("nothing was found over «{needle}»"))
    };
    let keller = over("Stefan Keller");
    assert_eq!(
        keller.state,
        MarkState::Protected,
        "a block's word was {:?} in another conversation instead of protected",
        keller.state
    );
    assert_eq!(
        keller.source,
        Source::Vault,
        "it was protected by {:?} and not by the vault",
        keller.source
    );

    // **And the card says what it is.** «You taught Z Privacy this value» is
    // what every other `Source::Vault` protection says, and it would be false
    // here: nobody taught this word, there is no identity behind it, and what
    // happened is that the person protected it once somewhere else.
    let why = explain(next.0, keller.span).expect("the why card");
    assert_eq!(
        why.headline, "You protected this word before, and Z Privacy kept it",
        "the card calls a block a taught value"
    );
    assert!(why.decided, "a word the person protected is marked as nobody's decision");

    // **And the token is this conversation's own**, derived from its own key —
    // so the word leaves the second conversation under a name the first one
    // never used, and the block now carries both.
    let taken = payload_to_take_out(next.0).expect("take out");
    assert!(
        !taken.text.contains("Stefan Keller"),
        "the block's word left the second conversation in the clear"
    );
    assert_eq!(blocks(), made, "the same word made a second block");

    // The second conversation's own z-pdf reads back, and so does the first's,
    // from the same blocks.
    let seen = read_a_document_that_came_back(taken.text.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("read back");
    assert_eq!(seen.conversations.len(), 1, "{:?}", seen.conversations);
    assert_eq!(seen.conversations[0].number, second);
    assert_eq!(
        seen.brought_back, seen.names,
        "the second conversation's own names did not come back: {:?}",
        seen.unresolved
    );
    assert!(read(&seen.restored).contains("Stefan Keller"));
}

/// **«In this conversation» exempts in that conversation only** — rule 6.
///
/// The exemption is remembered on the block, so it survives a restart; and a
/// conversation that never asked for it still protects the word. Both halves in
/// one run, because either alone would pass for the wrong reason: an exemption
/// that leaked everywhere would make the first half green, and an exemption
/// that was never written would make the second.
///
/// **The subject is the unlabelled identifier**, for the reason written over
/// `AGAIN`: it is the one word in these fixtures that nothing but a block can
/// find, so «protected» there has exactly one possible cause. The first
/// subject tried was «Stefan Keller», and it found a real thing instead: since
/// 085 that is **two** protections and two blocks, so un-protecting the
/// selection exempts the first word and the second word is still a block. That
/// is one name, one word working as designed — and it is why this guard asks
/// about a word that is one token.
#[test]
fn an_exemption_belongs_to_one_conversation() {
    let _guard = serial();
    let ground = Ground::fresh("exempt");
    let (first, number, _safe) = a_line_that_has_left("die erste", LINE);
    let made = blocks();
    let undone = unprotect_every_place(first.0, span_of(LINE, NUMBER)).expect("unprotect");
    assert!(
        matches!(undone, UndoOutcome::Undone { places: 1, .. }),
        "the identifier is not one protection in one place: {undone:?}"
    );
    drop(first);
    ground.restart();
    assert_eq!(blocks(), made, "the exemption deleted the block");

    let over = |bench: SessionId, needle: &str| {
        let got = span_of(AGAIN, needle);
        list_findings(bench)
            .expect("findings")
            .into_iter()
            .find(|f| f.span.start < got.end && got.start < f.span.end)
    };

    // **Here**, where it was exempted: the word is read again, in the same
    // conversation, and nothing finds it at all.
    let again = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(again.0)).expect("enter");
    import_text(again.0, AGAIN.to_string()).expect("import");
    assert!(
        over(again.0, NUMBER).is_none(),
        "the block worked in the conversation it was exempted from: {:?}",
        over(again.0, NUMBER)
    );
    drop(again);

    // **And in another conversation it stands**, because an exemption is not a
    // deletion: this is the one line that tells the two apart — and it is the
    // control for the line above, which would also be green if the block had
    // been deleted or had never been made.
    let elsewhere = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_begin("die zweite".to_string(), Some(elsewhere.0)).expect("begin");
    import_text(elsewhere.0, AGAIN.to_string()).expect("import");
    let there = over(elsewhere.0, NUMBER)
        .expect("the block did not protect its word in a conversation that never exempted it");
    assert_eq!(there.state, MarkState::Protected);
    assert_eq!(there.source, Source::Vault, "something other than the block found it");
}

/// **The count is a count: no door hands out a block's word** — the report's
/// own rule, and the privacy claim under it.
///
/// The snapshot the vault screen reads is asked for a word in every way it can
/// be asked, and answers with a number. The one place a block's value is read
/// is the door back, and what asks for it there is a token out of the person's
/// own document.
#[test]
fn the_blocks_are_counted_and_never_valued() {
    let _guard = serial();
    let _ground = Ground::fresh("counted");
    let (held, _number, safe) = a_line_that_has_left("die Mahnung", LINE);
    let made = blocks();
    assert!(made >= 3, "{made} blocks for three protected words");

    let snapshot = vault_snapshot().expect("snapshot");
    assert_eq!(snapshot.block_count, made);
    // The screen's own rows are the **taught values**, which a person taught on
    // purpose and reviews by name. Nothing was taught here, so there is
    // nothing to show, and the block count is not a row.
    assert!(
        snapshot.taught_values.is_empty(),
        "a block arrived in the taught-values list, where its word is printed"
    );
    assert_eq!(snapshot.value_count, 0, "a block was counted as a taught value");
    assert_eq!(snapshot.identity_count, 0);

    // A shut vault counts none of them, like every other number here.
    drop(held);
    vault_lock().expect("lock");
    let shut = vault_snapshot().expect("snapshot");
    assert_ne!(shut.vault, VaultState::Unlocked);
    assert_eq!(shut.block_count, 0, "a shut vault counted its blocks");
    // And with it shut, the door back brings nothing of its own back either —
    // the blocks are inside it. The sentence a person reads says to unlock it.
    let seen = read_a_document_that_came_back(safe.as_bytes().to_vec(), DocumentKind::Txt)
        .expect("the door stands with the vault shut");
    assert_eq!(seen.brought_back, 0, "a block answered through a locked vault");
    assert_ne!(seen.vault, VaultState::Unlocked);
}

/// **The door back makes no block** — 089 rule 5 meeting rules 1–2, and G34's
/// shape measured as behaviour.
///
/// Reading a document that came back is not protecting anything, so the count
/// does not move and the token places in the file are the same before and
/// after. The door takes no session, so there is no bench for a protection to
/// land on — this is what that shape is worth in numbers.
#[test]
fn the_door_back_makes_no_block() {
    let _guard = serial();
    let _ground = Ground::fresh("doorback");
    let (held, _number, safe) = a_line_that_has_left("die Mahnung", LINE);
    let made = blocks();
    // Asked first, so that «the count did not move» cannot be green because
    // there was no count: 0 == 0 is the shape a_guard_green_for_the_wrong_reason
    // is named for, and this line is what tells the two apart.
    assert!(made >= 3, "nothing became a block, so «the door made none» measures nothing");
    drop(held);

    let before = safe.matches("__Z_").count();
    for _ in 0..3 {
        let seen = read_a_document_that_came_back(safe.as_bytes().to_vec(), DocumentKind::Txt)
            .expect("read back");
        assert_eq!(seen.tokens as usize, before, "the door changed the file's own tokens");
    }
    assert_eq!(blocks(), made, "the door back made a block out of a reading");
}

/// **A block the hand made of two words stays one token** — 089 rule 3's own
/// sentence, and the seam between this round and 085.
///
/// One name, one word binds what the **app** read for itself; a selection is
/// the person's will, so a hand that draws two words gets one token over both
/// (085 ruling 1, and `Source::Vault` is exempt from the law by name). A block
/// made that way is one block, and it has to arrive in the next conversation
/// the same shape it left in — one token over two words, not two tokens.
#[test]
fn a_block_of_two_words_stays_one_token_elsewhere() {
    let _guard = serial();
    let ground = Ground::fresh("twowords");
    // A document the pack finds nothing in, so the hand is the only thing that
    // protects here and the shape measured below is the hand's.
    const PLAIN: &str = "Das Projekt Blaue Mappe läuft weiter.
";
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, PLAIN.to_string()).expect("import");
    conversation_begin("die erste".to_string(), Some(held.0)).expect("begin");
    let drawn = span_of(PLAIN, "Blaue Mappe");
    let outcome = protect(held.0, drawn, Scope::Conversation, Kind::Project).expect("protect");
    let token = match outcome {
        ProtectOutcome::Applied { ref token, .. } => token.clone(),
        other => panic!("the hand did not protect two words: {other:?}"),
    };
    assert_eq!(blocks(), 1, "two words drawn by one hand made {} blocks", blocks());
    drop(held);
    ground.restart();

    // Another conversation reads the same two words.
    const AGAIN_TWO: &str = "Zur Blaue Mappe liegt nichts Neues vor.
";
    let next = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(next.0, AGAIN_TWO.to_string()).expect("import");
    conversation_begin("die zweite".to_string(), Some(next.0)).expect("begin");
    let taken = payload_to_take_out(next.0).expect("take out");
    assert!(
        !taken.text.contains("Blaue Mappe"),
        "the block's two words left the second conversation in the clear"
    );
    // **One token over both words**, which is what «one token» means in the
    // text that leaves: the two words are replaced by one name, and nothing
    // of them is left between two names.
    let standing: Vec<&str> = taken.text.split_whitespace().filter(|w| w.contains("__Z_")).collect();
    assert_eq!(
        standing.len(),
        1,
        "the two words came back as {} tokens in «{}»",
        standing.len(),
        taken.text.trim()
    );
    // And it is this conversation's own name, not the first one's.
    assert_ne!(standing[0], token.as_str(), "the second conversation used the first's name");
    assert_eq!(blocks(), 1, "the same two words made a second block");
}

/// **One press over a selection reaches every block the selection spans** —
/// the lead's ruling of 15 October, closing a seam between 085 and 089.
///
/// Since 085 ruling 1 «Stefan Keller» is **two** protections and therefore two
/// blocks, one per word. The un-protect doors took the first protection the
/// span touched and worked on its token alone, so «in this conversation» over
/// a two-word selection exempted the first word and left the second a working
/// block — a press that did half of what it said. The lead's words: «a
/// selection is the person's will» (085), and the bar already says «That
/// selection spans 2 protected items», so the act follows the selection.
///
/// Measured as the person would meet it: after the press, **neither** word is
/// found from the vault in this conversation, and **both** are in another one.
/// The second half is the control — it is what tells an exemption from a
/// deletion, and it is also what would catch a press that exempted nothing.
#[test]
fn one_press_exempts_every_block_the_selection_spans() {
    let _guard = serial();
    let ground = Ground::fresh("spans");
    let (first, number, _safe) = a_line_that_has_left("die erste", LINE);
    let made = blocks();

    // Two words, one selection, one press.
    let undone =
        unprotect_every_place(first.0, span_of(LINE, "Stefan Keller")).expect("unprotect");
    let places = match undone {
        UndoOutcome::Undone { places, ref tokens, .. } => {
            assert_eq!(
                tokens.len(),
                2,
                "the press named {} token(s) for a selection spanning two: {tokens:?}",
                tokens.len()
            );
            places
        }
        other => panic!("the press undid nothing: {other:?}"),
    };
    assert_eq!(places, 2, "the press uncovered {places} places, not the two it spans");
    assert_eq!(blocks(), made, "the press deleted a block");

    drop(first);
    ground.restart();

    let from_the_vault = |bench: SessionId, needle: &str| {
        let got = span_of(ELSEWHERE, needle);
        list_findings(bench).expect("findings").into_iter().any(|f| {
            f.span.start < got.end && got.start < f.span.end && f.source == Source::Vault
        })
    };

    // Here, where both words were exempted: neither is found from the vault.
    let again = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_enter(number, Some(again.0)).expect("enter");
    import_text(again.0, ELSEWHERE.to_string()).expect("import");
    assert!(
        !from_the_vault(again.0, "Stefan"),
        "the first word of the selection is still a working block here"
    );
    assert!(
        !from_the_vault(again.0, "Keller"),
        "the second word of the selection is still a working block here — the press reached one block of two"
    );
    drop(again);

    // And in another conversation both stand, because an exemption is not a
    // deletion and the press reached no further than the conversation it was
    // made in.
    let elsewhere = Bench(open_session(None, "de".to_string()).expect("open"));
    conversation_begin("die zweite".to_string(), Some(elsewhere.0)).expect("begin");
    import_text(elsewhere.0, ELSEWHERE.to_string()).expect("import");
    assert!(
        from_the_vault(elsewhere.0, "Stefan"),
        "the first word's block does not work in a conversation that never exempted it"
    );
    assert!(
        from_the_vault(elsewhere.0, "Keller"),
        "the second word's block does not work in a conversation that never exempted it"
    );
}

/// **And «here» uncovers every place the selection spans, at its own place
/// only** — the same ruling, for the narrow act.
///
/// «Here» is the one-place direction: it takes the protection off the places
/// the selection covers and leaves every other place of those tokens alone. It
/// too took only the first item it touched. Nothing is written down by this
/// act — «Here»'s memory belongs to the saved document (089 rule 9) — so what
/// is measured is the document: both words are in the clear here, and both are
/// still protected where they stand again.
#[test]
fn here_uncovers_every_place_the_selection_spans() {
    let _guard = serial();
    let _ground = Ground::fresh("here");
    // The name twice, so «here» has somewhere else to leave alone.
    const TWICE: &str = "Herrn Stefan Keller, und Stefan Keller noch einmal.";
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, TWICE.to_string()).expect("import");
    answer_everything(held.0);
    conversation_begin("die erste".to_string(), Some(held.0)).expect("begin");
    let made = blocks();
    // The same floor, for the same reason: «no block was made or deleted» has
    // to be a statement about blocks that exist.
    assert!(made >= 2, "the name made {made} blocks, so this guard measures nothing");

    let at = TWICE.find("Stefan Keller").expect("the fixture");
    let span = Span {
        start: TWICE[..at].chars().map(char::len_utf16).sum::<usize>() as u32,
        end: (TWICE[..at].chars().map(char::len_utf16).sum::<usize>()
            + "Stefan Keller".chars().map(char::len_utf16).sum::<usize>()) as u32,
    };
    let undone = unprotect(held.0, span).expect("unprotect here");
    match undone {
        UndoOutcome::Undone { places, ref tokens, .. } => {
            assert_eq!(places, 2, "«here» uncovered {places} places of the two it spans");
            assert_eq!(tokens.len(), 2, "it named {} of the two tokens: {tokens:?}", tokens.len());
        }
        other => panic!("«here» undid nothing: {other:?}"),
    }
    assert_eq!(blocks(), made, "«here» made or deleted a block");

    // The first two words are in the clear, and the second pair still wears
    // its tokens — which is the whole difference between the two acts.
    let taken = payload_to_take_out(held.0).expect("take out");
    let clear = taken.text.matches("Stefan Keller").count();
    assert_eq!(clear, 1, "«here» left {clear} place(s) in the clear, not one");
    assert!(taken.text.contains("__Z_"), "«here» took the token off every place");
}

/// **A cover comes off before the words leave, and never after** — C-05's own
/// boundary, from the outside claims review of 23 October 2026.
///
/// The reviewer graded C-05 **false** and built the counterexample out of our
/// own tree: the glass carries «Undo protection» (`undoProtection`) and the
/// guide says «Press a protected word and «Undo protection» takes it back»,
/// while the claim's sentence said «can never be unprotected again — not by
/// you». Both are true, of different moments, and nothing in the sentence said
/// which. The sentence now carries the boundary — permanence begins where the
/// hand's choice ends, which is when the words leave — and this guard is that
/// boundary measured, with the reviewer's own counterexample as its first half.
///
/// **What is measured, and nothing else:** before anything has left, the door
/// the button on the glass calls takes the cover back and the value stands in
/// the clear again; once a message has left, **every** door this contract has
/// that takes a cover back leaves what left exactly as it was — the stored
/// form, character for character, and still so after a restart. And the block
/// the press made outlives all of it (rule 2), which is why 102 and this round
/// are a sentence and not a behaviour: «the block is never deleted» was never
/// the same promise as «not by you».
///
/// **The boundary is what left, not the door.** Measured here rather than
/// assumed: the three doors go on working after the send — the text in front
/// of the person is still that text, and a cover on it comes off whenever the
/// hand says so. What no door reaches is the message that has already gone.
/// So the sentence says «what has already left», and not «until it leaves the
/// button works», which would have been a promise about a control.
///
/// The three doors are **enumerated rather than reasoned about**: «no door
/// un-protects what left» is a claim about all of them, and a door nobody
/// called cannot be a control.
#[test]
fn a_cover_comes_off_before_it_leaves_and_never_after() {
    let _guard = serial();
    let ground = Ground::fresh("boundary");
    connect_provider(ProviderId { id: "fake".to_string() }, "k".to_string(), None, None)
        .expect("the echo provider");

    // **The subject is the unlabelled identifier**, for the reason written at
    // the top of this file: nothing in this build finds `8841-2270` with no
    // label in front of it, so the hand's cover is the only thing that ever
    // covers it here — and a cover taken back leaves the word standing in the
    // clear instead of being found again by the next pass.
    let held = Bench(open_session(None, "de".to_string()).expect("open"));
    import_text(held.0, AGAIN.to_string()).expect("import");
    conversation_begin("der Rückruf".to_string(), Some(held.0)).expect("begin");
    let number = conversation_open().expect("open").expect("a session is open");
    assert_eq!(
        blocks(),
        0,
        "the fixture covered something by itself, so the hand is not the only cover in this guard"
    );
    let drawn = span_of(AGAIN, NUMBER);
    assert!(
        inspect_selection(held.0, drawn).expect("inspect").protected_by.is_none(),
        "something already covers the word this guard is about"
    );

    match protect(held.0, drawn, Scope::Conversation, Kind::CustomerNo).expect("protect") {
        ProtectOutcome::Applied { .. } => {}
        other => panic!("the hand did not protect the word: {other:?}"),
    }
    let made = blocks();
    assert_eq!(made, 1, "one press by hand made {made} blocks");

    // **Before it leaves, the cover comes off** — the reviewer's
    // counterexample, at the door `acts.dart`'s «Undo protection» calls.
    match undo_last_protection(held.0).expect("undo") {
        UndoOutcome::Undone { places, .. } => {
            assert_eq!(places, 1, "the undo took {places} places off the one it covered");
        }
        other => panic!("«Undo protection» took nothing back before anything had left: {other:?}"),
    }
    // A view and not a door: nothing may leave in this half of the guard.
    let bare = payload_view(build_payload(held.0).expect("build")).expect("view").text;
    assert!(bare.contains(NUMBER), "the undo did not leave the word in the clear");
    assert!(!bare.contains("__Z_"), "a token is still standing where the undo took the cover off");
    assert_eq!(blocks(), made, "the undo deleted the block the press made");

    // And now it leaves, protected again, by the send.
    match protect(held.0, drawn, Scope::Conversation, Kind::CustomerNo).expect("protect again") {
        ProtectOutcome::Applied { .. } => {}
        other => panic!("the second press did not protect the word: {other:?}"),
    }
    set_question(held.0, "Worum geht es in diesem Brief?".to_string()).expect("question");
    let handle = build_payload(held.0).expect("build");
    ask_model(handle, ProviderId { id: "fake".to_string() }, None, Vec::new()).expect("ask");
    let left = {
        let rows = conversation_turns(number, Some(held.0)).expect("turns");
        assert_eq!(rows.len(), 1, "the send wrote {} turns", rows.len());
        let left = rows[0].question_as_it_left.clone();
        assert!(left.contains("__Z_"), "what left carried no token, so nothing below measures anything");
        assert!(!left.contains(NUMBER), "the word itself left this machine");
        left
    };

    // **And after it left, every door that takes a cover back** — each one
    // with a cover of its own in front of it.
    //
    // The cover is renewed before each door because the first one measured
    // otherwise: the marks are **not** taken off the bench by the send — the
    // preview's saved copy goes (rule 9), the decisions on the text in front
    // of the person do not — so the first door took the mark and the two after
    // it met an uncovered word and answered `NothingToUndo`. A door that found
    // nothing to do is no control at all, so each is given something to take
    // and has to say it took it.
    let mut answers: Vec<String> = Vec::new();
    for (name, which) in [("the last protection", 0u8), ("this place", 1), ("every place", 2)] {
        if inspect_selection(held.0, drawn).expect("inspect").protected_by.is_none() {
            match protect(held.0, drawn, Scope::Conversation, Kind::CustomerNo).expect("cover") {
                ProtectOutcome::Applied { .. } => {}
                other => panic!("the word could not be covered again for «{name}»: {other:?}"),
            }
        }
        let outcome = match which {
            0 => undo_last_protection(held.0),
            1 => unprotect(held.0, drawn),
            _ => unprotect_every_place(held.0, drawn),
        };
        answers.push(format!("{name}: {outcome:?}"));
        assert!(
            matches!(outcome, Ok(UndoOutcome::Undone { .. })),
            "«{name}» had a cover in front of it and took nothing, so it is no control: {outcome:?}"
        );
    }
    let answered = answers.join(" · ");
    let after = conversation_turns(number, Some(held.0)).expect("turns");
    assert_eq!(
        after[0].question_as_it_left, left,
        "a door changed what had already left — {answered}"
    );
    assert_eq!(blocks(), made, "a door after the send deleted the block — {answered}");

    // The bench is gone and the vault is read from the file again: what left
    // is what the file holds, and no door reached it there either.
    drop(held);
    ground.restart();
    let stored = conversation_turns(number, None).expect("turns");
    assert_eq!(
        stored[0].question_as_it_left, left,
        "the file holds something other than what left"
    );
    assert!(stored[0].question_as_it_left.contains("__Z_"), "the stored turn lost its token");
    assert!(!stored[0].question_as_it_left.contains(NUMBER), "the word is in the file in the clear");
    assert_eq!(blocks(), made, "a restart deleted the block");
}
