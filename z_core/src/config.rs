//! `ZCFG` — the one unencrypted file this program writes.
//!
//! The owner allowed it on 27 September, and allowed it **narrowly**. The core
//! now writes two kinds of file and no others:
//!
//! ```text
//! ZVLT   the sealed vault   secrets, identities, profiles, credentials
//! ZCFG   this              non-secret settings, from a closed list
//! ```
//!
//! His rule, which decides every future field:
//!
//! > **If the information could say anything about the user's work or their
//! > clients, it does not belong in ZCFG.**
//!
//! So this file may never hold a client's name, the active profile, a document
//! path, a list of recent files, any original or safe text, a token, a provider
//! credential, sensitive vault metadata, or a search history.
//!
//! ## How that is made true, rather than promised
//!
//! There is **no map** here. The file is written from a struct of five scalar
//! fields, and the writer emits those names and nothing else — so a field that
//! is not in the list cannot be written, because it does not exist. The list's
//! own length is declared once and counted by gate **G18a**, which is why the
//! number is not repeated in prose that can drift away from it.
//!
//! And the two fields that are text are **checked before they are written**:
//! a language is two lowercase letters, a pack id is short and plain. Without
//! that, `ui_language = "Nordstern Consulting GmbH"` would be a client's name
//! in a plaintext file, put there through a field that was on the list.
//!
//! Reading is forgiving in one direction only: an unknown key is skipped, so a
//! file from a later version still opens. Nothing unknown is ever written back.

use std::path::{Path, PathBuf};

use crate::api::{ApiError, ApiResult};

const MAGIC: &str = "ZCFG1";
const FILE_NAME: &str = "settings.zcfg";
/// Bumped when the meaning of a field changes. Adding a field does not need it.
const SCHEMA_VERSION: u32 = 1;

/// The whole allowlist, in one place. A reader and a writer both use it, and a
/// gate counts it.
const ALLOWED: [&str; 6] = [
    "schema_version",
    "first_run_completed",
    "ui_language",
    "default_privacy_pack",
    "original_pane_percent",
    "columns_in_step",
];

/// The non-secret settings, as they sit in the file.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct AppConfig {
    pub first_run_completed: bool,
    pub ui_language: String,
    pub default_privacy_pack: String,
    /// How much of the Workspace's width the Original column takes, as a
    /// percentage — the one thing on this list that is about a window.
    ///
    /// It lives here and not in the vault because the Workspace is drawn before
    /// any vault exists, and a person who never makes one would lose the
    /// handle's position at every launch. It names nothing of anybody's work:
    /// it is a number between 20 and 80.
    pub original_pane_percent: u32,
    /// Do the two columns scroll together? (041-L.)
    ///
    /// Beside the handle's position and for the same reason: the Workspace is
    /// drawn before any vault exists, and a person who never makes one should
    /// not have to switch this on at every launch. It is one bit and it names
    /// nothing — not a document, not a page, not a person.
    pub columns_in_step: bool,
}

impl Default for AppConfig {
    fn default() -> Self {
        Self {
            first_run_completed: false,
            ui_language: "en".to_string(),
            default_privacy_pack: "de".to_string(),
            // Half and half: the product's whole claim is that a person can
            // compare the two columns, so neither starts larger than the other.
            original_pane_percent: 50,
            // On, because the complaint this answers was «I work on the first
            // screen and do not find my work on the second». A person who
            // wants the columns apart says so once.
            columns_in_step: true,
        }
    }
}

/// Is this a value we are willing to put in a plaintext file?
///
/// Short, lowercase, letters and dashes. A language code and a pack id both fit
/// easily; a person's name, a company, an IBAN, a path and a sentence all fail.
fn is_a_plain_tag(value: &str) -> bool {
    !value.is_empty()
        && value.len() <= 16
        && value
            .chars()
            .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '-')
}

impl AppConfig {
    /// The file's text. The names, in one place, with nothing dynamic.
    fn to_text(&self) -> String {
        format!(
            "{MAGIC}\n\
             schema_version={SCHEMA_VERSION}\n\
             first_run_completed={}\n\
             ui_language={}\n\
             default_privacy_pack={}\n\
             original_pane_percent={}\n\
             columns_in_step={}\n",
            self.first_run_completed,
            self.ui_language,
            self.default_privacy_pack,
            self.original_pane_percent.clamp(20, 80),
            self.columns_in_step,
        )
    }

    /// Refuse to write anything that does not look like a setting.
    ///
    /// This is the allowlist's teeth. A name on the list is not enough: the
    /// value has to be the shape of that setting, or a caller could put a
    /// client's name into a field that was allowed.
    fn checked(&self) -> ApiResult<Self> {
        for (field, value) in [
            ("ui_language", &self.ui_language),
            ("default_privacy_pack", &self.default_privacy_pack),
        ] {
            if !is_a_plain_tag(value) {
                return Err(ApiError::InputRefused {
                    reason: format!(
                        "{field} may only be a short plain tag; nothing that could name a person, \
                         a client or a file is written to {FILE_NAME}"
                    ),
                });
            }
        }
        Ok(self.clone())
    }

    fn from_text(text: &str) -> Self {
        let mut out = Self::default();
        for line in text.lines().skip(1) {
            let Some((key, value)) = line.split_once('=') else {
                continue;
            };
            let (key, value) = (key.trim(), value.trim());
            // An unknown key is skipped, so a file from a later build still
            // opens. It is never written back, because there is nowhere to put
            // it: this struct has its fields and no map.
            if !ALLOWED.contains(&key) {
                continue;
            }
            match key {
                "first_run_completed" => out.first_run_completed = value == "true",
                "columns_in_step" => out.columns_in_step = value == "true",
                "ui_language" if is_a_plain_tag(value) => out.ui_language = value.to_string(),
                "default_privacy_pack" if is_a_plain_tag(value) => {
                    out.default_privacy_pack = value.to_string()
                }
                // A number, and a number in its own range: a file edited by
                // hand cannot make a column disappear.
                "original_pane_percent" => {
                    if let Ok(percent) = value.parse::<u32>() {
                        out.original_pane_percent = percent.clamp(20, 80);
                    }
                }
                _ => {}
            }
        }
        out
    }
}

/// Where the file is, and what it last said.
#[derive(Debug, Default)]
pub(crate) struct ConfigStore {
    dir: Option<PathBuf>,
    current: AppConfig,
}

impl ConfigStore {
    pub(crate) fn set_dir(&mut self, dir: &Path) -> ApiResult<()> {
        self.dir = Some(dir.to_path_buf());
        self.current = self.read_from_disk()?;
        Ok(())
    }

    fn path(&self) -> Option<PathBuf> {
        self.dir.as_ref().map(|d| d.join(FILE_NAME))
    }

    fn read_from_disk(&self) -> ApiResult<AppConfig> {
        let Some(path) = self.path() else {
            return Ok(AppConfig::default());
        };
        let bytes = match crate::secure_file::read_no_follow(&path, "settings.zcfg")? {
            Some(bytes) => bytes,
            // A missing file is not an error: it means «no settings yet», which
            // is exactly what a first run is.
            None => return Ok(AppConfig::default()),
        };
        let config = match String::from_utf8(bytes) {
            Ok(text) if text.starts_with(MAGIC) => AppConfig::from_text(&text),
            // A foreign file is not an error: it means «no settings yet».
            _ => AppConfig::default(),
        };
        Ok(config)
    }

    pub(crate) fn get(&self) -> AppConfig {
        self.current.clone()
    }

    pub(crate) fn save(&mut self, next: AppConfig) -> ApiResult<AppConfig> {
        let next = next.checked()?;
        let Some(path) = self.path() else {
            // No folder yet: kept for this run, and the caller is told so by
            // `Settings::session_only` as usual.
            self.current = next.clone();
            return Ok(next);
        };
        crate::secure_file::replace_atomically(&path, "zcfg.new", next.to_text().as_bytes(), "settings.zcfg")?;
        self.current = next.clone();
        Ok(next)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_file_holds_its_names_and_no_others() {
        let text = AppConfig {
            first_run_completed: true,
            ui_language: "de".to_string(),
            default_privacy_pack: "de".to_string(),
            original_pane_percent: 55,
            columns_in_step: false,
        }
        .to_text();

        assert!(text.starts_with(MAGIC));
        let keys: Vec<&str> = text
            .lines()
            .skip(1)
            .filter_map(|l| l.split_once('=').map(|(k, _)| k))
            .collect();
        assert_eq!(keys, ALLOWED, "the file's keys are the allowlist, in order");
        assert!(text.contains("schema_version=1"));
        assert!(text.contains("first_run_completed=true"));
        // 041-F — the one window preference, written as a number in its range.
        assert!(text.contains("original_pane_percent=55"));
        let read = AppConfig::from_text(&text);
        assert_eq!(read.original_pane_percent, 55, "the handle's place did not survive the file");
        let silly = AppConfig::from_text(&text.replace("original_pane_percent=55", "original_pane_percent=0"));
        assert_eq!(silly.original_pane_percent, 20, "a column could be made to disappear by hand");

        // 041-L — the other window preference, and it is one bit. It is written
        // as it stands, read back as it stands, and **absent** means the
        // default, which is on: a file from an older build must leave the
        // columns following each other, not drifting apart silently.
        assert!(text.contains("columns_in_step=false"));
        assert!(!AppConfig::from_text(&text).columns_in_step);
        let older = text
            .lines()
            .filter(|l| !l.starts_with("columns_in_step="))
            .collect::<Vec<_>>()
            .join("\n");
        assert!(
            AppConfig::from_text(&older).columns_in_step,
            "a file written before 041-L must still bring the columns in step"
        );
    }

    #[test]
    fn a_value_that_could_name_a_client_is_refused_not_written() {
        // The allowlist's teeth. Every one of these is a name on the list with a
        // value that has no business in a plaintext file.
        for bad in [
            "Nordstern Consulting GmbH",
            "Thomas Müller",
            "/home/anna/Vertrag.pdf",
            "DE89370400440532013000",
            "__Z_AB12_PERSON_9XQ4__",
            "",
            "a very long string indeed",
        ] {
            let c = AppConfig {
                first_run_completed: true,
                ui_language: bad.to_string(),
                default_privacy_pack: "de".to_string(),
                original_pane_percent: 50,
                columns_in_step: true,
            };
            assert!(c.checked().is_err(), "«{bad}» should not be writable");
        }
        // And the shapes that are settings do pass.
        for good in ["en", "de", "ur", "de-at"] {
            let c = AppConfig {
                first_run_completed: false,
                ui_language: good.to_string(),
                default_privacy_pack: good.to_string(),
                original_pane_percent: 50,
                columns_in_step: true,
            };
            assert!(c.checked().is_ok(), "«{good}» is a setting");
        }
    }

    #[test]
    fn an_unknown_key_is_skipped_and_never_written_back() {
        let text = format!(
            "{MAGIC}\nschema_version=1\nfirst_run_completed=true\nui_language=de\n\
             recent_file=/home/anna/Vertrag.pdf\nactive_client=Nordstern\n"
        );
        let read = AppConfig::from_text(&text);
        assert!(read.first_run_completed);
        assert_eq!(read.ui_language, "de");
        // The two keys that do not belong were skipped, and cannot come back:
        // there is nowhere in the struct to keep them.
        let back = read.to_text();
        assert!(!back.contains("recent_file"), "{back}");
        assert!(!back.contains("Nordstern"), "{back}");
        assert!(!back.contains("Vertrag"), "{back}");
    }

    #[test]
    fn a_missing_or_foreign_file_simply_means_no_settings_yet() {
        let store = ConfigStore::default();
        assert_eq!(store.get(), AppConfig::default());
        assert!(!store.get().first_run_completed, "a fresh device has not been through it");
        assert_eq!(AppConfig::from_text("not our file at all"), AppConfig::default());
    }
}
