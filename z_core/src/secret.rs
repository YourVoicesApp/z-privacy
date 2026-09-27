//! A string that does not print itself.
//!
//! Invariant G11: no original text and no vault value may reach a log, an error
//! message, or any `Debug` output. The biggest leak path after the network is a
//! line someone adds next year —
//!
//! ```text
//! eprintln!("scan failed on {document:?}");
//! ```
//!
//! — which would put a real client's letter into a log file. So the values are
//! not plain `String`s: they are [`Secret`], whose `Debug` says `[REDACTED]` and
//! whose content can only be reached by calling [`Secret::expose`], a name
//! chosen so that reading it in a diff is uncomfortable.

use std::fmt;

/// Text that must never print itself: the original document, a vault value, a
/// revealed name.
#[derive(Clone, PartialEq, Eq, Default)]
pub(crate) struct Secret(String);

impl Secret {
    pub(crate) fn new(value: impl Into<String>) -> Self {
        Self(value.into())
    }

    /// Read the value. Every call site is a place to ask "does this leave the
    /// device, or reach a log?" — which is the point of the name.
    pub(crate) fn expose(&self) -> &str {
        &self.0
    }

    pub(crate) fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    pub(crate) fn len(&self) -> usize {
        self.0.len()
    }
}

impl fmt::Debug for Secret {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        // Length only. It is useful when debugging and tells nobody anything.
        write!(f, "[REDACTED {} bytes]", self.0.len())
    }
}

impl fmt::Display for Secret {
    /// Displaying is printing, and printing is what G11 forbids.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "[REDACTED]")
    }
}

impl From<String> for Secret {
    fn from(value: String) -> Self {
        Self(value)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn g11_a_secret_does_not_print_itself() {
        let s = Secret::new("Thomas Müller");
        assert!(!format!("{s:?}").contains("Müller"), "Debug leaked the value");
        assert!(!format!("{s}").contains("Müller"), "Display leaked the value");
        assert!(format!("{s:?}").contains("REDACTED"));
        // The value is reachable, but only by asking for it by name.
        assert_eq!(s.expose(), "Thomas Müller");
    }

    #[test]
    fn g11_a_struct_holding_a_secret_is_safe_to_debug() {
        #[derive(Debug)]
        struct Holder {
            #[allow(dead_code)]
            original: Secret,
        }
        let h = Holder {
            original: Secret::new("Kunde: Nordstern GmbH"),
        };
        assert!(!format!("{h:?}").contains("Nordstern"), "{h:?}");
    }
}
