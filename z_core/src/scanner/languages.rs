//! Every language a person may choose, named in its own language.
//!
//! The owner, 6 October, after a run where he could not choose Arabic: «the
//! language list holds every language; we have no problem with the language
//! rules — we will not include them all». So the list and the rules stop being
//! the same question. A language in this table can be chosen today; whether a
//! pack of rules exists for it is a separate fact the row carries, and the
//! screen draws a line between the two rather than hiding half of them.
//!
//! What a language with no pack does: the general rules run (e-mail, IBAN,
//! BIC, telephone, card, and the rest), the rows in `sets/world.rs` run, the
//! vault layer runs, and the person's own list for that language runs. What
//! does not run is another language's dictionary — choosing Arabic must never
//! quietly leave German names switched on.
//!
//! Measured on AR-1, the invented Arabic letter: 5 auto · 2 waiting under a
//! bare «ar», the same as under the German pack, once the BIC row stopped
//! being German (`sets/world.rs`).
//!
//! The codes are ISO 639-1. The name is the language's own name for itself —
//! a person looking for their language looks for the word they would write,
//! not for an English one. Adding a language is one row, and a row is all it
//! takes because nothing here is a rule.

/// `code · the language's own name`.
const TABLE: &[(&str, &str)] = &[
    ("af", "Afrikaans"),
    ("am", "አማርኛ"),
    ("ar", "العربية"),
    ("az", "Azərbaycanca"),
    ("be", "Беларуская"),
    ("bg", "Български"),
    ("bn", "বাংলা"),
    ("bs", "Bosanski"),
    ("ca", "Català"),
    ("cs", "Čeština"),
    ("cy", "Cymraeg"),
    ("da", "Dansk"),
    ("de", "Deutsch"),
    ("el", "Ελληνικά"),
    ("en", "English"),
    ("es", "Español"),
    ("et", "Eesti"),
    ("eu", "Euskara"),
    ("fa", "فارسی"),
    ("fi", "Suomi"),
    ("fr", "Français"),
    ("ga", "Gaeilge"),
    ("gl", "Galego"),
    ("gu", "ગુજરાતી"),
    ("he", "עברית"),
    ("hi", "हिन्दी"),
    ("hr", "Hrvatski"),
    ("hu", "Magyar"),
    ("hy", "Հայերեն"),
    ("id", "Bahasa Indonesia"),
    ("is", "Íslenska"),
    ("it", "Italiano"),
    ("ja", "日本語"),
    ("ka", "ქართული"),
    ("kk", "Қазақша"),
    ("km", "ខ្មែរ"),
    ("kn", "ಕನ್ನಡ"),
    ("ko", "한국어"),
    ("ku", "Kurdî"),
    ("ky", "Кыргызча"),
    ("lo", "ລາວ"),
    ("lt", "Lietuvių"),
    ("lv", "Latviešu"),
    ("mk", "Македонски"),
    ("ml", "മലയാളം"),
    ("mn", "Монгол"),
    ("mr", "मराठी"),
    ("ms", "Bahasa Melayu"),
    ("my", "မြန်မာ"),
    ("nb", "Norsk bokmål"),
    ("ne", "नेपाली"),
    ("nl", "Nederlands"),
    ("nn", "Nynorsk"),
    ("pa", "ਪੰਜਾਬੀ"),
    ("pl", "Polski"),
    ("ps", "پښتو"),
    ("pt", "Português"),
    ("ro", "Română"),
    ("ru", "Русский"),
    ("si", "සිංහල"),
    ("sk", "Slovenčina"),
    ("sl", "Slovenščina"),
    ("sq", "Shqip"),
    ("sr", "Српски"),
    ("sv", "Svenska"),
    ("sw", "Kiswahili"),
    ("ta", "தமிழ்"),
    ("te", "తెలుగు"),
    ("th", "ไทย"),
    ("tl", "Tagalog"),
    ("tr", "Türkçe"),
    ("uk", "Українська"),
    ("ur", "اردو"),
    ("uz", "Oʻzbekcha"),
    ("vi", "Tiếng Việt"),
    ("zh", "中文"),
];

/// Every language, in the order the list draws them: the ones this build has
/// rules for first, then the rest, each group by its code.
pub(crate) fn all() -> Vec<crate::api::LanguageRow> {
    let mut rows: Vec<crate::api::LanguageRow> = TABLE
        .iter()
        .map(|(code, name)| crate::api::LanguageRow {
            id: (*code).to_string(),
            label: (*name).to_string(),
            has_rules: has_rules(code),
        })
        .collect();
    rows.sort_by(|a, b| b.has_rules.cmp(&a.has_rules).then(a.id.cmp(&b.id)));
    rows
}

/// Is this a language this build can be asked to read?
///
/// Every code in the table, and nothing else. A caller cannot invent a
/// language, which is what keeps one list per language true in the vault.
pub(crate) fn known(code: &str) -> bool {
    TABLE.iter().any(|(id, _)| *id == code)
}

/// Does this build carry rules of its own for the language — a dictionary, a
/// set of label rules, or both?
pub(crate) fn has_rules(code: &str) -> bool {
    crate::scanner::sets::all().iter().any(|set| set.id == code)
        || crate::scanner::packs::installed_packs().iter().any(|p| p.id == code)
}
