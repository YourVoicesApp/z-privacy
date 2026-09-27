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
    /// A folder, a profile or a pack could not be used, and why.
    ImportRefused { reason: String },
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
            Self::ImportRefused { reason } => write!(f, "that could not be used: {reason}"),
            Self::DocumentRefused { reason, detail } => {
                write!(f, "this document was not imported ({reason:?}): {detail}")
            }
            Self::BadSpan { reason } => write!(f, "bad selection: {reason}"),
            Self::UnknownToken => write!(f, "no such token in this session"),
            Self::NothingToSend => write!(f, "there is nothing to send"),
            Self::PayloadRefused { reason } => write!(f, "this payload was refused by its own audit: {reason}"),
            Self::NetworkRefused { reason, detail } => write!(f, "the request did not go through ({reason:?}): {detail}"),
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
    /// The working language, `en` or `de`. It picks the pack today; the
    /// interface follows when it is translated.
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
}

/// An installed detection pack. The **label is the pack's own**, not the UI's: a
/// screen may not invent the name of a rules engine.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PackRow {
    pub id: String,
    pub label: String,
}

/// A provider as the UI is allowed to see it: a name, and whether it is
/// connected. The credential itself is not in this type and has no getter
/// anywhere in the contract — once given, it never comes back out.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProviderRow {
    pub id: String,
    pub label: String,
    /// True when a credential for this provider exists in this run.
    pub connected: bool,
    /// True when that credential lives only in memory, because there was no open
    /// vault to seal it into. It is gone when the app closes, and the UI says so
    /// rather than letting the user believe it was saved.
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
pub enum Scope {
    /// This place in this document only.
    Once,
    /// Every appearance in this conversation, under one token.
    Conversation,
    /// Kept in the vault and found by itself from now on.
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
    pub source: Source,
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

/// What the AI will receive, for showing in the right-hand column.
#[derive(Clone, PartialEq, Eq)]
pub struct PayloadView {
    pub text: String,
    pub protected_count: u32,
    pub open_suggestions: u32,
}

/// A row of the tokens panel. The real value is not in it.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TokenRow {
    pub token: String,
    pub kind: Kind,
    pub scope: Scope,
    pub source: Source,
    pub source_detail: String,
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

/// A piece of a restored answer. `restored` is true for words put back here.
#[derive(Clone, PartialEq, Eq)]
pub struct Segment {
    pub text: String,
    pub restored: bool,
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
    pub source: Source,
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
/// `WrongPassphrase` carries nothing, and that is deliberate. It used to carry
/// `attempts_left`, which was always 0 — a field that looked like information
/// and was not, and which a screen would have shown as «no tries left» to
/// someone who had simply mistyped. (Task 032; the same family as the
/// `open_suggestions` that was always 0.)
///
/// There is no attempt limit and there should not be one: locking a **local**
/// file after three tries protects nobody — whoever has the file does not use
/// our window — while a real person who mistypes would be shut out of their own
/// vault forever. The cost of guessing is Argon2id at 64 MiB a try, which is a
/// defence that cannot be walked around.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VaultUnlockOutcome {
    Unlocked { identities: u32, values: u32 },
    WrongPassphrase,
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
            .field("restored", &self.restored)
            .finish()
    }
}

// ---------------------------------------------------------------- session

/// Open a conversation. `pack_id` is the session's override; empty means the
/// profile's pack, and failing that the app default.
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

// ---------------------------------------------------------------- tokens

/// Show one value locally, for a moment. This does not touch any payload.
pub fn reveal(session: SessionId, token: String) -> ApiResult<RevealedValue> {
    crate::ops::reveal(session, token)
}

/// Put the token back in the view.
pub fn hide(session: SessionId, token: String) -> ApiResult<()> {
    crate::ops::hide(session, token)
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

/// Incoming only: hand the core an answer as it arrived. M6 replaces this with
/// the real network path; until then it is how a provider's reply gets in.
pub fn ingest_answer(session: SessionId, raw: String) -> ApiResult<AnswerId> {
    crate::ops::ingest_answer(session, raw)
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

pub fn create_profile(name: String) -> ApiResult<String> {
    crate::ops::create_profile(name)
}

// ---------------------------------------------------------------- profiles, packs

/// The profiles, as the switcher lists them: `id\tname`.
pub fn profiles() -> ApiResult<Vec<ProfileRow>> {
    crate::ops::profiles()
}

/// Switch profile. Tokens already given stand; only new matching follows.
pub fn switch_profile(session: SessionId, profile_id: String) -> ApiResult<SwitchOutcome> {
    crate::ops::switch_profile(session, profile_id)
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
