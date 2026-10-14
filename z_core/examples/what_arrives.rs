//! **What does Z's reader hand over?** The instrument for paper 086.
//!
//!     cargo run -p z_core --example what_arrives --features measuring -- <file> [--lang ar] [--out <path>] [--find «الكتاب,السلام,المجرم»]
//!
//! The feature is not decoration: the one door this instrument needs in the
//! library — `measuring::whole_word_places` — stands behind it, so that a door
//! which exists only to measure is not part of what the product ships. Without
//! `--features measuring` cargo refuses this target by name.
//!
//! 038-C measured the first two faults of the Arabic reading base on the
//! owner's own book — 205 434 presentation-form characters, handed over in
//! visual order — and both are still open. This is how they are measured
//! again, from **inside** the product and on any file: what the reader hands
//! over, what an NFC or an NFKC fold would change about it, and how many places
//! a word the operator names stands in before and after each fold.
//!
//! **It reports; it changes nothing.** No fold reaches the reader, no scan is
//! run, and no vault is told where to look — so nothing a vault holds can get
//! into these numbers — and the session is closed at the end.
//!
//! **The one place a document's text leaves here is `--out`**, a path the
//! operator names, because 086 is a reading he has to be able to do with his
//! own eyes. Everything else printed is a number, a word he asked about, or
//! that word spelt backwards or with two of its letters swapped — never a word
//! the document itself holds.
//!
//! The places a word stands in are counted by the product's own search
//! (`z_core::measuring::whole_word_places`) and by nothing written here:
//! case-blind, across a hyphen the page put inside a word, and with the
//! clitics Arabic writes in front of a name. A `contains` in an instrument
//! would answer a different question and look like an answer to this one.

use std::path::Path;

use unicode_normalization::char::is_combining_mark;
use unicode_normalization::UnicodeNormalization;
use z_core::api::{self, ApiError, DocumentKind};
use z_core::measuring::whole_word_places;

// ---------------------------------------------------------------- the switches

#[derive(Debug)]
struct Args {
    file: String,
    lang: String,
    out: Option<String>,
    find: Vec<String>,
}

/// A word list as the operator types it: commas or Arabic commas between the
/// words, and the guillemets he writes around them are his punctuation, not
/// part of any word.
fn words_of(list: &str) -> Vec<String> {
    list.split([',', '،'])
        .map(|w| w.trim().trim_matches(|c: char| matches!(c, '«' | '»' | '"' | '\'' | ' ')).to_string())
        .filter(|w| !w.is_empty())
        .collect()
}

fn switches() -> Result<Args, String> {
    let mut file: Option<String> = None;
    let mut lang = "de".to_string();
    let mut out = None;
    let mut find = Vec::new();
    let mut rest = std::env::args().skip(1);
    while let Some(arg) = rest.next() {
        match arg.as_str() {
            "--lang" => lang = rest.next().ok_or("--lang needs a pack id")?,
            "--out" => out = Some(rest.next().ok_or("--out needs a path")?),
            "--find" => find = words_of(&rest.next().ok_or("--find needs a word, or a list of them")?),
            other if other.starts_with("--") => return Err(format!("«{other}» is not a switch this instrument knows")),
            other => file = Some(other.to_string()),
        }
    }
    match file {
        Some(file) => Ok(Args { file, lang, out, find }),
        None => Err("no file to read".to_string()),
    }
}

fn kind_of(path: &Path) -> Option<DocumentKind> {
    match path.extension().and_then(|e| e.to_str())?.to_lowercase().as_str() {
        "txt" | "md" | "csv" => Some(DocumentKind::Txt),
        "docx" => Some(DocumentKind::Docx),
        "pdf" => Some(DocumentKind::Pdf),
        _ => None,
    }
}

// ------------------------------------------------------------------ the folds

/// One column of every table below: a name, the text under that fold, and the
/// fold itself — so that a word the operator asks about is folded **the same
/// way as the text it is looked for in**, and each column compares like with
/// like.
struct Fold {
    name: &'static str,
    text: String,
    /// The same text with the marks between the letters gone — 038-C's third
    /// step, the matching view, which that paper is careful to call a view and
    /// not a rewrite. Here it is neither: it is a second count, so that a word
    /// the product cannot find can be asked about with the vowels out of the
    /// way without anything being changed for anybody.
    bare: String,
    fold: fn(&str) -> String,
}

impl std::fmt::Debug for Fold {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        // Numbers only, even here: a `{:?}` on a column must not become a way
        // to print a document.
        write!(f, "Fold({}, {} chars)", self.name, self.text.chars().count())
    }
}

/// The harakat a vowelled book writes between its letters, and the tatweel
/// that stretches a word — dropped by the same clause the core's own edge rule
/// uses for a mark that belongs to the letter in front of it
/// (`is_combining_mark`, 085 ruling 3), so that there is one answer in this
/// tree to «what is a mark» and not two.
fn bare_of(text: &str) -> String {
    text.chars().filter(|c| !is_combining_mark(*c) && *c != '\u{0640}').collect()
}

fn columns(read: &str) -> Vec<Fold> {
    [
        ("as read", read.to_string(), (|s: &str| s.to_string()) as fn(&str) -> String),
        ("NFC", read.nfc().collect(), |s: &str| s.nfc().collect()),
        ("NFKC", read.nfkc().collect(), |s: &str| s.nfkc().collect()),
    ]
    .into_iter()
    .map(|(name, text, fold)| Fold { name, bare: bare_of(&text), text, fold })
    .collect()
}

// ---------------------------------------------------------------- the counting

/// The bidi controls, each by its own code point: a count of «some controls»
/// cannot tell an embedding from an isolate, and the two say different things
/// about who laid the page out.
const BIDI: [(char, &str); 11] = [
    ('\u{200E}', "LRM"),
    ('\u{200F}', "RLM"),
    ('\u{202A}', "LRE"),
    ('\u{202B}', "RLE"),
    ('\u{202C}', "PDF"),
    ('\u{202D}', "LRO"),
    ('\u{202E}', "RLO"),
    ('\u{2066}', "LRI"),
    ('\u{2067}', "RLI"),
    ('\u{2068}', "FSI"),
    ('\u{2069}', "PDI"),
];

#[derive(Debug)]
struct Counts {
    chars: usize,
    words: usize,
    spaces: usize,
    lines: usize,
    lines_unspaced: usize,
    lines_unbroken: usize,
    longest_run: usize,
    readable: usize,
    forms_a: usize,
    forms_b: usize,
    letters: usize,
    harakat: usize,
    bidi: Vec<usize>,
}

impl Counts {
    fn of(text: &str) -> Self {
        let mut c = Counts {
            chars: text.chars().count(),
            words: text.split_whitespace().count(),
            spaces: text.chars().filter(|c| *c == ' ').count(),
            // **The third fault of the reading base, and the one 038-C does
            // not name.** A PDF puts a word where it belongs instead of
            // writing a space, and a reader that hands over a line with no
            // space in it has given us a line nothing can be a word inside —
            // which is the one thing every layer above needs, since a taught
            // name, a vault value and «protect every place» all ask
            // `occurrences`, and `occurrences` asks that a word stand on its
            // own. These four rows are how that is seen without reading a line.
            lines: text.lines().count(),
            lines_unspaced: text.lines().filter(|l| !l.contains(' ')).count(),
            lines_unbroken: text.lines().filter(|l| l.chars().count() > 30 && !l.contains(' ')).count(),
            longest_run: text
                .split([' ', '\n', '\t'])
                .map(|run| run.chars().count())
                .max()
                .unwrap_or(0),
            readable: 0,
            forms_a: 0,
            forms_b: 0,
            letters: 0,
            harakat: 0,
            bidi: BIDI.iter().map(|(control, _)| text.chars().filter(|c| c == control).count()).collect(),
        };
        for ch in text.chars() {
            // The same formula `check_document` prints, so the two instruments
            // can be held against each other. **It counts a presentation form
            // as readable**, because to Unicode it is a letter — which is why
            // that figure stays high while the shapes are still there, and why
            // it is not the measurement 086 wants.
            if ch.is_alphanumeric() || ch.is_whitespace() || ch.is_ascii_punctuation() || "«»—–…".contains(ch) {
                c.readable += 1;
            }
            match ch {
                '\u{FB50}'..='\u{FDFF}' => c.forms_a += 1,
                '\u{FE70}'..='\u{FEFF}' => c.forms_b += 1,
                '\u{0620}'..='\u{064A}' => c.letters += 1,
                '\u{064B}'..='\u{065F}' => c.harakat += 1,
                _ => {}
            }
        }
        c
    }

    fn percent_readable(&self) -> usize {
        self.readable * 100 / self.chars.max(1)
    }

    fn bidi_total(&self) -> usize {
        self.bidi.iter().sum()
    }
}

// ----------------------------------------------------------------- the printing

/// `198 995`, because `198995` is read twice.
fn grouped(n: usize) -> String {
    let digits: Vec<char> = n.to_string().chars().collect();
    let mut out = String::new();
    for (i, d) in digits.iter().enumerate() {
        if i > 0 && (digits.len() - i) % 3 == 0 {
            out.push(' ');
        }
        out.push(*d);
    }
    out
}

/// One value per column, in the columns' own order.
fn by_column(values: impl Iterator<Item = String>) -> Vec<String> {
    values.collect()
}

fn row(label: &str, numbers: &[String]) {
    let mut line = format!("  {label:<36}");
    for n in numbers {
        line.push_str(&format!("{n:>13}"));
    }
    println!("{line}");
}

// ------------------------------------------------------------------ the words

/// The four ways this instrument is allowed to ask «how many».
///
/// `marks` takes the harakat and the tatweel out of the text and out of the
/// word alike. `anywhere` drops the one rule that makes a place a place — so it
/// is **not** the product's number and the table says so where it prints it.
/// It is here because the gap between the two is a measurement in itself: a
/// spelling that stands 173 times in the text and in 5 places is a spelling
/// whose neighbours arrived glued to it.
#[derive(Debug, Clone, Copy, PartialEq)]
struct How {
    marks: bool,
    anywhere: bool,
}

/// How many times `word` is in each column, asked that way — whole-word places
/// through the product's own search, and nothing else through anything else.
fn counted(columns: &[Fold], word: &str, how: How) -> Vec<usize> {
    columns
        .iter()
        .map(|column| {
            let folded = (column.fold)(word);
            let (text, needle) = if how.marks {
                (&column.bare, bare_of(&folded))
            } else {
                (&column.text, folded)
            };
            if needle.is_empty() {
                return 0;
            }
            if how.anywhere {
                text.matches(needle.as_str()).count()
            } else {
                whole_word_places(text, &needle).len()
            }
        })
        .collect()
}

/// Every spelling of `word` this instrument knows how to ask about: the word
/// itself, the word backwards — 038-C measured this reader handing the book
/// over in visual order — and each of its adjacent letters swapped, which is
/// the shape the lead measured outside the product with `pdftotext`
/// («المجرم» arriving as «املجرم»).
///
/// It decides nothing between them. It says which spelling the product can
/// find, and that is the whole question 086 asks of the reader.
fn spellings(word: &str) -> Vec<(String, String)> {
    let letters: Vec<char> = word.chars().collect();
    let mut out = vec![("as given".to_string(), word.to_string())];
    let backwards: String = letters.iter().rev().collect();
    if backwards != *word {
        out.push(("backwards".to_string(), backwards));
    }
    for at in 0..letters.len().saturating_sub(1) {
        let mut swapped = letters.clone();
        swapped.swap(at, at + 1);
        let spelling: String = swapped.iter().collect();
        if spelling != *word {
            out.push((format!("letters {}↔{} «{spelling}»", at + 1, at + 2), spelling));
        }
    }
    out
}

fn main() {
    // Which build said these numbers, so a measurement can be put back to a
    // commit — the stamp the window shows and the copied report carries.
    println!("{}", z_core::core_version());
    let args = match switches() {
        Ok(args) => args,
        Err(why) => {
            println!("{why}");
            println!("usage: what_arrives <file> [--lang <pack>] [--out <path>] [--find «word,word»]");
            return;
        }
    };
    let path = Path::new(&args.file);
    let shown = path.file_name().and_then(|n| n.to_str()).unwrap_or("?");
    let Some(kind) = kind_of(path) else {
        println!("«{shown}» is not a kind this build reads (.txt .md .csv .docx .pdf)");
        return;
    };
    let bytes = match std::fs::read(path) {
        Ok(bytes) => bytes,
        Err(e) => {
            println!("«{shown}» could not be opened: {e}");
            return;
        }
    };
    let session = match api::open_session(None, args.lang.clone()) {
        Ok(session) => session,
        Err(e) => {
            println!("no session: {e}");
            return;
        }
    };

    let installed: Vec<String> = api::packs()
        .map(|packs| packs.iter().map(|p| p.id.clone()).collect())
        .unwrap_or_default();
    println!();
    println!("  file                          {shown}  ·  {} KiB", grouped(bytes.len() / 1024));
    if installed.contains(&args.lang) {
        println!("  pack                          {}", args.lang);
    } else {
        // Said out loud rather than silently ignored: `open_session` takes any
        // pack id, and 086's whole point is that a language is measured before
        // it has a pack.
        println!(
            "  pack                          «{}» is not installed here ({}) — and nothing below reads a pack: \
             no scan is run, and the reader is the same either way",
            args.lang,
            installed.join(" · ")
        );
    }
    println!("  vault                         never told where to look, so nothing it holds is in these numbers");

    let started = std::time::Instant::now();
    let view = match api::import_document(session, shown.to_string(), bytes, kind) {
        Ok(view) => view,
        Err(ApiError::DocumentRefused { reason, detail }) => {
            // The reason names a font or a filter: the structure of the file,
            // and not a word of anybody's text — and it is the whole use of an
            // instrument when a document is refused.
            println!("  refused                       {reason:?}\n                                {detail}");
            let _ = api::close_session(session);
            return;
        }
        Err(other) => {
            println!("  refused                       {other}");
            let _ = api::close_session(session);
            return;
        }
    };
    let read_ms = started.elapsed().as_millis();
    println!("  read                          {} pages  ·  {read_ms} ms", view.pages);

    // **The reader is not touched**: the folds are made here, from the text it
    // handed over, so that 086 can see which fold would change what before
    // anything at all is decided.
    let columns = columns(&view.text);
    let counts: Vec<Counts> = columns.iter().map(|column| Counts::of(&column.text)).collect();
    let header = by_column(columns.iter().map(|column| column.name.to_string()));

    println!();
    row("", &header);
    row("characters", &by_column(counts.iter().map(|c| grouped(c.chars))));
    row("words", &by_column(counts.iter().map(|c| grouped(c.words))));
    row("spaces", &by_column(counts.iter().map(|c| grouped(c.spaces))));
    row("lines", &by_column(counts.iter().map(|c| grouped(c.lines))));
    row("lines with no space", &by_column(counts.iter().map(|c| grouped(c.lines_unspaced))));
    row("lines over 30 with no space", &by_column(counts.iter().map(|c| grouped(c.lines_unbroken))));
    row("longest run with no space", &by_column(counts.iter().map(|c| grouped(c.longest_run))));
    row("readable", &by_column(counts.iter().map(|c| format!("{}%", c.percent_readable()))));
    row("forms  FB50–FDFF", &by_column(counts.iter().map(|c| grouped(c.forms_a))));
    row("forms  FE70–FEFF", &by_column(counts.iter().map(|c| grouped(c.forms_b))));
    row("letters  0620–064A", &by_column(counts.iter().map(|c| grouped(c.letters))));
    row("harakat  064B–065F", &by_column(counts.iter().map(|c| grouped(c.harakat))));
    row("bidi controls", &by_column(counts.iter().map(|c| grouped(c.bidi_total()))));
    for (at, (control, name)) in BIDI.iter().enumerate() {
        let each = by_column(counts.iter().map(|c| grouped(c.bidi.get(at).copied().unwrap_or(0))));
        if each.iter().any(|n| n != "0") {
            row(&format!("    U+{:04X} {name}", *control as u32), &each);
        }
    }
    if counts.iter().all(|c| c.bidi_total() == 0) {
        // A zero by itself does not say what was looked for, and «by code
        // point» has to hold when the answer is none of them.
        println!(
            "      none of {}",
            BIDI.iter().map(|(_, name)| *name).collect::<Vec<_>>().join(" ")
        );
    }
    println!();
    println!("  «readable» is check_document's own formula, so that the two instruments compare — and a");
    println!("  presentation form is a letter to it, which is why that figure can stand at 97% while every");
    println!("  shape is still wrong. The rows under it are the ones 086 reads, and so are the three about");
    println!("  spaces: a word with no space beside it is a word nothing can find, whatever shape it is in.");

    if !args.find.is_empty() {
        println!();
        println!("  places each word stands in, counted by the product's own whole-word search");
        println!("  (· marks — the harakat and the tatweel out of the text and out of the word alike)");
        println!("  (· anywhere — the spelling wherever it stands, inside a longer run too. **Not a place.**");
        println!("   The gap between a row and its «anywhere» is what the reader glued together.)");
        row("", &header);
        for word in &args.find {
            for (how_spelt, spelling) in spellings(word) {
                let mut already: Vec<Vec<usize>> = Vec::new();
                for how in [
                    How { marks: false, anywhere: false },
                    How { marks: true, anywhere: false },
                    How { marks: false, anywhere: true },
                    How { marks: true, anywhere: true },
                ] {
                    let found = counted(&columns, &spelling, how);
                    let as_given = how_spelt == "as given";
                    let plainest = how == How { marks: false, anywhere: false };
                    // The word as the operator gave it is printed whether it
                    // stands anywhere or not — a zero he asked for is an
                    // answer. Everything else is printed only when it says
                    // something a row above it did not.
                    let worth_saying = (as_given && plainest)
                        || (found.iter().any(|n| *n > 0) && !already.contains(&found));
                    if !worth_saying {
                        continue;
                    }
                    already.push(found.clone());
                    let mut label = if as_given {
                        format!("«{word}»  {how_spelt}")
                    } else {
                        format!("        {how_spelt}")
                    };
                    if how.marks {
                        label.push_str(" · marks");
                    }
                    if how.anywhere {
                        label.push_str(" · anywhere");
                    }
                    row(&label, &by_column(found.iter().map(|n| grouped(*n))));
                }
            }
        }
    }

    if let Some(out) = &args.out {
        println!();
        match std::fs::write(out, &view.text) {
            Ok(()) => println!("  the text it read, as it read it, is in {out}"),
            Err(e) => println!("  the text could not be written to {out}: {e}"),
        }
    }

    let _ = api::close_session(session);
}
