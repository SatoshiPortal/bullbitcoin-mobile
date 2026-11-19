//! Bootstrap status, mapped from arti into types we own.
//!
//! This is the information the previous C-ABI wrapper discarded: it reduced
//! the whole of [`arti_client::status::BootstrapStatus`] to a single `bool`
//! captured once at startup. arti's own documentation warns that the status is
//! **not monotonic** — a client can become *less* bootstrapped when
//! connectivity drops or its directory expires — so a one-shot boolean is
//! wrong by construction, and the failure only surfaces later at the
//! application layer.

use arti_client::status::{BlockageKind as ArtiBlockageKind, BootstrapStatus};
use flutter_rust_bridge::frb;

/// Network transport configured for this Tor client.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TorTransport {
    /// Connect to Tor relays directly.
    Direct,
    /// Reach a Tor bridge through the Snowflake pluggable transport.
    Snowflake,
}

/// Why the client believes it cannot make progress.
///
/// Maps [`arti_client::status::BlockageKind`], which is `#[non_exhaustive]`
/// upstream — hence [`BlockageKind::Other`].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BlockageKind {
    /// Bootstrap has not been requested yet.
    ///
    /// Not a fault. arti reports this whenever the client was built with
    /// `BootstrapBehavior::Manual` and has not been told to start, which is
    /// exactly our steady state between `start()` and `bootstrap()`. It must
    /// never be shown to the user as a problem.
    NotStarted,
    /// No TCP connectivity at all.
    Offline,
    /// TCP works but the Tor handshake does not complete.
    ///
    /// This is the censorship signature: a middlebox is inspecting and
    /// dropping Tor traffic. It is the condition that should offer the user
    /// circumvention, and the one plain bridges do *not* fix.
    Filtering,
    /// Some other problem reaching the Tor network.
    CantReachTor,
    /// The device clock is wrong enough to break certificate validation.
    ClockSkewed,
    /// Directory information could not be assembled, with no obvious
    /// connection-level cause.
    CantBootstrap,
    /// A blockage kind added upstream after this mapping was written.
    Other,
}

impl From<ArtiBlockageKind> for BlockageKind {
    fn from(k: ArtiBlockageKind) -> Self {
        match k {
            ArtiBlockageKind::Disabled => Self::NotStarted,
            ArtiBlockageKind::Offline => Self::Offline,
            ArtiBlockageKind::Filtering => Self::Filtering,
            ArtiBlockageKind::CantReachTor => Self::CantReachTor,
            ArtiBlockageKind::ClockSkewed => Self::ClockSkewed,
            ArtiBlockageKind::CantBootstrap => Self::CantBootstrap,
            // `ArtiBlockageKind` is `#[non_exhaustive]`: a new upstream variant
            // must not break the build, but it must not silently look healthy
            // either.
            _ => Self::Other,
        }
    }
}

impl BlockageKind {
    /// Whether this blockage is consistent with active network censorship.
    ///
    /// Advisory only. arti documents `blocked()` as a best-effort diagnostic
    /// that "may declare that Arti is stuck for reasons that are incorrect".
    /// Use it to *offer* circumvention, never to assert to the user that they
    /// are being censored.
    #[frb(sync)]
    pub fn suggests_censorship(self) -> bool {
        matches!(self, Self::Filtering | Self::CantReachTor)
    }

    /// Whether this blockage is worth telling the user about at all.
    ///
    /// [`BlockageKind::NotStarted`] is arti describing our own deliberate
    /// `Manual` bootstrap mode back to us; reporting it would put a permanent
    /// bogus warning on screen before the user has done anything.
    #[frb(sync)]
    pub fn is_user_visible(self) -> bool {
        !matches!(self, Self::NotStarted)
    }
}

/// A blockage: a machine-readable kind plus arti's human-readable detail.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Blockage {
    /// Programmatic discriminant, safe to switch on.
    pub kind: BlockageKind,
    /// arti's own wording. Developer/diagnostic detail, not a localized string.
    pub message: String,
}

/// A snapshot of how ready the client is.
#[derive(Debug, Clone, PartialEq)]
pub struct TorStatus {
    /// Rough bootstrap progress, 0.0 (just started) to 1.0 (ready).
    pub fraction: f32,
    /// Whether a new request can be acted on right now.
    pub ready_for_traffic: bool,
    /// Present when arti believes it is stuck.
    pub blockage: Option<Blockage>,
    /// arti's one-line summary of where bootstrap is, e.g. `"36%: connecting
    /// successfully; directory is fetching authority certificates (0/9)"`, or
    /// `"Stuck at 0%: ..."` followed by the blockage while arti is stuck.
    ///
    /// This is the `Display` of [`BootstrapStatus`], which arti documents as
    /// designed for human readability, not machine parsing: show or log it as
    /// diagnostic detail, never switch on it, and use [`TorStatus::fraction`]
    /// and [`TorStatus::blockage`] for logic. Not localized. Empty once the
    /// service has stopped.
    pub stage: String,
    /// Route configured for this client.
    ///
    /// This does not by itself mean that Snowflake connected. Consumers must
    /// also require [`TorStatus::ready_for_traffic`] before claiming that.
    pub transport: TorTransport,
}

impl TorStatus {
    pub(crate) fn stopped(transport: TorTransport) -> Self {
        Self {
            fraction: 0.0,
            ready_for_traffic: false,
            blockage: None,
            stage: String::new(),
            transport,
        }
    }

    pub(crate) fn from_bootstrap(s: &BootstrapStatus, transport: TorTransport) -> Self {
        Self {
            fraction: s.as_frac(),
            ready_for_traffic: s.ready_for_traffic(),
            blockage: s.blocked().map(|b| Blockage {
                kind: b.kind().into(),
                message: b.message().to_string(),
            }),
            stage: s.to_string(),
            transport,
        }
    }

    /// Whether the client is stuck in a way consistent with censorship.
    #[frb(sync)]
    pub fn suggests_censorship(&self) -> bool {
        self.blockage
            .as_ref()
            .is_some_and(|b| b.kind.suggests_censorship())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn filtering_is_the_censorship_signal() {
        assert!(BlockageKind::Filtering.suggests_censorship());
        assert!(BlockageKind::CantReachTor.suggests_censorship());
    }

    #[test]
    fn offline_and_clock_skew_are_not_censorship() {
        // Being offline or having a wrong clock is a local problem. Offering
        // bridges here would send the user down the wrong path.
        assert!(!BlockageKind::Offline.suggests_censorship());
        assert!(!BlockageKind::ClockSkewed.suggests_censorship());
        assert!(!BlockageKind::CantBootstrap.suggests_censorship());
    }

    #[test]
    fn unknown_upstream_kind_is_not_treated_as_censorship() {
        assert!(!BlockageKind::Other.suggests_censorship());
    }

    #[test]
    fn not_started_is_neither_censorship_nor_user_visible() {
        // Observed live: with BootstrapBehavior::Manual, arti reports
        // `Disabled` ("Client is waiting to be told to bootstrap") the whole
        // time between start() and bootstrap(). Showing that as a blockage
        // would be a permanent false alarm.
        assert!(!BlockageKind::NotStarted.suggests_censorship());
        assert!(!BlockageKind::NotStarted.is_user_visible());
    }

    #[test]
    fn real_blockages_are_user_visible() {
        for k in [
            BlockageKind::Offline,
            BlockageKind::Filtering,
            BlockageKind::CantReachTor,
            BlockageKind::ClockSkewed,
            BlockageKind::CantBootstrap,
            BlockageKind::Other,
        ] {
            assert!(k.is_user_visible(), "{k:?} should be reportable");
        }
    }

    #[test]
    fn status_without_blockage_is_not_censored() {
        let s = TorStatus {
            fraction: 1.0,
            ready_for_traffic: true,
            blockage: None,
            stage: "100%: connecting successfully; directory is usable".into(),
            transport: TorTransport::Direct,
        };
        assert!(!s.suggests_censorship());
    }

    #[test]
    fn status_with_filtering_blockage_is_censored() {
        let s = TorStatus {
            fraction: 0.1,
            ready_for_traffic: false,
            blockage: Some(Blockage {
                kind: BlockageKind::Filtering,
                message: "Our internet connection seems filtered".into(),
            }),
            stage: "Stuck at 10%: Our internet connection seems filtered".into(),
            transport: TorTransport::Direct,
        };
        assert!(s.suggests_censorship());
    }

    #[test]
    fn default_arti_status_maps_to_not_ready() {
        // `BootstrapStatus: Default` is arti's "nothing has happened yet".
        let s = TorStatus::from_bootstrap(&BootstrapStatus::default(), TorTransport::Direct);
        assert!(!s.ready_for_traffic);
        assert!(s.fraction < 1.0);
        assert_eq!(s.transport, TorTransport::Direct);
    }

    #[test]
    fn stage_is_arti_display_of_the_same_snapshot() {
        let arti = BootstrapStatus::default();
        let s = TorStatus::from_bootstrap(&arti, TorTransport::Direct);
        assert_eq!(s.stage, arti.to_string());
        // The percentage leads the line, so even a truncated UI label carries
        // the progress it describes.
        let percent = (s.fraction * 100.0).round() as u32;
        assert!(
            s.stage.starts_with(&format!("{percent}%"))
                || s.stage.starts_with(&format!("Stuck at {percent}%")),
            "unexpected stage text: {:?}",
            s.stage
        );
    }

    #[test]
    fn stopped_status_has_no_stage() {
        let s = TorStatus::stopped(TorTransport::Snowflake);
        assert!(s.stage.is_empty());
        assert!(!s.ready_for_traffic);
    }
}
