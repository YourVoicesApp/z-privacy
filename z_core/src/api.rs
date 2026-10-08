//! The contract. The only surface the UI may call.
//!
//! Four rules hold for every line in this file, and `scripts/gates.sh` checks
//! all four:
//!
//! * **Every function returns [`ApiResult`].** No panic crosses the boundary —
//!   not even for "impossible" states, which are errors here, not aborts.
//! * **No function that sends accepts text.** Sending takes a [`PayloadHandle`];
//!   the outgoing text is built here and never handed back in.
//! * **No key or passphrase-derived secret crosses the boundary.** The vault is
//!   opened with a passphrase and the master key never leaves this crate.
//! * **Signatures sit on one line**, so the gates can read them without a parser.
//!
//! ## Offsets are UTF-16
//!
//! Dart strings are UTF-16. A selection made in Flutter counts code units, not
//! bytes, so [`Span`] is in UTF-16 code units and this crate converts to byte
//! offsets internally. A span that lands inside a character — `ü`, an emoji —
//! is [`ApiError::BadSpan`], never a silent cut.

use std::fmt;

/// Every call can fail, and says how.
pub type ApiResult<T> = Result<T, ApiError>;

/// What can go wrong on the surface. Never a panic.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ApiError {
    /// The function exists in the contract but its stage has not been built yet.
    NotImplemented,
    /// No such session, or it was closed.
    InvalidSession,
    /// No such payload.
    InvalidHandle,
    /// The document changed after this payload was built. Build a new one.
    StalePayload { expected: u32, got: u32 },
    /// The vault must be opened before this can be answered.
    VaultLocked,
    /// The chosen provider has no key, or is not reachable.
    ProviderUnavailable { provider: String },
    /// Suggestions are still unanswered; there is no way past them.
    OpenSuggestions { count: u32 },
    /// What was given cannot be used, and why: an empty value, a name left
    /// blank, a passphrase too short, a credential missing where one is
    /// needed, a scope that does not apply in this conversation.
    ///
    /// The person's next move is to change what they entered.
    InputRefused { reason: String },
    /// Something was named that is not here — a profile, a rule set, a pack, a
    /// taught rule. `UnknownToken` is this same shape for a token in a session.
    ///
    /// The person's next move is to name something else.
    NotFound { reason: String },
    /// There is no vault on this device yet, so there is nothing to open, to
    /// change, or to keep anything in.
    ///
    /// Three neighbours, deliberately apart: this one means **there is none**,
    /// `VaultLocked` means there is one and it is shut, and `VaultRequired`
    /// means an act needs one open and none is.
    VaultAbsent,
    /// A vault is already on this device, and making another would write over
    /// it. Refused rather than merged: there is no way back from that.
    VaultAlreadyExists,
    /// A place Z Privacy keeps its **own** files cannot be used safely — a
    /// symlink where a directory belongs, permissions that let someone else
    /// read it, a temporary file left by another program.
    ///
    /// Nothing the person typed is wrong here, so it is not `InputRefused`.
    StorageRefused { reason: String },
    /// **Another copy of Z Privacy changed this vault since this one read it.**
    ///
    /// Its own variant, and not `StorageRefused`, because the place is fine:
    /// the folder is writable, the file is intact, and a second window of this
    /// program wrote to it. 050/A — the first answer to the owner's two-copies
    /// attack refused with `StorageRefused`, which renders as «Z Privacy will
    /// not use that location», and the location was never the trouble. It
    /// carries no reason because there is only one: a person does not need a
    /// byte count to be told to close the other window.
    VaultChangedElsewhere,
    /// **Z Privacy could write here and is declining to, because the person
    /// said otherwise.**
    ///
    /// The folder that holds Z's own files has had a permission taken off it.
    /// `secure_dir` used to set `0o700` unconditionally on every write path, so
    /// from `0o500` it **gave Z back the write bit the person removed, in
    /// silence** — under a comment that called the line «narrowing» (058).
    ///
    /// Its own variant, and not `StorageRefused`, because the next move is a
    /// different one: `StorageRefused` means *choose somewhere else*, and this
    /// means *change the permission yourself, or choose somewhere else — and
    /// know Z will not change it for you.* The deeper reason is that Z is not
    /// refusing the folder at all: the folder is perfectly usable, and Z is
    /// deferring to a decision. A variant that cannot say that is the wrong
    /// variant. **One variant per next move, not per cause** (the lead,
    /// 8 October 2026).
    ///
    /// **The sentence must carry the promise** — that Z will not change a
    /// permission the person set. Naming the cause and omitting the promise
    /// says the small half.
    StoragePermissionsKept { reason: String },
    /// A document was not imported, with the named reason and a detail for the
    /// user («page 3 of 20 has no text layer»).
    DocumentRefused { reason: Refusal, detail: String },
    /// A span outside the text, reversed, or inside a character.
    BadSpan { reason: String },
    /// No such token in this session.
    UnknownToken,
    /// Nothing is protected and nothing is written; there is nothing to build.
    NothingToSend,
    /// The built payload failed the core's own leak audit and was thrown away.
    /// This should never reach a user; if it does, the bug stayed inside.
    PayloadRefused { reason: String },
    /// The network did not carry the question, and why. Never a response body:
    /// a provider's error page can quote the request back, so nothing that comes
    /// off the wire is allowed into this message.
    NetworkRefused { reason: NetworkRefusal, detail: String },
    /// A vault file asked for KDF costs this build does not support.
    UnsupportedKdfParameters { reason: String },
    /// A vault file had bytes after the end of the versioned ZVLT structure.
    TrailingVaultData,
    /// The vault could not be authenticated after key derivation.
    ///
    /// This does not distinguish a wrong passphrase from a modified vault: the
    /// AEAD tag proves only that opening failed, not which human story caused it.
    VaultAuthenticationFailed,
    /// This payload handle already drove a send, or is driving one now.
    PayloadAlreadySent,
    /// The act needs an open vault — Always, Profile, or anything kept for tomorrow —
    /// and there is not one. Named so a press that cannot keep its promise cannot
    /// look like success.
    VaultRequired,
    /// **A press in the whitespace between two columns** (046/Q). The span was
    /// read without trouble; there is simply no value where it points, and
    /// resolving it to the nearest cell would be the app choosing a column for
    /// the person.
    ///
    /// Not `BadSpan`: that one means a selection this crate could not read — out
    /// of range, reversed, or cut through a character — and its sentence tells
    /// the person to select again, which is wrong advice here. The same
    /// reasoning that split `ImportRefused` on 30 September: a different story
    /// needs a different type, because the screen can only say why if the type
    /// says why.
    BetweenColumns,
}

/// Why a request did not complete. Numbers and names only, by construction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum NetworkRefusal {
    /// This provider has no credential in this run.
    NotConnected,
    /// The address is not `https`, and is not a machine on this computer.
    InsecureUrl,
    /// The host answered with a redirect. We do not follow one: the safe payload
    /// and the credential were addressed to *this* host and go nowhere else.
    Redirected { status: u32 },
    /// The host answered, but not with an answer.
    BadStatus { status: u32 },
    /// Nothing came back in time.
    Timeout { millis: u32 },
    /// The answer was longer than we accept.
    ResponseTooLarge { limit_kib: u32 },
    /// The outgoing text is longer than this provider accepts. Checked **before**
    /// a socket is opened, so a huge document is refused here rather than turned
    /// into an unreasonable request. (Task 021.)
    PayloadTooLarge { kib: u32, limit_kib: u32 },
    /// The answer arrived but is not the shape this provider promised.
    Unreadable,
    /// The host could not be reached at all.
    Unreachable,
}

impl fmt::Display for ApiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NotImplemented => write!(f, "not implemented yet"),
            Self::InvalidSession => write!(f, "no such session"),
            Self::InvalidHandle => write!(f, "no such payload"),
            Self::StalePayload { expected, got } => {
                write!(f, "payload is stale: built on revision {got}, session is at {expected}")
            }
            Self::VaultLocked => write!(f, "the vault is locked"),
            Self::ProviderUnavailable { provider } => write!(f, "provider {provider} is not available"),
            Self::OpenSuggestions { count } => write!(f, "{count} suggestions are still unanswered"),
            Self::InputRefused { reason } => write!(f, "that cannot be used: {reason}"),
            Self::NotFound { reason } => write!(f, "that is not here: {reason}"),
            Self::VaultAbsent => write!(f, "there is no vault on this device yet"),
            Self::VaultAlreadyExists => write!(f, "a vault already exists on this device"),
            Self::StorageRefused { reason } => write!(f, "that place cannot be used safely: {reason}"),
            Self::VaultChangedElsewhere => {
                write!(f, "another copy of Z Privacy changed this vault")
            }
            Self::StoragePermissionsKept { reason } => {
                write!(f, "a permission you set was kept, so nothing was written: {reason}")
            }
            Self::DocumentRefused { reason, detail } => {
                write!(f, "this document was not imported ({reason:?}): {detail}")
            }
            Self::BadSpan { reason } => write!(f, "bad selection: {reason}"),
            Self::BetweenColumns => write!(f, "that point is between two columns and names no value"),
            Self::UnknownToken => write!(f, "no such token in this session"),
            Self::NothingToSend => write!(f, "there is nothing to send"),
            Self::PayloadRefused { reason } => write!(f, "this payload was refused by its own audit: {reason}"),
            Self::NetworkRefused { reason, detail } => {
                write!(f, "the request did not go through ({reason:?}): {detail}")
            }
            Self::UnsupportedKdfParameters { reason } => write!(f, "unsupported vault KDF parameters: {reason}"),
            Self::TrailingVaultData => write!(f, "the vault file has data after the end of the ZVLT structure"),
            Self::VaultAuthenticationFailed => {
                write!(f, "could not unlock the vault; the passphrase may be incorrect, or the vault may be corrupted or modified")
            }
            Self::PayloadAlreadySent => write!(f, "this payload has already been sent"),
            Self::VaultRequired => write!(f, "this needs an open vault"),
        }
    }
}

impl std::error::Error for ApiError {}

// ---------------------------------------------------------------- identifiers

/// A conversation. Everything below hangs off one of these.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SessionId {
    pub id: u32,
}

/// The session's revision. Any change that affects the safe text bumps it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Revision {
    pub n: u32,
}

/// A built payload, by reference. The text itself stays in the core.
///
/// It carries the revision it was built on: after any change to the session it
/// is stale and [`send`] refuses it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PayloadHandle {
    pub id: u32,
    pub session: u32,
    pub revision: u32,
}

/// Which provider to talk to. A newtype, not a `String`, so that no signature
/// on the send path carries free text at all.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderId {
    pub id: String,
}

/// Why something is protected, in words a person can judge.
///
/// The owner's ninth question, 28 September:
///
/// > If I taught Z Privacy something today, can I know tomorrow exactly what it
/// > learned, why, where it applies — and make it forget completely?
///
/// «Source: Vault» is technically true and answers nobody. The rule this type
/// exists to keep is: **there is no protection whose origin we cannot explain**
/// — and the danger it exists to prevent is the one worse than any of the eight
/// lies: local knowledge piling up until the user no longer knows why the app
/// behaves as it does, and a privacy product quietly becomes a black box.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Explanation {
    /// «You taught this value» · «German privacy rule» · «You protected this
    /// by hand» · «A shape that needs no language».
    pub headline: String,
    /// The particulars, one per line: «Valid IBAN checksum», «German label:
    /// Mobil», «Two rules agree». Empty is not allowed to happen — a protection
    /// with nothing to say about itself is the black box arriving.
    pub because: Vec<String>,
    pub kind: Kind,
    pub scope: Scope,
    /// Where it applies: «This document only» · «Client Nordstern» · «Everywhere».
    pub applies: String,
    /// Whether a person decided this, or a layer did.
    pub decided: bool,
    pub token: String,
    /// When it was taught, in seconds since 1970. 0 when it was not taught at
    /// all (a rule found it) or when the vault predates the date being kept.
    pub learned_at: u64,
    /// The identity and value it came from, when the vault taught it. This is
    /// what «Edit» and «Forget» act on.
    pub entity: Option<u32>,
    pub value_id: Option<u32>,
    /// Other spellings of the same value. Shown behind one tap, like every
    /// other value in this app.
    pub aliases: Vec<String>,
    /// The reach of the taught value, when one was taught — so the «Forget»
    /// button can carry its own scope in its name instead of leaving a person
    /// to assemble the meaning from a line of small print. `None` when nothing
    /// was taught, which is the same case as `entity`/`value_id` being `None`.
    pub taught_reach: Option<TaughtReach>,
}

/// Where the **taught value** lives — which is what «Forget» acts on, and a
/// different question from `Explanation::applies` (the reach of the protection
/// standing here).
///
/// A reach, never a client: the profile's **name** is deliberately absent, for
/// the same reason it is absent from `applies` — a name belongs where a person
/// chooses or manages a profile, not in an explanation. The screen needs only
/// enough to name its own button truthfully.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TaughtReach {
    /// The identity holding it belongs to one profile.
    ThisProfile,
    /// It belongs to no profile, so every profile knows it.
    Everywhere,
}

/// What forgetting something would take away — shown **before** it happens.
///
/// «Forget» has to mean forget. Not «we removed the alias but another rule
/// still recognises it», and not «we removed the identity but an old rule
/// still protects it». So the plan counts every local relation, and
/// `still_known_by` is the check that there are none left afterwards.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ForgetPlan {
    /// What it is, so the sheet can name it back to the user.
    pub what: String,
    pub values: u32,
    pub aliases: u32,
    /// Identities that would be left holding nothing, and so go too.
    pub identities: u32,
    /// The profiles it is associated with, by name.
    pub profiles: Vec<String>,
    /// What is **not** touched, said out loud because the user is about to
    /// press a button that says «forget».
    pub keeps: Vec<String>,
    /// Permanent knowledge that could recognise this value **in future**.
    ///
    /// The definition is strict on purpose (the owner, 28 Sep). Empty means:
    /// *no permanent knowledge **in the current vault** will recognise this
    /// value again.* It is not a claim about every copy of the vault that has
    /// ever existed: an older valid one may be restored and bring the value
    /// back, which is F-02 and is stated as an accepted limitation rather than
    /// quietly contradicted here. It does
    /// **not** mean the value is nowhere in the program — the open
    /// conversation's token store still holds it, and an answer already
    /// received still reads as it did. Those are not knowledge for tomorrow;
    /// they are today's work, and `keeps` says so in words.
    ///
    /// Must be empty after forgetting. Reported rather than assumed, and both a
    /// test and the screen check it.
    pub still_known_by: Vec<String>,
}

/// What a selection is, before anything is done to it.
///
/// This type exists because the design boards give the Protect button **five**
/// states, and a screen may not work out which one it is in. Every field below
/// is a question the core is better placed to answer than a widget: is this
/// already protected, does the vault know it, would protecting it snap to whole
/// items, how many places would «all matches» take, and what kind does the pack
/// think it is. (Task 024.)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SelectionView {
    /// Empty when the span holds nothing but space.
    pub empty: bool,
    /// The pack's guess. `Custom` when nothing recognised it.
    pub kind: Kind,
    /// How many places this exact value stands in this document, protected or
    /// not. 1 means «all matches» is the same act as «protect», and the button
    /// hides its count.
    pub matches: u32,
    /// The token, when this exact stretch is already protected. Then the only
    /// act offered is Undo.
    pub protected_as: Option<String>,
    pub protected_by: Option<Source>,
    /// «Z Vault · CLIENT #17», «de:salutation», «selected by you» — the why.
    pub protected_detail: String,
    /// The identity the vault knows this value under, when it knows one. Two or
    /// more is a conflict the app must put to the user, never settle itself.
    pub entities: Vec<String>,
    /// The whole protected items this selection cuts into. Non-empty means
    /// Protect would snap to these instead of taking the selection as drawn.
    pub snaps_to: Vec<Span>,
    /// What Protect will actually take: the selection grown out to whole words
    /// and tidied of the marks at its edges (041-K). The same as the span that
    /// was asked about whenever that one was already whole, and the screen
    /// draws **this** so what is highlighted is what will happen.
    pub word_span: Span,
    /// The capitalised word standing one space before it — «Björn» in front of
    /// «Sandström». An offer the bubble makes and a person answers; the core
    /// never takes it unasked.
    pub also_before: Option<Span>,
}

/// What the app has been told to do by itself.
///
/// Where these live is decided by one rule and no other: **gate G15 says the
/// sealed vault is the only file this core writes.** So a setting is kept in the
/// vault when one is open, and in memory for this run when there is none — the
/// same two homes a provider credential has, and `session_only` says which.
///
/// That is also why `first_run_done` can be false again on a device with no
/// vault: nothing was written, so nothing is remembered. The screen says so
/// rather than pretending otherwise.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Settings {
    /// How much of the Workspace's width the Original column takes, 20 to 80.
    /// A window's preference, kept per device beside the first-run flag, and
    /// readable with no vault — the two columns are drawn long before one.
    pub original_pane_percent: u32,
    /// Do the two columns scroll together? On by default (041-L).
    pub columns_in_step: bool,
    /// Is the Safe column open? On by default (046/K).
    ///
    /// **The owner's standing rule, 7 October:** «بشرط أن الطوي والفتح لا يتم
    /// تلقائياً، يتم بالضغط على إشارة محددة» — a collapse or an expand is
    /// always a person's press on a visible control, and the app never folds
    /// or unfolds anything by itself. A state nothing but a person may change
    /// has to be remembered, or closing the program would change it for them.
    pub safe_column_open: bool,
    /// Is the side panel at its wider width? Narrow by default, which is the
    /// width it has always had (046/K, the same rule).
    pub review_panel_wide: bool,
    /// Scan the moment a document arrives, with no dialog. On by default: the
    /// boards' rule is that nobody has to press anything to be protected.
    pub scan_on_import: bool,
    /// How long a revealed value stays on screen.
    pub reveal_seconds: u32,
    /// Lock the vault after this many minutes of not being used. 0 = never.
    /// Enforced **in the core**, not by a timer in the UI: a screen that forgot
    /// to count would leave the vault open, and nobody would know.
    pub auto_lock_minutes: u32,
    /// The detection pack a new session starts with.
    pub pack_id: String,
    /// The working language, `en` or `de`.
    ///
    /// **What it selects in v1, exactly:** the language of the First Run page,
    /// and the rule set a new session starts with. It does **not** translate
    /// the interface, which is English. The field is named `ui_language` in the
    /// settings file; that name describes what it will govern, not all it
    /// governs today, and the First Run page says so out loud rather than
    /// letting a person infer a translated app from choosing «Deutsch».
    ///
    /// It is also not «the rule set»: more than one set can run in a scan
    /// (M7.10A), so this picks a starting point, not the only engine allowed.
    pub language: String,
    /// False until the first-run page has been passed.
    pub first_run_done: bool,
    /// True when all of the above will be gone when the app closes, because
    /// there is no vault to keep them in.
    pub session_only: bool,
}

/// One kind of value, as something to draw rather than something to enumerate.
///
/// The owner's rule of 27 September: **a screen must not assume that Person,
/// Company, IBAN and Phone are all the kinds there can be.** So the list comes
/// from here, with its labels, and a UI draws whatever it is handed. When
/// user-made kinds arrive they appear as more rows with `custom: true`, and no
/// screen has to change to show them.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct KindRow {
    pub kind: Kind,
    /// What to call it. The core's word, not the screen's.
    pub label: String,
    /// True for a kind the user made. Always false today; the field exists so
    /// that the day it is true, nothing above it needs rewriting.
    pub custom: bool,
}

/// A profile, as a row rather than a packed string. The UI must never have to
/// split a field out of text to draw a name. (Task 022.)
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProfileRow {
    pub id: String,
    pub name: String,
    /// The rule sets switched on for this client's documents. A firm that works
    /// in two languages runs both **in one scan**, so this is a list.
    pub languages: Vec<String>,
}

/// One rule set this build carries, named by itself.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuleSetRow {
    pub id: String,
    pub label: String,
    /// How many label rules it carries. Counted, never written down — a number
    /// on a screen must have a source (§2 of the invariants).
    pub rules: u32,
}

/// A label rule the person taught, as a screen shows it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LabelRuleRow {
    pub id: u32,
    /// The word as they typed it.
    pub label: String,
    pub kind: Kind,
    /// `None` is everywhere; `Some` names the profile it belongs to.
    pub profile_id: Option<String>,
    pub profile_name: Option<String>,
    /// Days since the epoch, 0 when unknown — never today's date guessed in.
    pub learned_at: u64,
}

/// An installed detection pack. The **label is the pack's own**, not the UI's: a
/// screen may not invent the name of a rules engine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackRow {
    pub id: String,
    pub label: String,
    /// `de-DE`, `sv-SE` — the full locale, where this language has a name pack.
    /// Empty where it has label rows only, which English does: a pack is not
    /// required to carry names, and saying so is better than inventing a
    /// locale for a list of words.
    pub locale: String,
    /// The pack's own version, so a report can say which knowledge produced a
    /// finding.
    pub version: String,
    /// Rules this language needs that no other language can use, by name.
    ///
    /// The honest measure of the contract. German declares three — a national
    /// vehicle plate, a local telephone number written after the German word
    /// for telephone, a German street line — and Swedish declares none, which
    /// is what «the second language is data» means in a number.
    pub own_rules: Vec<String>,
    /// One line naming the sources of its name lists and their licences.
    pub provenance: String,
    /// How many given and family names it ships with.
    pub given: u32,
    pub family: u32,
}

/// What a model said, and what the request cost.
///
/// The protected path also keeps the answer in the core and returns its id, so
/// the restored view is reachable the way it always was: `answer` is `Some`
/// there and `None` for a direct request, which has nothing to restore.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelAnswer {
    pub answer: Option<AnswerId>,
    /// The model's words as they arrived. For a protected request this is the
    /// text with tokens still in it — the restored view is a different call,
    /// and this one is what the model actually wrote.
    pub text: String,
    pub usage: ModelUsage,
}

/// What one request to a model cost, as the provider reported it.
///
/// Enough to tell a person what happened, and the ground a managed
/// subscription would one day stand on. What it deliberately does **not**
/// carry is the prompt: a usage record that stored the question would be a
/// second copy of the document, kept for accounting.
///
/// A number the provider did not state is `0`, and `0` means «not stated»
/// rather than «none» — a figure we were not given is not a figure we invent.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelUsage {
    pub provider_id: String,
    pub model_id: String,
    pub input_units: u32,
    pub output_units: u32,
    /// How long the request took, end to end, in milliseconds.
    pub millis: u32,
    pub ok: bool,
}

/// What a model can be asked to do.
///
/// Named capabilities rather than model names, because a screen that knows
/// «gpt-4o can see pictures» is a screen that has to be edited every time a
/// company ships something. The UI asks what a model can do; the catalogue
/// answers.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ModelCapability {
    /// Text in, text out. Every model in V1 has this and only this is used.
    Text,
    /// Accepts images as well as text.
    Vision,
    /// Can be given tools to call.
    Tools,
    /// Asked to reason at length before answering.
    Reasoning,
}

/// One model a provider offers, as the catalogue states it.
///
/// The gateway's unit of choice. A provider is **where** a request goes; a
/// model is **what** answers it; a credential is what opens the door. Keeping
/// the three apart is the whole of why a second provider is a file and not a
/// rewrite — and why the screens below never name a model of their own.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelDescriptor {
    pub provider_id: String,
    pub model_id: String,
    /// What a person reads in a list.
    pub display_name: String,
    pub capabilities: Vec<ModelCapability>,
    /// The context window the provider states, in thousands of tokens. 0 where
    /// the provider does not say — a number we do not have is not a number we
    /// invent.
    pub context_k: u32,
    /// Whether this model, at this provider's address, needs a credential.
    pub credential_required: bool,
    /// Usable in this run: the provider is connected, or needs no credential.
    pub available: bool,
}

/// A provider as the UI is allowed to see it: a name, and whether it is
/// connected. The credential itself is not in this type and has no getter
/// anywhere in the contract — once given, it never comes back out.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderRow {
    pub id: String,
    pub label: String,
    /// True when this provider can be used at this address in this run.
    pub connected: bool,
    /// True when that usable connection lives only in memory, because there was
    /// no open vault to seal it into. It is gone when the app closes, and the UI
    /// says so rather than letting the user believe it was saved.
    pub session_only: bool,
    /// Where requests go. Editable, so a local model on this machine can be used.
    pub base_url: String,
    /// Which model is asked. Not a secret, and shown so the answer can be read
    /// knowing what produced it.
    pub model: String,
    /// Whether this provider, **at this address**, needs a credential at all.
    ///
    /// A property of the provider, not a rule of the world (the owner, 27 Sep):
    /// a model on this machine needs none, and a future provider may authorise
    /// some other way. A screen asks this instead of assuming.
    pub credential_required: bool,
}

/// Where a provider credential actually lives.
///
/// Never inferred from `connected`, and never from the login record either: a
/// record with an empty credential is `Missing`, because a provider that needs
/// no key holds none.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CredentialState {
    /// No credential is stored for this provider, in the vault or in memory.
    Missing,
    /// Kept in process memory for this run only.
    SessionOnly,
    /// Sealed inside the vault.
    EncryptedInVault,
}

/// How the document last came to be scanned. The band reads this; it does not
/// remember how it was first opened.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScanOrigin {
    NotScanned,
    OnImport,
    Rescan,
}

/// One answer that came back from a provider.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AnswerId {
    pub id: u32,
}

/// A range in the document, in **UTF-16 code units** (Dart's own counting).
///
/// `u32`, not `usize`: frb hands `usize` to Dart as `BigInt`, and no document
/// has four billion code units.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Span {
    pub start: u32,
    pub end: u32,
}

// ---------------------------------------------------------------- vocabulary

/// How long a protection lasts.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
/// How far a protection reaches. Four steps, each one wider than the last, and
/// each one **doing** what it says (task 034).
///
/// Until then `Conversation` and `Always` were labels: the breadth came from
/// whether `protect` or `protect_all_matches` was called, and `Always` promised
/// the vault while nothing ever wrote to it. The dialog said «kept in the vault
/// and found by itself from now on» and the app did not do it — which is the
/// worst kind of untruth a privacy product can tell, because the user stops
/// watching for what they think is handled.
pub enum Scope {
    /// This one place, and nothing else.
    Once,
    /// Every appearance in this conversation, under one token. Gone when the
    /// conversation is.
    Conversation,
    /// Every appearance here, **and kept in the vault under the profile this
    /// conversation is in** — so it is found by itself in that client's next
    /// document, and in no other client's.
    ///
    /// The level a firm with several clients needs: what you learn about one of
    /// them does not become a rule about all of them.
    Profile,
    /// Every appearance here, and kept in the vault for **every** profile.
    Always,
}

/// What kind of thing a value is. It travels in the token name on purpose: the
/// model must know it is answering about a bank account, not a name.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Kind {
    Person,
    Company,
    Email,
    Phone,
    /// An IBAN — an account, internationally addressed.
    Iban,
    /// A bank's own identifier (SWIFT/BIC). Not an IBAN, and not the same secret.
    Bic,
    /// A plain account number, as a German letter writes it after «Kontonummer:».
    Account,
    TaxId,
    CustomerNo,
    Address,
    Contract,
    Project,
    Client,
    /// A national identity card number — `Personalausweisnummer L01X00T47`.
    IdCard,
    /// A date of birth. The date alone: «geboren am» stays in the clear, as a
    /// salutation does, so the sentence still reads.
    Birthdate,
    /// A vehicle's registration plate.
    Vehicle,
    /// A German social-insurance number — *Sozialversicherungsnummer*, the one
    /// a payslip carries: an area number, the bearer's birth date, the first
    /// letter of their birth name, a serial and a check digit over all of it.
    ///
    /// It carries a birth date inside it, so it is not only an identifier: a
    /// person whose number is read has had their date of birth read with it.
    SocialInsuranceNo,
    /// A personnel number — *Personalnummer*, what a payroll ledger calls an
    /// employee. Not a customer number: the word is read twice, once in the
    /// explain card and once in the token the model is asked about, and
    /// «customer» is wrong in both on a payslip.
    EmployeeNo,
    Custom,
}

/// Which layer decided. The user must be able to see why a word was hidden.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Source {
    /// Shapes that need no language: an IBAN, an e-mail, a postcode.
    GeneralRule,
    /// The habits of one language: Herr, Frau, GmbH, Kundennummer.
    LanguagePack,
    /// Your own people and things.
    Vault,
    /// You selected it.
    Hand,
}

/// Protected already, or still waiting for the user's word.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MarkState {
    Protected,
    Suggested,
}

/// Is the vault open?
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VaultState {
    /// There is no vault on this device yet.
    Absent,
    /// It exists and is sealed. The vault layer is skipped entirely while it is.
    Locked,
    Unlocked,
}

/// The formats a document may arrive in. More are added by adding a reader, not
/// by loosening a rule.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DocumentKind {
    Txt,
    Docx,
    Pdf,
}

/// Why a document was not imported. Named, never a general «it failed»: the user
/// is owed the reason, and a scanned page is a different problem from a corrupt
/// file or an encrypted one.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Refusal {
    /// Pages with no text layer at all — a photograph of a document. We do not
    /// guess, and we do not send it anywhere to be read.
    ScannedPdfNoTextLayer { pages: u32 },
    /// The file is encrypted. Opening it would need its password, which is a
    /// different conversation.
    EncryptedPdf,
    /// The text is there but this build cannot read it faithfully.
    ///
    /// `page` names where (0 for the file as a whole) and `readable_percent` says
    /// how much of that page came out as text. **Measured per page on purpose:**
    /// nineteen clean pages and one at 41% average out to «fine», and the page
    /// that failed is exactly the page with the client's name on it.
    UnsupportedEncoding { page: u32, readable_percent: u32 },
    /// The page's fonts or filters are ones this reader does not understand, so
    /// nothing on it can be trusted — refused even if part of it looks like words.
    /// Fail-closed: the dangerous failure is not a refused import, it is an import
    /// that looks successful while secrets sit in text we could not see.
    UnreadableStructure { page: u32 },
    /// The file does not hold together: a broken zip, a truncated PDF.
    MalformedDocument,
    /// Bigger than the limit. A document is untrusted input; one file may not eat
    /// the machine.
    DocumentTooLarge { mib: u32, limit_mib: u32 },
    /// More pages than the limit.
    TooManyPages { pages: u32, limit: u32 },
    /// The text after decompression is past the limit — a small file that swells.
    TextTooLarge { limit_mib: u32 },
    /// A few compressed bytes that unpack into a great many: a zip bomb.
    CompressionBomb { ratio: u32 },
    /// More parts inside the file than a document has any reason to hold.
    TooManyParts { parts: u32, limit: u32 },
    /// Reading it took longer than the limit.
    TookTooLong { millis: u32 },
    /// Empty, or nothing but whitespace: there is nothing to protect.
    EmptyDocument,
}

/// A name the person taught, for the list that shows what Z has learned.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TaughtNameRow {
    pub id: u32,
    pub text: String,
    /// A surname, or a given name.
    pub family: bool,
    /// `None` is everywhere; `Some(profile)` is one client.
    pub profile_id: Option<String>,
    pub learned_at: u64,
}

/// What a person says a word is when they add it themselves.
///
/// Two of these are **words** — a given name, a family name — and go into the
/// name dictionary beside the packs, where the rules that know how names are
/// written can use them. Two are **values** — a whole person, a company — and
/// go into the vault, because «Nordstern Consulting GmbH» is not a word any
/// rule can be taught, it is a thing to be found.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UserNameKind {
    Given,
    Family,
    Person,
    Company,
}

/// One row of «your names»: what this device knows because a person said so.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserNameRow {
    pub id: u32,
    /// The identity this value lives in, when the row is a vault value.
    /// `None` when it is a taught word, and the two ids are not comparable.
    pub entity_id: Option<u32>,
    pub text: String,
    pub kind: UserNameKind,
    /// Protected the moment it appears, rather than suggested and waiting.
    pub always: bool,
    pub profile_id: Option<String>,
    pub learned_at: u64,
    /// Which list it is kept in. A whole person or a company is a value in the
    /// vault rather than a word in a dictionary, and is always in the default
    /// one.
    pub list: String,
}

/// What an imported list did. Three numbers and the reasons for the third.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NameImport {
    pub added: u32,
    pub already_known: u32,
    pub refused: u32,
    /// One sentence per refused row, in the file's order, so a person can fix
    /// the file rather than guess at it. Never the whole file back.
    pub reasons: Vec<String>,
    /// How many **values** the table taught beyond its names — the customer
    /// numbers, contracts and accounts in its other columns.
    ///
    /// Without this `added: 2` meant «two names and six numbers ignored» and
    /// read as success (056).
    pub values: u32,
    /// The header columns this build could not place, by name and in the
    /// file's own order.
    ///
    /// **Nothing is discarded quietly.** A column nobody can name a kind for
    /// stays out of the vault, and the person is told which ones they were so
    /// they can see the difference between «imported» and «imported the
    /// names».
    pub columns_not_used: Vec<String>,
}

/// A name a document keeps using that no dictionary of ours knows.
///
/// Phase 2's answer to «a dictionary of every surname on earth»: Z notices the
/// names this document uses, gathers each one once, and asks about it once. A
/// candidate is **not** a finding — nothing about it is protected, and nothing
/// is written to a dictionary until a person says so.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct NameCandidate {
    /// The word, as the document writes it.
    pub text: String,
    /// What the document is using it as. A surname, so far: the two rules that
    /// find candidates both read the position of a known given name.
    pub family: bool,
    /// How many times the word stands in this document.
    pub occurrences: u32,
    /// How many pages it stands on, which is how much reading it would take to
    /// check it by hand.
    pub pages: u32,
    /// Up to three lines it appears in, so one look is enough to decide. Local
    /// only, like the document itself.
    pub examples: Vec<String>,
    /// Which rule noticed it.
    pub why: String,
}

/// What a copied report is about.
///
/// Two states and no third: a document the core is holding, or a file it
/// refused. Written as one type rather than two functions with optional
/// arguments, so that «a refusal with a session» cannot be asked for.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ReportSubject {
    /// A document that was imported. Every number comes from the core's own
    /// state; the screen passes nothing but the session.
    Imported { session: SessionId },
    /// A file that was not imported. The screen knows these three things and
    /// the core knows nothing about it at all.
    Refused {
        name: String,
        bytes: u32,
        refusal: Refusal,
    },
}

/// Where a piece of text sits in the document it came from, so that Review can
/// say «page 17» instead of an offset into one enormous string.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Place {
    pub page: u32,
    pub paragraph: u32,
}

/// What kind of identity an entity is — how the user thinks about it.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EntityKind {
    Client,
    Person,
    Company,
    Project,
    Custom,
}

/// How far the vault may act on one value by itself.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Policy {
    /// Replaced the moment it appears.
    Always,
    /// Marked and counted, waiting for your word.
    Suggest,
    /// Never found by itself; kept here so its aliases and token stay stable.
    Manual,
}

/// One identity in the vault list. The label is readable once the vault is open;
/// the values inside it are not, and each needs its own [`reveal_value`].
#[derive(Clone, PartialEq, Eq)]
pub struct EntityRow {
    pub id: u32,
    pub kind: EntityKind,
    pub label: String,
    pub profile_id: Option<String>,
    pub values: u32,
    /// «4 always · 1 suggest», as the vault list shows it.
    pub policy_summary: String,
}

/// One value inside an identity — without the value itself.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ValueRow {
    pub id: u32,
    pub kind: Kind,
    pub aliases: u32,
    pub policy: Policy,
}

/// An identity opened: what it is, and the values it holds.
#[derive(Clone, PartialEq, Eq)]
pub struct EntityCard {
    pub id: u32,
    pub kind: EntityKind,
    pub label: String,
    pub profile_id: Option<String>,
    pub values: Vec<ValueRow>,
}

/// The four answers a suggestion can get. There is no fifth, and no "send anyway".
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FindingAnswer {
    Protect,
    Always,
    NotSensitive,
    Skip,
}

// ---------------------------------------------------------------- views

/// One marked stretch of the document, for drawing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Mark {
    pub span: Span,
    pub state: MarkState,
    pub token: Option<String>,
    pub kind: Kind,
    /// Who **found** it.
    pub source: Source,
    /// Whether a person **decided** it, as against a layer deciding on its own.
    ///
    /// Two different questions, and mixing them wrote a false history: the pack
    /// may have found a name while you chose to protect it, and a list that
    /// said «you found this» would be wrong. It is also a rule and not only a
    /// label — see [`Scope`] and the rescan behaviour. (Task 033/034.)
    pub decided: bool,
    /// Pack id, entity id, or the rule's name — the "why" behind the mark.
    pub source_detail: String,
    /// The page and paragraph it sits on, when the text came from a document.
    pub place: Option<Place>,
}

/// The original text and its marks. Local only; this never leaves the device.
#[derive(Clone, PartialEq, Eq)]
pub struct DocumentView {
    pub text: String,
    pub marks: Vec<Mark>,
    /// What the user called it: a file name, or empty for text typed in.
    pub name: String,
    pub kind: DocumentKind,
    pub pages: u32,
}

/// **What a selection of lines holds** (046/Q).
///
/// The owner, 7 October: «نعتمد فقط على الأسطر — في حال تحديد الكل نحسب كم سطر
/// في النص.» The line is the unit a person works with, so the count is said
/// out loud — and with it the two numbers that decide what an act over those
/// lines is worth.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct LineSelection {
    /// How many lines are selected. «All» is simply every line.
    pub lines: u32,
    /// Values already protected inside them.
    pub protected: u32,
    /// Values inside them still waiting for an answer.
    pub open: u32,
}

/// **The question that travels with the document**, as it stands (046/N).
///
/// `text` is what would **leave** — protected — and `marks` are over the
/// question the person typed, so the field can draw them the way the Original
/// column draws its own. The raw question is not in this type: it is already
/// in the field a person is looking at, and a view that handed it back would be
/// one more copy of their writing crossing the bridge for nothing.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuestionView {
    pub text: String,
    pub marks: Vec<Mark>,
}

/// What the AI will receive, for showing in the right-hand column.
#[derive(Clone, PartialEq, Eq)]
pub struct PayloadView {
    pub text: String,
    pub protected_count: u32,
    pub open_suggestions: u32,
    /// Where a page begins **in this text**, with the page's own number.
    ///
    /// The Original column can find its own edges: the reader leaves a form
    /// feed between page and page and the column draws where it falls. The
    /// payload cannot — `build` turns each form feed into an ordinary line
    /// break, because a control character is of no use to a model, and one
    /// `\n` is indistinguishable from every other. So the builder says where
    /// they went, and it is the builder that says it because it is the only
    /// place that holds the document's offsets and the payload's at the same
    /// moment. Deriving this afterwards from the protections would be a second
    /// opinion about one fact, which in this project is how two screens come
    /// to disagree.
    ///
    /// Offsets are UTF-16 code units, like every other offset the UI is given.
    /// Adding this changes nothing that leaves the device: it is read off the
    /// payload, never written into it.
    pub page_edges: Vec<PageEdge>,
}

/// One page boundary: where it is, and which page begins there.
///
/// The number is the document's, not the index of this row. A protection may
/// swallow a page break — a selection that spans one is replaced by a single
/// token — and then that edge is simply absent from the payload while the
/// pages after it keep the numbers they have in the document. Carrying the
/// number rather than counting rows is what stops the two columns labelling
/// the same page differently.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct PageEdge {
    /// UTF-16 offset of the character the page begins at.
    pub at: u32,
    /// «Page 2» is the first edge a document can have: page one begins at the
    /// top, where no rule is drawn.
    pub page: u32,
}

/// A row of the tokens panel. The real value is not in it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TokenRow {
    pub token: String,
    pub kind: Kind,
    pub scope: Scope,
    pub source: Source,
    pub decided: bool,
    pub source_detail: String,
}

/// A token being shown in the safe column right now.
///
/// The value is not in it: that was handed over once, when it was revealed.
/// This row says only *that* it may be on screen, and for how much longer —
/// and the core is the one that says so.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RevealedToken {
    pub token: String,
    pub remaining_ms: u32,
}

/// A value shown locally for a moment. Revealing never touches a payload.
#[derive(Clone, PartialEq, Eq)]
pub struct RevealedValue {
    pub token: String,
    pub value: String,
    /// Every other spelling of the same value. Shown with it because they are
    /// the same secret: a vault screen that listed a name but hid «Herr Müller»
    /// would be keeping something from its owner for no reason.
    pub aliases: Vec<String>,
    pub ttl_ms: u32,
}

/// What one piece of a restored answer **is** — 046/U.
///
/// Three states and not two bools: a piece is the model's words, or a value we
/// put back, or a token we could not. Two bools would have a fourth corner
/// that means nothing, and this project has paid for an impossible state
/// before.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Piece {
    /// The model's own words.
    Words,
    /// A value this conversation put back where its token stood.
    Restored,
    /// **A token this conversation does not know.**
    ///
    /// It is kept in the view, word for word, because the model really did
    /// write it and removing it would be a second lie. What changes is that it
    /// is no longer indistinguishable from the answer: it says what it is, and
    /// `AnswerSnapshot::unknown_tokens` names every one of them.
    ///
    /// The commonest cause, and the one the owner met: an answer from another
    /// conversation. A token is minted per session today, so Monday's answer
    /// carries names Friday's conversation never made.
    Unresolved,
}

/// A piece of a restored answer.
///
/// `piece` and no `restored: bool` beside it. The bool was there first and this
/// change could have left it — three readers, one line each — but
/// `restored == (piece == Restored)` is the same fact written twice, and
/// wherever two places can disagree about one fact, one of them is already
/// wrong. The three readers were changed instead.
#[derive(Clone, PartialEq, Eq)]
pub struct Segment {
    pub text: String,
    pub piece: Piece,
}

/// How many items each layer caught.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LayerCount {
    pub source: Source,
    pub detail: String,
    pub count: u32,
}

/// The result of a scan, as the band under the Original header reports it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanReport {
    pub auto: u32,
    pub suggested: u32,
    pub normal: u32,
    pub by_layer: Vec<LayerCount>,
    /// Said out loud, because a locked vault means the app cannot recognise your
    /// own people: the general rules and the pack still run, the vault layer does
    /// not, and the band under the header says so.
    pub vault: VaultState,
}

/// Something the scanner is not sure about. It stays in the clear until answered.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Finding {
    pub id: u32,
    pub span: Span,
    pub kind: Kind,
    /// Who found it.
    pub source: Source,
    /// Whether a person decided it. The review list groups by this, not by
    /// `source`: confirming the pack's suggestion is **your** decision.
    pub decided: bool,
    pub reason: String,
    pub state: MarkState,
    /// The vault identities that claim this text.
    ///
    /// Empty when no identity is involved; one when the vault knows it; **more
    /// than one is a conflict** — two identities claim the same spelling, and the
    /// scanner refuses to choose silently. The app must ask.
    pub entities: Vec<String>,
    /// Where it sits: page and paragraph. Kept through protection, so a review
    /// list can still jump to page 17 after everything is replaced.
    pub place: Option<Place>,
    /// How many places in this document hold this same value, in this same
    /// state — this one included, so it is never 0.
    ///
    /// For a suggestion it is the size of the decision: one answer settles all
    /// of them, because a person deciding about «Lindenstraße 8» has decided
    /// about «Lindenstraße 8», not about a byte range. The card says «in N
    /// places» from this number, and Dart counts nothing itself.
    pub occurrences: u32,
}

/// What happened when the user pressed Protect.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProtectOutcome {
    /// Protected here, and in `places` places if all matches were taken.
    Applied { token: String, places: u32 },
    /// It was already protected; nothing to do but say by whom.
    AlreadyProtected { token: String, source: Source, source_detail: String },
    /// A new spelling of something known: alias of that identity, or a new one?
    BelongsToEntity { entity: String, token: String },
    /// The selection cut a protected item; these whole items were taken instead.
    Snapped { spans: Vec<Span> },
}

/// What one step back did.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum UndoOutcome {
    NothingToUndo,
    /// `created_entity` is set when that act had also added a vault identity.
    Undone { token: String, places: u32, created_entity: Option<String> },
}

/// Switching a profile keeps tokens already given.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SwitchOutcome {
    pub kept_tokens: u32,
    pub revision: u32,
}

/// Switching a pack rescans; what the old pack caught and the new one does not
/// becomes manual, and stays protected.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RescanOutcome {
    pub changed_to_manual: u32,
    pub revision: u32,
}

/// Opening the vault. No key appears here in either direction.
///
/// Authentication failure is not an outcome here. It is an [`ApiError`], because
/// Rust cannot prove whether the passphrase was wrong or the file was modified.
///
/// There is no attempt limit and there should not be one: locking a **local**
/// file after three tries protects nobody — whoever has the file does not use
/// our window — while a real person who mistypes would be shut out of their own
/// vault forever. The cost of guessing is Argon2id at 64 MiB a try, which is a
/// defence that cannot be walked around.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VaultUnlockOutcome {
    Unlocked { identities: u32, values: u32 },
}

// ---------------------------------------------------------------- G11: no text in Debug

// These four carry the user's own writing across the bridge. Deriving `Debug` on
// them would put a client's letter into the first log line someone adds, so each
// one says what it is and not what it says. Invariant G11.

impl fmt::Debug for DocumentView {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("DocumentView")
            .field("text", &format_args!("[REDACTED {} bytes]", self.text.len()))
            .field("marks", &self.marks.len())
            .field("name", &self.name)
            .field("kind", &self.kind)
            .field("pages", &self.pages)
            .finish()
    }
}

impl fmt::Debug for PayloadView {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PayloadView")
            .field("text", &format_args!("[REDACTED {} bytes]", self.text.len()))
            .field("protected_count", &self.protected_count)
            .field("open_suggestions", &self.open_suggestions)
            .finish()
    }
}

impl fmt::Debug for RevealedValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("RevealedValue")
            .field("token", &self.token)
            .field("value", &format_args!("[REDACTED]"))
            .field("ttl_ms", &self.ttl_ms)
            .finish()
    }
}

impl fmt::Debug for EntityRow {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("EntityRow")
            .field("id", &self.id)
            .field("kind", &self.kind)
            .field("label", &format_args!("[REDACTED]"))
            .field("values", &self.values)
            .finish()
    }
}

impl fmt::Debug for EntityCard {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("EntityCard")
            .field("id", &self.id)
            .field("kind", &self.kind)
            .field("label", &format_args!("[REDACTED]"))
            .field("values", &self.values)
            .finish()
    }
}

impl fmt::Debug for Segment {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("Segment")
            .field("text", &format_args!("[REDACTED {} bytes]", self.text.len()))
            .field("piece", &self.piece)
            .finish()
    }
}

// ---------------------------------------------------------------- truth snapshots
//
// Flutter draws these. It does not keep a second copy of any fact in them.
// `state_revision` is a check that a mutation actually moved displayed truth;
// it is not itself a source the screen draws from.

/// Home: vault, packs, providers, settings — one read.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct HomeSnapshot {
    pub state_revision: u32,
    pub vault: VaultState,
    pub identity_count: u32,
    pub value_count: u32,
    pub profiles: Vec<ProfileRow>,
    pub packs: Vec<PackRow>,
    pub providers: Vec<ProviderFact>,
    pub settings: Settings,
    pub kinds: Vec<KindRow>,
}

/// The workspace: findings are the canonical set; the counts are derived from them.
#[derive(Clone, PartialEq, Eq)]
pub struct WorkspaceSnapshot {
    pub state_revision: u32,
    pub session: SessionId,
    pub profile_id: Option<String>,
    pub revision: u32,
    pub scan_origin: ScanOrigin,
    pub auto_protected: u32,
    pub user_protected: u32,
    pub open_suggestions: u32,
    pub normal: u32,
    pub token_count: u32,
    pub can_undo: bool,
    pub findings: Vec<Finding>,
    pub document: DocumentView,
    pub tokens: Vec<TokenRow>,
    pub payload: Option<PayloadView>,
    pub handle: Option<PayloadHandle>,
    pub vault: VaultState,
    pub answers: Vec<AnswerId>,
}

/// Vault room: header and body draw from this one object.
#[derive(Clone, PartialEq, Eq)]
pub struct VaultSnapshot {
    pub state_revision: u32,
    pub vault: VaultState,
    pub identity_count: u32,
    pub value_count: u32,
    pub profiles: Vec<ProfileRow>,
    pub taught_values: Vec<TaughtValueRow>,
    pub can_forget: bool,
}

/// Which durable layer a privacy-rules row came from.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum KnowledgeSource {
    BuiltIn,
    UserTaughtValue,
    UserException,
}

/// My Privacy Rules, read in one call from the vault.
#[derive(Clone, PartialEq, Eq)]
pub struct PrivacyRulesSnapshot {
    pub state_revision: u32,
    pub profile_id: Option<String>,
    pub values: Vec<TaughtValueRow>,
    pub exceptions: Vec<TaughtExceptionRow>,
    /// The label rules this person taught, effective for `profile_id`.
    pub label_rules: Vec<LabelRuleRow>,
    /// Every rule set this build carries, so the screen can offer them without
    /// keeping a list of its own.
    pub rule_sets: Vec<RuleSetRow>,
    /// The sets actually switched on for `profile_id` — what *ran*, not what
    /// was asked for.
    pub active_sets: Vec<String>,
    /// Was the «Rules I taught» section built? True since M7.10B; kept as a
    /// field because a screen must read this, never assume it.
    pub rules_built: bool,
}

/// One taught value. The value is present only because the vault is unlocked and
/// this screen exists for the owner to review what they taught.
#[derive(Clone, PartialEq, Eq)]
pub struct TaughtValueRow {
    pub entity_id: u32,
    pub entity_label: String,
    pub value_id: u32,
    pub kind: Kind,
    pub profile_id: Option<String>,
    pub profile_name: Option<String>,
    /// How many spellings, not which ones — the same shape as `ValueRow`.
    pub aliases: u32,
    pub taught_at: u64,
    pub why: String,
    pub source: KnowledgeSource,
}

/// One durable exception taught by the user.
#[derive(Clone, PartialEq, Eq)]
pub struct TaughtExceptionRow {
    pub id: u32,
    pub value: String,
    pub kind: Kind,
    pub profile_id: Option<String>,
    pub profile_name: Option<String>,
    pub taught_at: u64,
    pub why: String,
    pub source: KnowledgeSource,
}

/// Providers as they actually stand, including where a credential lives.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderSnapshot {
    pub state_revision: u32,
    pub providers: Vec<ProviderFact>,
}

/// One provider's facts. `credential_state` is storage, not a guess from `connected`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderFact {
    pub id: String,
    /// What Z Privacy speaks, not what a person chose: «OpenAI-compatible».
    /// A **protocol**, shown where the technical detail belongs.
    pub label: String,
    /// A credential is stored for this provider — not «this provider is set
    /// up». A model on this machine is connected and holds no credential, so
    /// this is `false` while `connected` is `true`, and the two words are not
    /// interchangeable anywhere.
    pub configured: bool,
    pub connected: bool,
    pub endpoint: String,
    pub model: String,
    pub credential_required: bool,
    pub credential_state: CredentialState,
    /// Is this endpoint on this computer?
    ///
    /// Reported by the core from the address itself, never worked out by a
    /// screen — because the word «Local» is a promise about where the text
    /// goes, and a promise must be checked by whoever knows. It is the same
    /// test the network door enforces, so the word and the rule cannot part.
    pub on_this_computer: bool,
}

/// One answer, both views, from the core.
#[derive(Clone, PartialEq, Eq)]
pub struct AnswerSnapshot {
    pub state_revision: u32,
    pub answer: AnswerId,
    pub index: u32,
    pub total: u32,
    /// The answer before this one, or `None` at the first.
    ///
    /// Carried here rather than worked out by a screen, for the reason the
    /// whole snapshot exists: `index`/`total` and «which answer do I move to»
    /// must be **one** fact. A list held in Dart alongside a count from Rust
    /// is two sources that will disagree, and «Answer 2 of 2» with a stale
    /// neighbour is the same family as every lie this project has hunted.
    pub previous: Option<AnswerId>,
    /// The answer after this one, or `None` at the last.
    pub next: Option<AnswerId>,
    pub restored: Vec<Segment>,
    pub as_written: String,
    /// **Every token in this answer that this conversation could not resolve**
    /// — 046/U, by name and in the order they appear.
    ///
    /// Empty is the ordinary case and the only one a person need not be told
    /// about. Non-empty means the answer was built somewhere else: a screen
    /// that drew these as the model's own words would be telling a person that
    /// `__Z_5CDD_IBAN_5B32__` is what the model said about their account.
    ///
    /// Named here as well as marked in the pieces so that the count in the
    /// sentence and the marks in the text are **one** fact.
    pub unknown_tokens: Vec<String>,
}

impl fmt::Debug for WorkspaceSnapshot {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("WorkspaceSnapshot")
            .field("state_revision", &self.state_revision)
            .field("profile_id", &self.profile_id)
            .field("scan_origin", &self.scan_origin)
            .field("auto_protected", &self.auto_protected)
            .field("user_protected", &self.user_protected)
            .field("open_suggestions", &self.open_suggestions)
            .field("token_count", &self.token_count)
            .field("can_undo", &self.can_undo)
            .field("findings", &self.findings.len())
            .field("document", &self.document)
            .finish()
    }
}

impl fmt::Debug for VaultSnapshot {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("VaultSnapshot")
            .field("state_revision", &self.state_revision)
            .field("vault", &self.vault)
            .field("identity_count", &self.identity_count)
            .field("value_count", &self.value_count)
            .field("taught_values", &self.taught_values.len())
            .field("can_forget", &self.can_forget)
            .finish()
    }
}

impl fmt::Debug for TaughtValueRow {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TaughtValueRow")
            .field("entity_id", &self.entity_id)
            .field("entity_label", &format_args!("[REDACTED]"))
            .field("value_id", &self.value_id)
            .field("kind", &self.kind)
            .field("profile_id", &self.profile_id)
            .field("aliases", &self.aliases)
            .field("taught_at", &self.taught_at)
            .field("source", &self.source)
            .finish()
    }
}

impl fmt::Debug for TaughtExceptionRow {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("TaughtExceptionRow")
            .field("id", &self.id)
            .field("value", &format_args!("[REDACTED]"))
            .field("kind", &self.kind)
            .field("profile_id", &self.profile_id)
            .field("taught_at", &self.taught_at)
            .field("source", &self.source)
            .finish()
    }
}

impl fmt::Debug for PrivacyRulesSnapshot {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("PrivacyRulesSnapshot")
            .field("state_revision", &self.state_revision)
            .field("profile_id", &self.profile_id)
            .field("values", &self.values.len())
            .field("exceptions", &self.exceptions.len())
            .field("rules_built", &self.rules_built)
            .finish()
    }
}

impl fmt::Debug for AnswerSnapshot {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.debug_struct("AnswerSnapshot")
            .field("state_revision", &self.state_revision)
            .field("answer", &self.answer)
            .field("index", &self.index)
            .field("total", &self.total)
            .field("restored", &self.restored.len())
            .field("as_written", &format_args!("[REDACTED {} bytes]", self.as_written.len()))
            .finish()
    }
}

// ---------------------------------------------------------------- session

// ------------------------------------------------------- the owner's sessions

/// **One of the owner's sessions** — 064. «Session» is the word he uses; in the
/// core it is a `Conversation`, because `SessionId` below already means one
/// document's bench. Task 066 pays that rename.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ConversationRow {
    /// The identity. Never changes, never reused — not even after a deletion.
    pub number: u32,
    /// The handle, which the person may change at any time.
    pub name: String,
    /// Seconds since 1970.
    pub began_at: u64,
    /// How many exchanges its own sealed file holds.
    pub turns: u32,
    /// **How many tokens were named again** when this session was entered or
    /// born. Reported rather than hidden: at a birth the names on the screen
    /// change, and a number a person can see beats a silent redraw. Zero for a
    /// row that was merely listed.
    pub renamed_tokens: u32,
}

/// Begin a session, with the name the person was asked for once.
///
/// Called at the first exit — Copy, a PDF, a question sent to a model — when
/// none is open. There is no "new session" button, by the owner's design.
/// `bench` is the document in front of them, whose tokens are named again from
/// this session's key: the names that leave are the session's names.
pub fn conversation_begin(name: String, bench: Option<SessionId>) -> ApiResult<ConversationRow> {
    crate::ops::conversation::begin(name, bench)
}

/// Enter an existing session. Asks nothing, and names the bench's tokens from
/// that session's key.
pub fn conversation_enter(number: u32, bench: Option<SessionId>) -> ApiResult<ConversationRow> {
    crate::ops::conversation::enter(number, bench)
}

/// Which session is open, if any.
pub fn conversation_open() -> ApiResult<Option<u32>> {
    crate::ops::conversation::open()
}

/// Every session the vault keeps.
pub fn conversations() -> ApiResult<Vec<ConversationRow>> {
    crate::ops::conversation::rows()
}

/// Change a session's handle. The number is the identity and does not move.
pub fn conversation_rename(number: u32, name: String) -> ApiResult<()> {
    crate::ops::conversation::rename(number, name)
}

/// **Delete a session: its key and its file, together.**
///
/// Returns the name, so the screen can say what went. Nothing protected in this
/// session can ever be unprotected again — the key is destroyed and nothing
/// derives anything, which makes the owner's warning a fact rather than a
/// caution. Key and file cannot be separated, because the key *is* the map.
pub fn conversation_forget(number: u32) -> ApiResult<String> {
    crate::ops::conversation::forget(number)
}

/// Write one exchange into the open session's file.
pub fn conversation_record(question: String, answer: String) -> ApiResult<u32> {
    crate::ops::conversation::record(question, answer)
}

/// Does the open session still belong to the document on this bench? — 062 §C.
///
/// `None` means there is nothing to compare: no session open, no document, or a
/// session that kept none. **`None` is not «yes»** — a restored session whose
/// document moved must refuse rather than guess, and reading this as agreement
/// is the defect the `Option` exists to prevent.
pub fn conversation_document_matches(bench: SessionId) -> ApiResult<Option<bool>> {
    crate::ops::conversation::document_matches(bench)
}

/// Open a conversation. `pack_id` is the session's override; empty means the
/// profile's pack, and failing that the app default.
///
/// **This is a document's bench, not one of the owner's sessions** — the two
/// wore one word until 064 and task 066 pays the rename.
pub fn open_session(profile_id: Option<String>, pack_id: String) -> ApiResult<SessionId> {
    crate::ops::open_session(profile_id, pack_id)
}

/// Close it and forget its session tokens.
pub fn close_session(session: SessionId) -> ApiResult<()> {
    crate::ops::close_session(session)
}

/// The session's current revision — the number that makes a handle stale.
pub fn session_revision(session: SessionId) -> ApiResult<Revision> {
    crate::ops::session_revision(session)
}

// ---------------------------------------------------------------- document

/// Bring in typed text. No file, no pages: one paragraph per blank line.
pub fn import_text(session: SessionId, text: String) -> ApiResult<DocumentView> {
    crate::ops::import_text(session, text)
}

/// Bring in a file. Read here, from memory, with the limits of G15 — and refused
/// by name when it cannot be read honestly.
pub fn import_document(session: SessionId, name: String, bytes: Vec<u8>, kind: DocumentKind) -> ApiResult<DocumentView> {
    crate::ops::import_document(session, name, bytes, kind)
}

/// The names this document uses that no dictionary knows, one row each.
///
/// Sorted by how much a single decision buys: the name that stands in the most
/// places first. The owner's measure of this phase is not how many names Z
/// knows, but how few decisions a person makes before a document is understood.
pub fn name_candidates(session: SessionId) -> ApiResult<Vec<NameCandidate>> {
    crate::ops::name_candidates(session)
}

/// The report a person can copy when something is wrong with a document.
///
/// **Numbers only, by contract**: sizes, counts, the kinds by name, the
/// refusal by its own name — and not one character of the document or of
/// anything found in it. It exists for a tester who cannot send us the file,
/// and it is written in the core so that the screen cannot work out a figure
/// of its own.
pub fn import_report(subject: ReportSubject) -> ApiResult<String> {
    crate::ops::import_report(subject)
}

/// The original text with its marks, for the left-hand column.
pub fn document_view(session: SessionId) -> ApiResult<DocumentView> {
    crate::ops::document_view(session)
}

/// Run the detection layers over the whole document. M3.
pub fn scan(session: SessionId) -> ApiResult<ScanReport> {
    crate::ops::scan(session)
}

// ---------------------------------------------------------------- protect

/// Protect a selection. The outcome says whether it was already known.
/// What is this selection, and what would Protect do to it? Answered before
/// anything is changed, so a button can show the right state instead of pressing
/// blind and apologising afterwards.
pub fn inspect_selection(session: SessionId, span: Span) -> ApiResult<SelectionView> {
    crate::ops::inspect_selection(session, span)
}

pub fn protect(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    crate::ops::protect(session, span, scope, kind)
}

/// Protect every place the selected text appears, all under one token.
pub fn protect_all_matches(session: SessionId, span: Span, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    crate::ops::protect_all_matches(session, span, scope, kind)
}

/// One step back. "All matches" went in as one act, so it comes out as one act.
/// Remove the protection on this stretch — **this document, this decision**.
///
/// The counterpart that makes «Forget» honest (task 037). Forgetting erases
/// what Z Privacy learned for future use and deliberately leaves the open
/// document exactly as it is; this is the only thing that changes what is
/// protected here, and it is asked for by name.
pub fn unprotect(session: SessionId, span: Span) -> ApiResult<UndoOutcome> {
    crate::ops::unprotect(session, span)
}

pub fn undo_last_protection(session: SessionId) -> ApiResult<UndoOutcome> {
    crate::ops::undo_last_protection(session)
}

/// Teach an existing token another spelling of the same thing.
pub fn add_alias(session: SessionId, token: String, alias: String) -> ApiResult<u32> {
    crate::ops::add_alias(session, token, alias)
}

// ---------------------------------------------------------------- review

/// Everything the scan found, in three states, each with its reason.
pub fn list_findings(session: SessionId) -> ApiResult<Vec<Finding>> {
    crate::ops::list_findings(session)
}

/// Answer one suggestion. Skip leaves it in the clear, and still counted.
pub fn answer_finding(session: SessionId, finding: u32, answer: FindingAnswer) -> ApiResult<ScanReport> {
    crate::ops::answer_finding(session, finding, answer)
}

/// Remember that one suggestion is not sensitive in a durable scope.
pub fn teach_exception(session: SessionId, finding: u32, scope: Scope) -> ApiResult<ScanReport> {
    crate::ops::teach_exception(session, finding, scope)
}

// ---------------------------------------------------------------- tokens

/// Show one value locally, for a moment. This does not touch any payload.
pub fn reveal(session: SessionId, token: String) -> ApiResult<RevealedValue> {
    crate::ops::reveal(session, token)
}

/// Put the token back in the view.
pub fn hide(session: SessionId, token: String) -> ApiResult<()> {
    crate::ops::hide(session, token)
}

/// Which tokens are shown locally right now, and for how much longer.
pub fn revealed_tokens(session: SessionId) -> ApiResult<Vec<RevealedToken>> {
    crate::ops::revealed_tokens(session)
}

/// The window is no longer the one in front.
///
/// The screen reports the event; what it means is decided here. Measured on
/// Linux/GTK before it was promised: this is `AppLifecycleState.inactive`,
/// which also arrives once at startup and again during a restore — harmless,
/// because covering what is uncovered asks nothing of the person and nothing
/// of the vault.
pub fn window_focus_lost() -> ApiResult<()> {
    crate::ops::hide_all_reveals()
}

/// The window is not on the screen at all — minimised, or on a workspace that
/// is not the visible one. Measured as `AppLifecycleState.hidden`.
///
/// It ends every reveal, as losing focus does. Locking the vault when the
/// window disappears is a separate act with its own switch, and its own
/// commit: this door must never be the one that locks, because `inactive`
/// arrives at startup and a vault that locked itself on every launch would be
/// a defect wearing a promise's clothes.
pub fn window_hidden() -> ApiResult<()> {
    crate::ops::hide_all_reveals()
}

/// Cover everything that is uncovered: the vault's value and every token.
pub fn hide_all_reveals() -> ApiResult<()> {
    crate::ops::hide_all_reveals()
}

/// The tokens standing in this conversation, without their values.
pub fn list_tokens(session: SessionId) -> ApiResult<Vec<TokenRow>> {
    crate::ops::list_tokens(session)
}

// ---------------------------------------------------------------- payload

/// Build the outgoing text here, and hand back a reference to it.
pub fn build_payload(session: SessionId) -> ApiResult<PayloadHandle> {
    crate::ops::build_payload(session)
}

/// The payload as text, for the right-hand column. Shown, never authored.
pub fn payload_view(handle: PayloadHandle) -> ApiResult<PayloadView> {
    crate::ops::payload_view(handle)
}

/// Send a built payload. Takes a handle: there is no signature here that could
/// accept the original text, by design.
pub fn send(handle: PayloadHandle, provider: ProviderId) -> ApiResult<AnswerId> {
    crate::ops::send(handle, provider)
}

/// Ask a model, with a workspace's instructions and a conversation's history.
///
/// The protected door of the Model Gateway, and the one a workspace uses. It
/// takes a **handle**, so there is no signature here through which a document
/// could be sent unprotected — the same promise `send` has always made, with a
/// context and a chosen model added.
///
/// `model` is optional: without one, the provider's configured model answers.
pub fn ask_model(handle: PayloadHandle, provider: ProviderId, model: Option<String>, workspace: Vec<String>, history: Vec<String>) -> ApiResult<ModelAnswer> {
    crate::ops::ask_model(handle, provider, model, workspace, history)
}

/// Send text to a model **as it stands**, because the person chose to.
///
/// Direct Mode. A separate function, a separate body type and a separate path
/// through the gateway: nothing turns a protected request into this one, and a
/// protected request that fails is reported as having failed. The person knows
/// which mode they are in, because they called this.
///
/// It is «not redacted». It is never «not encrypted»: the address is checked
/// the way every other request's is, and plain HTTP reaches nothing but this
/// machine.
pub fn ask_model_directly(session: SessionId, text: String, provider: ProviderId, model: Option<String>, workspace: Vec<String>, history: Vec<String>) -> ApiResult<ModelAnswer> {
    crate::ops::ask_model_directly(session, text, provider, model, workspace, history)
}

/// **Set the question that travels with this document** (046/N).
///
/// The owner, 7 October: «ليس لدينا شات — شات مع نموذج… لا يوجد خيار مثلاً
/// مباشرة إلى الشات.» Before this a document reached the model with no request
/// at all, so whatever came back was the model's own guess at what was wanted.
///
/// **The question is text, and text is scanned.** It is protected here, by the
/// same packs, the same vault and the same lists the document was read with —
/// and by what this document has already protected, so a name that is a token
/// in the sheet is the *same* token in the question. A question field that
/// bypassed the scanner would be the one hole big enough to sink the product.
///
/// What comes back is what would **leave**, and the marks over what was typed.
/// Setting it makes any payload built before it stale, because the Safe column
/// must not show yesterday's request.
pub fn set_question(session: SessionId, text: String) -> ApiResult<QuestionView> {
    crate::ops::set_question(session, text)
}

/// The question as it stands, protected. Marks are empty here: they belong to
/// the act of setting it, and re-deriving them on every read would be a second
/// scan of the same sentence.
pub fn question(session: SessionId) -> ApiResult<QuestionView> {
    crate::ops::question(session)
}

/// **What a selection of lines holds** (046/Q): how many lines, how many values
/// in them are already protected, and how many are still waiting.
///
/// `from` and `to` are line numbers from zero, in either order. The core
/// answers because these are facts about findings; a screen that counted them
/// would be a second source for a number Rust already holds.
pub fn line_selection(session: SessionId, from: u32, to: u32) -> ApiResult<LineSelection> {
    crate::ops::line_selection(session, from, to)
}

/// **Protect the same cell in every selected line** (046/Q).
///
/// A person selects the lines, clicks **one** value, and the cell it stands in
/// is protected in all of them. The column is reached by **example** — the
/// example being a person's own click — and never by inference about what a
/// header means.
///
/// The cell is cell **k** of the row, counting runs separated by two or more
/// spaces or a tab: by **order**, never by character position, which 048
/// measured as the only thing about a table that survives this build's PDF
/// reader on the owner's real documents.
///
/// **Each value becomes its own token.** Never the line as one token: a line
/// swallowed whole would destroy the row and take its amounts with it.
pub fn protect_cell_in_lines(session: SessionId, span: Span, from: u32, to: u32, scope: Scope, kind: Kind) -> ApiResult<ProtectOutcome> {
    crate::ops::protect_cell_in_lines(session, span, from, to, scope, kind)
}

/// Incoming only: hand the core an answer as it arrived, tied to the payload the
/// model saw. There is no restore-from-arbitrary-session-text path.
pub fn ingest_answer(payload: PayloadHandle, raw: String) -> ApiResult<AnswerId> {
    crate::ops::ingest_answer(payload, raw)
}

// ---------------------------------------------------------------- answer

/// The answer with your own words back in place. The default view.
pub fn restored_view(session: SessionId, answer: AnswerId) -> ApiResult<Vec<Segment>> {
    crate::ops::restored_view(session, answer)
}

/// The answer exactly as it arrived, tokens and all.
pub fn ai_view(session: SessionId, answer: AnswerId) -> ApiResult<String> {
    crate::ops::ai_view(session, answer)
}

// ---------------------------------------------------------------- vault

/// Where this device keeps its vault. Called once at startup by the app.
pub fn set_data_dir(dir: String) -> ApiResult<()> {
    crate::ops::set_data_dir(dir)
}

/// Where this machine's Z Privacy files belong, decided by the core rather than
/// guessed by the screen. Never the temp directory: a platform that cannot say
/// is refused, not fallen back on.
pub fn default_data_dir() -> ApiResult<String> {
    crate::data_dir::default_data_dir().map(|p| p.to_string_lossy().to_string())
}

/// Is it open? Locked means the vault layer is skipped, and the UI says so.
pub fn vault_state() -> ApiResult<VaultState> {
    crate::ops::vault_state()
}

/// Make a vault on this device: a random master key, sealed under this passphrase.
pub fn vault_create_with_passphrase(passphrase: String) -> ApiResult<VaultUnlockOutcome> {
    crate::ops::vault_create(passphrase)
}

/// Change the passphrase. Only the master key is re-wrapped; the vault's contents
/// are not decrypted and not rewritten.
pub fn vault_change_passphrase(old: String, replacement: String) -> ApiResult<()> {
    crate::ops::vault_change_passphrase(old, replacement)
}

/// Open the vault with the user's passphrase. Argon2id and the master key stay
/// inside this crate; neither ever crosses the bridge.
pub fn vault_unlock_with_passphrase(passphrase: String) -> ApiResult<VaultUnlockOutcome> {
    crate::ops::vault_unlock(passphrase)
}

/// Close it. Every revealed value re-hides.
pub fn vault_lock() -> ApiResult<()> {
    crate::ops::vault_lock()
}

/// The identities, as the vault list shows them. `None` means every profile.
pub fn entities(profile_id: Option<String>) -> ApiResult<Vec<EntityRow>> {
    crate::ops::entities(profile_id)
}

/// One identity opened, with the values inside it.
pub fn entity(entity_id: u32) -> ApiResult<EntityCard> {
    crate::ops::entity(entity_id)
}

/// A new identity: «CLIENT #17», and what you call it.
pub fn create_entity(kind: EntityKind, label: String, profile_id: Option<String>) -> ApiResult<u32> {
    crate::ops::create_entity(kind, label, profile_id)
}

/// Deleting an identity deletes the values inside it.
pub fn delete_entity(entity_id: u32) -> ApiResult<()> {
    crate::ops::delete_entity(entity_id)
}

/// Add a value to an identity, or change one. `value_id` is `None` for a new one.
pub fn set_value(entity: u32, value_id: Option<u32>, kind: Kind, text: String, policy: Policy) -> ApiResult<u32> {
    crate::ops::set_value(entity, value_id, kind, text, policy)
}

/// Teach a value another spelling of the same thing.
pub fn add_value_alias(entity: u32, value_id: u32, alias: String) -> ApiResult<()> {
    crate::ops::add_value_alias(entity, value_id, alias)
}

/// Show one stored value, for a moment, locally.
pub fn reveal_value(entity: u32, value_id: u32) -> ApiResult<RevealedValue> {
    crate::ops::reveal_value(entity, value_id)
}

/// A new profile — one client's dictionary.
/// Rename an identity. The label is the only part of it a screen ever shows.
pub fn rename_entity(entity_id: u32, label: String) -> ApiResult<()> {
    crate::ops::rename_entity(entity_id, label)
}

/// Move an identity to another profile, or to none — `None` means everywhere.
pub fn move_entity(entity_id: u32, profile_id: Option<String>) -> ApiResult<()> {
    crate::ops::move_entity(entity_id, profile_id)
}

/// Forget one value, keeping the identity it belonged to.
pub fn delete_value(entity: u32, value_id: u32) -> ApiResult<()> {
    crate::ops::delete_value(entity, value_id)
}

/// Forget one spelling of a value.
pub fn remove_value_alias(entity: u32, value_id: u32, alias: String) -> ApiResult<()> {
    crate::ops::remove_value_alias(entity, value_id, alias)
}

/// Search the vault — **on this device, in memory, and nowhere else**.
///
/// The query is matched against labels, values and their spellings, which means
/// it touches secrets; that is exactly why it happens here and returns only
/// rows. Nothing about what matched is reported, so a search result says «this
/// identity» and never «because its IBAN is …».
pub fn search_vault(query: String) -> ApiResult<Vec<EntityRow>> {
    crate::ops::search_vault(query)
}

/// Why is this protected? The full answer, for one protected stretch.
pub fn explain(session: SessionId, span: Span) -> ApiResult<Explanation> {
    crate::ops::explain(session, span)
}

/// What forgetting this value would take away. Nothing is changed.
pub fn forget_plan(entity: u32, value_id: u32, everywhere: bool) -> ApiResult<ForgetPlan> {
    crate::ops::forget_plan(entity, value_id, everywhere)
}

/// Forget it. Returns what was actually removed, and proves nothing still
/// recognises it.
pub fn forget_value(entity: u32, value_id: u32, everywhere: bool) -> ApiResult<ForgetPlan> {
    crate::ops::forget_value(entity, value_id, everywhere)
}

/// Forget one durable exception.
pub fn forget_exception(id: u32) -> ApiResult<()> {
    crate::ops::forget_exception(id)
}

/// Every kind of value this build knows, with its label.
pub fn kinds() -> ApiResult<Vec<KindRow>> {
    crate::ops::kinds()
}

/// What the app has been told to do by itself.
pub fn settings() -> ApiResult<Settings> {
    crate::ops::settings()
}

/// Change it. Returns the settings as they now stand, including where they live.
pub fn save_settings(settings: Settings) -> ApiResult<Settings> {
    crate::ops::save_settings(settings)
}

/// Make a client, and return its id.
///
/// `session` is the open document's session when the client is made from the
/// document screen, and `None` from the vault screen. It decides one thing: the
/// language the client starts with, because the document in front of the person
/// is the only language the app is not guessing at that moment.
pub fn create_profile(name: String, session: Option<SessionId>) -> ApiResult<String> {
    crate::ops::create_profile(name, session)
}

pub fn rename_profile(profile_id: String, name: String) -> ApiResult<()> {
    crate::ops::rename_profile(profile_id, name)
}

// ---------------------------------------------------------------- profiles, packs

/// The profiles, as the switcher lists them: `id\tname`.
pub fn profiles() -> ApiResult<Vec<ProfileRow>> {
    crate::ops::profiles()
}

/// Switch profile. Tokens already given stand; only new matching follows.
pub fn switch_profile(session: SessionId, profile_id: Option<String>) -> ApiResult<SwitchOutcome> {
    crate::ops::switch_profile(session, profile_id)
}

/// What is revealed right now, and for how much longer.
///
/// `remaining_ms` of 0 means nothing is revealed — the screen must mask the
/// value at once. A countdown drawn in Flutter is for a person to read; it is
/// never the reason a secret stays visible.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RevealState {
    pub entity: Option<u32>,
    pub value_id: Option<u32>,
    pub remaining_ms: u32,
}

/// Ask the core what is revealed. Called about once a second while showing.
pub fn reveal_state() -> ApiResult<RevealState> {
    crate::ops::reveal_state()
}

/// Stop revealing before the time is up.
pub fn hide_value() -> ApiResult<()> {
    crate::ops::hide_value()
}

/// The rule sets this build carries. A language is a set, not a screen.
pub fn rule_sets() -> ApiResult<Vec<RuleSetRow>> {
    crate::ops::rule_sets()
}

/// Switch which rule sets a profile runs. Several at once, on purpose.
pub fn set_profile_languages(profile_id: String, languages: Vec<String>) -> ApiResult<ProfileRow> {
    crate::ops::set_profile_languages(profile_id, languages)
}

/// Teach a name: «Al-Hassan is a family name». One word at a time.
///
/// Knowledge, not a protection: it tells the rules what kind of word this is,
/// and the rules decide what to do with it. Local, in the vault, and undone by
/// `forget_name`.
///
/// `session` is the document it was learned from, and it decides which
/// language's list the name goes into: a name met in a Swedish document is a
/// Swedish name even on a device set up in German. `None` is for a name typed
/// with nothing open, and then the device's own language is the only answer.
pub fn teach_name(text: String, family: bool, profile_id: Option<String>, session: Option<SessionId>) -> ApiResult<u32> {
    crate::ops::teach_name(text, family, profile_id, session)
}

/// Unlearn a taught name. An open document keeps the tokens it already has.
pub fn forget_name(id: u32) -> ApiResult<()> {
    crate::ops::forget_name(id)
}

/// Every name the person taught, newest first.
pub fn taught_names() -> ApiResult<Vec<TaughtNameRow>> {
    crate::ops::taught_names()
}

/// Add a name a person types themselves, with what it is and how far it reaches.
///
/// The kind decides where it is kept and the strength decides what Z does with
/// it: a given or family name is a word for the dictionary, a person or a
/// company is a value for the vault, and «always» means protected on sight
/// instead of suggested. Needs an open vault, like everything else a person
/// teaches this device.
pub fn add_user_name(text: String, kind: UserNameKind, always: bool, profile_id: Option<String>, list: String) -> ApiResult<u32> {
    crate::ops::add_user_name(text, kind, always, profile_id, list)
}

/// One list of names a person keeps — **one per language**, named by the
/// language's own id, with its size and its switch.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct UserListRow {
    pub name: String,
    /// How many **names** are in it: words in the dictionary and whole people
    /// and companies in the vault, which are one thing to the person who
    /// imported them.
    pub names: u32,
    /// How many **other values** are in it — a customer number, a contract, a
    /// phone. A client table teaches these and nothing else does, so they are
    /// counted apart: «21 names» and «21 names and 6 numbers» are different
    /// answers to «what did that file teach me?» (056).
    pub values: u32,
    /// Off means the scanner is not told about them — not that they are gone.
    pub enabled: bool,
}

/// The lists, with what is in them.
pub fn user_lists() -> ApiResult<Vec<UserListRow>> {
    crate::ops::user_lists()
}

/// Move every name in one list into another language's list, in one act.
///
/// Not a rename: the destination keeps the names it already has, and the list
/// that is emptied stops being a list. What comes back is how many moved.
pub fn move_user_list(from: String, to: String) -> ApiResult<u32> {
    crate::ops::move_user_list(from, to)
}

/// Turn one off, or on. Off is not forgotten: every name in it is still here.
pub fn set_user_list_enabled(name: String, enabled: bool) -> ApiResult<()> {
    crate::ops::set_user_list_enabled(name, enabled)
}

/// How many names forgetting this list would take with it — asked first.
pub fn user_list_plan(name: String) -> ApiResult<u32> {
    crate::ops::user_list_plan(name)
}

/// Forget a list and the names in it, and nothing else.
pub fn forget_user_list(name: String) -> ApiResult<u32> {
    crate::ops::forget_user_list(name)
}

/// Everything this device knows because a person said so, newest first.
///
/// Both stores in one list, because a person who added four names does not
/// think of them as living in two places.
pub fn user_names(profile_id: Option<String>) -> ApiResult<Vec<UserNameRow>> {
    crate::ops::user_names(profile_id)
}

/// Take one of those back. `entity_id` is the row's own, or `None` for a word.
pub fn forget_user_name(id: u32, entity_id: Option<u32>) -> ApiResult<()> {
    crate::ops::forget_user_name(id, entity_id)
}

/// Read a list of names: a CSV whose first line names its columns.
///
/// `name` and `type` are required; `source` and `licence` are kept with each
/// name if they are there. Nothing is written until the whole file has been
/// read, and what comes back is three numbers and a sentence for every row
/// that was refused.
///
/// `scope` is asked once for the whole file, in the app's own word — the same
/// `Scope` `protect` takes, so a review screen over this import hands it
/// through rather than translating it:
///
/// * `None` — «offer them and I decide»: knowledge, no protection.
/// * `Some(Profile)` — this client's book, protected on sight in this client's
///   documents and in no other client's.
/// * `Some(Always)` — every client's, kept with no profile at all.
/// * `Some(Once)` / `Some(Conversation)` — refused, because both are answers
///   about a place in a document and a list has no places in it.
///
/// It decides what a row **becomes**; a name the vault already holds keeps the
/// reach it was given by hand, and is counted as already known.
pub fn import_user_names(csv: String, profile_id: Option<String>, list: String, scope: Option<Scope>) -> ApiResult<NameImport> {
    crate::ops::import_user_names(csv, profile_id, list, scope)
}

/// Teach a label rule: «the value after this word is a customer number».
pub fn teach_label_rule(label: String, kind: Kind, profile_id: Option<String>) -> ApiResult<u32> {
    crate::ops::teach_label_rule(label, kind, profile_id)
}

/// Forget a taught rule. Knowledge only — an open document keeps its tokens.
pub fn forget_label_rule(id: u32) -> ApiResult<()> {
    crate::ops::forget_label_rule(id)
}

/// Every rule the person taught, newest first.
pub fn label_rules() -> ApiResult<Vec<LabelRuleRow>> {
    crate::ops::label_rules()
}

/// A language this build does not carry yet.
///
/// Shown under a line, greyed and unchoosable, so that a person can see where
/// the product is going without being offered something that is not there. The
/// list lives in the core beside the packs themselves: a screen with its own
/// copy would go on promising a language after it had shipped, or after it had
/// been dropped.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct LanguageRow {
    /// ISO 639-1.
    pub id: String,
    /// The language's own name for itself — what a person looks for.
    pub label: String,
    /// Does this build carry rules of its own for it? False means the general
    /// rules, the vault and the person's own list, and no dictionary.
    pub has_rules: bool,
}

/// Every language a person may choose, the ones with rules first.
///
/// 041-Q: this used to be `planned_packs`, a short list of languages «that are
/// coming», and a language not on it could not be chosen at all. The owner
/// could not pick Arabic on a build whose vault had an Arabic list in it. A
/// language with no pack is still a language: the general rules run, the rows
/// in `sets/world.rs` run, the vault runs, and the person's own list for that
/// language runs. Only another language's dictionary stays off.
pub fn languages() -> ApiResult<Vec<LanguageRow>> {
    Ok(crate::scanner::languages::all())
}

/// The installed privacy packs. A pack is a detection engine, not a UI language.
pub fn packs() -> ApiResult<Vec<PackRow>> {
    crate::ops::packs()
}

/// Override the pack for this session: app default → profile → session.
pub fn switch_pack(session: SessionId, pack_id: String) -> ApiResult<RescanOutcome> {
    crate::ops::switch_pack(session, pack_id)
}

// ---------------------------------------------------------------- providers

/// The providers and whether each is connected.
/// Every model this build can offer, with what each one can do.
///
/// The catalogue the screens read. One layer, static in V1 — a registry inside
/// the application is honest about being a list we maintain, and a marketplace
/// is not in this phase.
pub fn models() -> ApiResult<Vec<ModelDescriptor>> {
    crate::ops::models()
}

pub fn providers() -> ApiResult<Vec<ProviderRow>> {
    crate::ops::providers()
}

/// Hand a provider its credential. It goes into the sealed vault if one is open,
/// and otherwise stays in memory for this run only — never to a file in the
/// clear, and never back across this boundary.
pub fn connect_provider(provider: ProviderId, credential: String, base_url: Option<String>, model: Option<String>) -> ApiResult<ProviderRow> {
    crate::ops::connect_provider(provider, credential, base_url, model)
}

/// Change where a provider is reached and which model is asked, without touching
/// its credential — which the UI does not have and is never given back.
///
/// The model is a **setting, not part of the security contract**: models come and
/// go, and a list of their names has no business being compiled into Rust.
pub fn configure_provider(provider: ProviderId, base_url: Option<String>, model: Option<String>) -> ApiResult<ProviderRow> {
    crate::ops::configure_provider(provider, base_url, model)
}

/// Forget a provider's credential, here and in the vault.
pub fn disconnect_provider(provider: ProviderId) -> ApiResult<ProviderRow> {
    crate::ops::disconnect_provider(provider)
}

/// Send the word "ping" and nothing of yours, to see if a provider answers.
/// Returns how many milliseconds the round trip took.
pub fn test_provider(provider: ProviderId) -> ApiResult<u32> {
    crate::ops::test_provider(provider)
}

// ---------------------------------------------------------------- truth snapshots

/// Home, as one read. The counts, the vault, the providers — the same object.
pub fn home_snapshot() -> ApiResult<HomeSnapshot> {
    crate::ops::home_snapshot()
}

/// The workspace, as one read. Counts are derived from `findings`.
pub fn workspace_snapshot(session: SessionId) -> ApiResult<WorkspaceSnapshot> {
    crate::ops::workspace_snapshot(session)
}

/// The vault room, as one read. Header and body draw from this object.
pub fn vault_snapshot() -> ApiResult<VaultSnapshot> {
    crate::ops::vault_snapshot()
}

/// My Privacy Rules, from the vault. `profile_id` narrows to effective rules.
pub fn privacy_rules_snapshot(profile_id: Option<String>) -> ApiResult<PrivacyRulesSnapshot> {
    crate::ops::privacy_rules_snapshot(profile_id)
}

/// Providers, including where each credential actually lives.
pub fn provider_snapshot() -> ApiResult<ProviderSnapshot> {
    crate::ops::provider_snapshot()
}

/// One answer, both views, as one read.
pub fn answer_snapshot(session: SessionId, answer: AnswerId) -> ApiResult<AnswerSnapshot> {
    crate::ops::answer_snapshot(session, answer)
}
