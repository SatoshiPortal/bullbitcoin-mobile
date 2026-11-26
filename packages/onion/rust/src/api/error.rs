//! The failure family exposed across the FFI boundary.
//!
//! Deliberately a small, closed set of *our* types: no `arti_client::Error`,
//! no `anyhow`, nothing from a dependency. The Dart side switches on
//! [`TorFailureKind`] exhaustively, so every variant must stay meaningful to a
//! user-facing message.

use flutter_rust_bridge::frb;
use std::fmt;

/// Why a Tor operation failed.
///
/// Mirrors the shape the Dart side needs, not arti's internal taxonomy.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TorFailureKind {
    /// The state/cache directory could not be prepared, or the config was rejected.
    Configuration,
    /// The local SOCKS listener could not be bound.
    ListenerBind,
    /// Bootstrap did not complete. Inspect the last [`crate::api::status::TorStatus`]
    /// for a `blockage` explaining why.
    Bootstrap,
    /// A connection through Tor failed (used by the reachability probe).
    Connect,
    /// The probe did not complete within its deadline.
    Timeout,
    /// The service was not started, or was already stopped.
    NotRunning,
    /// Anything we did not model. `logMessage` is for our logs, never for the user.
    Unexpected,
}

impl fmt::Display for TorFailureKind {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let s = match self {
            Self::Configuration => "configuration",
            Self::ListenerBind => "listener-bind",
            Self::Bootstrap => "bootstrap",
            Self::Connect => "connect",
            Self::Timeout => "timeout",
            Self::NotRunning => "not-running",
            Self::Unexpected => "unexpected",
        };
        f.write_str(s)
    }
}

/// A modelled, recoverable failure.
///
/// `log_message` carries developer detail. It is logged on our side and must
/// never be rendered to the end user verbatim — the Dart layer maps
/// [`TorFailure::kind`] to a localized string.
#[derive(Debug, Clone, thiserror::Error)]
#[error("{kind}: {log_message}")]
pub struct TorFailure {
    /// The programmatic discriminant.
    pub kind: TorFailureKind,
    /// Developer-facing detail. Never user-facing.
    pub log_message: String,
}

#[frb(ignore)]
impl TorFailure {
    /// Build a failure of `kind` with developer detail `msg`.
    pub fn new(kind: TorFailureKind, msg: impl fmt::Display) -> Self {
        Self {
            kind,
            log_message: msg.to_string(),
        }
    }

    /// Shorthand for [`TorFailureKind::Configuration`].
    pub fn configuration(msg: impl fmt::Display) -> Self {
        Self::new(TorFailureKind::Configuration, msg)
    }

    /// Shorthand for [`TorFailureKind::ListenerBind`].
    pub fn listener_bind(msg: impl fmt::Display) -> Self {
        Self::new(TorFailureKind::ListenerBind, msg)
    }

    /// Shorthand for [`TorFailureKind::Bootstrap`].
    pub fn bootstrap(msg: impl fmt::Display) -> Self {
        Self::new(TorFailureKind::Bootstrap, msg)
    }

    /// Shorthand for [`TorFailureKind::Connect`].
    pub fn connect(msg: impl fmt::Display) -> Self {
        Self::new(TorFailureKind::Connect, msg)
    }

    /// Shorthand for [`TorFailureKind::Timeout`].
    pub fn timeout(msg: impl fmt::Display) -> Self {
        Self::new(TorFailureKind::Timeout, msg)
    }

    /// Shorthand for [`TorFailureKind::NotRunning`].
    pub fn not_running(msg: impl fmt::Display) -> Self {
        Self::new(TorFailureKind::NotRunning, msg)
    }

    /// Shorthand for [`TorFailureKind::Unexpected`].
    pub fn unexpected(msg: impl fmt::Display) -> Self {
        Self::new(TorFailureKind::Unexpected, msg)
    }
}

/// Result alias for this crate's public surface.
pub type TorResult<T> = Result<T, TorFailure>;

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kind_is_stable_for_logs() {
        assert_eq!(TorFailureKind::Bootstrap.to_string(), "bootstrap");
        assert_eq!(TorFailureKind::Timeout.to_string(), "timeout");
    }

    #[test]
    fn display_keeps_developer_detail_out_of_kind() {
        let f = TorFailure::bootstrap("directory fetch gave up after 3 tries");
        assert_eq!(f.kind, TorFailureKind::Bootstrap);
        assert!(f.log_message.contains("gave up"));
        // The Display impl is for our logs; the Dart side never renders it.
        assert!(f.to_string().starts_with("bootstrap: "));
    }
}
