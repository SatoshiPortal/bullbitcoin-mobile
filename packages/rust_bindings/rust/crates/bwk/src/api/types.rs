use flutter_rust_bridge::frb;

#[frb(unignore)]
#[derive(Debug, Clone)]
pub enum SpNetwork {
    Bitcoin,
    Signet,
    Testnet,
    Regtest,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub enum CoinSource {
    Sp,
    Segwit,
    Taproot,
    Other,
}

#[frb(unignore)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum UnifiedCoinStatus {
    Unconfirmed,
    Unspent,
    Spent,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub enum SpNotification {
    ScanStarted {
        from: u32,
        to: u32,
    },
    ScanReceiveProgress {
        current: u32,
        end: u32,
    },
    ScanCompleted,
    /// Receive and spend frontiers persisted when the scan stopped, `None` for
    /// one never recorded.
    ScanStopped {
        last_scanned: Option<u32>,
        last_spend: Option<u32>,
    },
    ScanFailed {
        message: String,
    },
    NewOutput {
        outpoint: String,
        amount_sat: u64,
    },
    OutputSpent {
        outpoint: String,
    },
    Broadcasted {
        txid: String,
    },
    BroadcastFailed {
        message: String,
    },
    ElectrumTx {
        kind: CoinSource,
        txid: String,
        amount_sat: u64,
        height: Option<u32>,
    },
    ScanSpendProgress {
        current: u32,
        end: u32,
    },
    HeaderProgressStarted {
        phase: HeaderProgressPhase,
        start: u32,
        end: u32,
    },
    HeaderProgress {
        phase: HeaderProgressPhase,
        current: u32,
        end: u32,
    },
    HeaderProgressCompleted {
        phase: HeaderProgressPhase,
    },
    HeaderProgressFailed {
        phase: HeaderProgressPhase,
    },
    PaymentHistoryUpdated,
    /// The electrum connection dropped; the listener does not reconnect on its
    /// own.
    ElectrumDisconnected,
    /// The chain reorganized above `fork_height`; what the scan recorded above
    /// it was rolled back and is scanned again.
    Reorg {
        fork_height: u32,
    },
    /// The electrum server's header chain does not hold the checkpoint block.
    HeaderCheckpointMismatch,
    /// The electrum listener connected, e.g. after a restart.
    ElectrumConnected,
}

#[frb(unignore)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HeaderProgressPhase {
    Replay,
    InitialSync,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub struct SpCoinView {
    pub outpoint: String,
    pub amount_sat: u64,
    pub height: Option<u32>,
    pub is_spendable: bool,
    pub label: Option<String>,
}

/// Typed payment direction surfaced to Dart so consumers can `match` on
/// it exhaustively instead of string-comparing.
#[frb(unignore)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpPaymentDirection {
    Receive,
    Send,
    SelfSend,
}

#[frb(unignore)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpPaymentStatus {
    Unconfirmed,
    ConfirmedUnverified,
    Verified,
    VerifyFailed,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub struct SpPaymentView {
    pub txid: String,
    pub direction: SpPaymentDirection,
    pub status: SpPaymentStatus,
    pub amount_sat: u64,
    pub fee_sat: Option<u64>,
    pub height: Option<u32>,
    pub timestamp: Option<u64>,
    pub label: Option<String>,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub struct UnifiedCoinView {
    pub source: CoinSource,
    pub outpoint: String,
    pub amount_sat: u64,
    pub height: Option<u32>,
    pub status: UnifiedCoinStatus,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub enum RecipientView {
    Sp {
        address: String,
        amount_sat: u64,
        label: Option<u32>,
        /// Send-max: drain all spendable coins to this output (amount_sat is
        /// ignored on the way in; the computed amount is reported back).
        is_max: bool,
    },
    Standard {
        address: String,
        amount_sat: u64,
        is_max: bool,
    },
}

#[frb(unignore)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SpRecipientAddressKind {
    Sp,
    Standard,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub struct TxSimulation {
    pub inputs: Vec<UnifiedCoinView>,
    pub outputs: Vec<RecipientView>,
    pub fee_sat: u64,
    pub change_sat: u64,
    /// The threshold `prepare_psbt` used, reused by `finalize_psbt`. `None`
    /// keeps bwk's default.
    pub change_dust_threshold: Option<u64>,
}

#[frb(unignore)]
#[derive(Debug, Clone)]
pub struct SpBalanceView {
    pub confirmed_sat: u64,
    pub total_unified_sat: u64,
    pub last_scanned_height: Option<u32>,
}

/// A block the app trusts, which the header chain must contain. `hash` is the
/// block hash in hex. `height` must sit on a 2016 block retarget boundary.
/// A mainnet account needs one: bwk panics opening its header store without it.
#[frb(unignore)]
#[derive(Debug, Clone)]
pub struct SpHeaderCheckpoint {
    pub height: u32,
    pub hash: String,
}

#[derive(Debug, Clone)]
pub struct RegtestDefaults {
    pub is_ok: bool,
    pub error: String,
    pub blindbit_url: String,
    pub p2p_node: String,
    pub electrum_url: String,
}

/// Errors a Silent Payments call can return that a caller must be able to tell
/// apart, rather than matching on message text.
///
/// Everything the Dart side needs to branch on gets its own variant; anything
/// it can only log or show generically stays in [SpError::Other]. Added because
/// consumers were sniffing substrings out of the previous `Result<_, String>`
/// surface, which broke silently whenever a message was reworded.
#[frb(unignore)]
#[derive(Debug, Clone)]
pub enum SpError {
    /// A scan is already running; start another only after it finishes or is
    /// cancelled.
    ScannerAlreadyRunning,
    /// `dispose()` gave up waiting for the inner lock. The session is kept, so
    /// the caller may retry rather than treat the account as gone.
    DisposeTimedOut,
    /// The coin set moved after the simulation the caller confirmed, so the
    /// pinned transaction can no longer be built. The caller must re-confirm.
    /// `detail` names the offending outpoint, for logs only.
    SimulationDrifted { detail: String },
    /// Anything else. `message` is for logs, never for the user.
    Other { message: String },
}

impl std::fmt::Display for SpError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ScannerAlreadyRunning => write!(f, "scanner already running"),
            Self::DisposeTimedOut => {
                write!(
                    f,
                    "dispose timed out: inner lock still held; retry or restart"
                )
            }
            Self::SimulationDrifted { detail } => write!(
                f,
                "transaction inputs changed since confirmation: {detail}; please re-confirm"
            ),
            Self::Other { message } => write!(f, "{message}"),
        }
    }
}

impl From<String> for SpError {
    fn from(message: String) -> Self {
        Self::Other { message }
    }
}
