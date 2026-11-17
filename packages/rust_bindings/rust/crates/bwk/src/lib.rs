#![allow(unexpected_cfgs)]

pub mod api;

#[cfg(not(feature = "bull_sdk"))]
mod frb_generated;

// When building under the `bull_sdk` feature the full flutter_rust_bridge
// generated module (`frb_generated.rs`) is intentionally cfg'd out (the
// aggregator regenerates all wire code). The API layer still references
// `crate::frb_generated::StreamSink`, so we provide a minimal shim.
//
// Why an alias to `StreamSinkBase` instead of re-running the FRB macro:
// `frb_generated_boilerplate!` emits a *per-crate* `StreamSink` newtype that
// wraps `StreamSinkBase` (its inner field is private). The bull_sdk aggregator
// emits its OWN such newtype in its generated wire function and constructs it
// there, so a newtype here would be a DISTINCT nominal type from the one the
// aggregator passes to `SpAccount::init` — the generated call would not type
// check, and the dependency cannot name the aggregator's type (no cyclic dep).
//
// Instead we alias `StreamSink` to the FRB crate's shared `StreamSinkBase`,
// which is the single canonical type re-exported by `flutter_rust_bridge`.
// The aggregator's post-gen `fix_frb_generated.sh` reconstructs a
// `StreamSinkBase` (via its public `::deserialize`, wire-identical to what the
// newtype does internally) for `init`'s argument, so both sides agree on one
// type. The codec is `DcoCodec` to match the aggregator's `full_dep` default
// (`default_stream_sink_codec = DcoCodec`); note this differs from a standalone
// bb-mobile build, whose own codegen defaults to `SseCodec`. `StreamSinkBase`
// only has the codec-level `add_raw`, so the typed `add(SpNotification)` used by
// `sp_account.rs` is provided via the `SpStreamSinkExt` extension trait below.
#[cfg(feature = "bull_sdk")]
mod frb_generated {
    use crate::api::types::SpNotification;
    use flutter_rust_bridge::for_generated::{DcoCodec, StreamSinkBase};
    use flutter_rust_bridge::Rust2DartSendError;

    pub type StreamSink<T, C = DcoCodec> = StreamSinkBase<T, C>;

    pub trait SpStreamSinkExt {
        fn add(&self, value: SpNotification) -> Result<(), Rust2DartSendError>;
    }

    impl SpStreamSinkExt for StreamSinkBase<SpNotification, DcoCodec> {
        fn add(&self, value: SpNotification) -> Result<(), Rust2DartSendError> {
            use flutter_rust_bridge::for_generated::Rust2DartAction;
            use flutter_rust_bridge::IntoIntoDart;
            self.add_raw(DcoCodec::encode(
                Rust2DartAction::Success,
                value.into_into_dart(),
            ))
        }
    }

    use flutter_rust_bridge::for_generated::DartAbi;
    use flutter_rust_bridge::{IntoDart, IntoIntoDart};

    // Wire-identical to the aggregator's mirror `IntoDart for
    // crate::api::simple::SpNotification`: a `[discriminant, fields...]` DCO
    // tuple. dart_bwk cannot name the aggregator's mirror type (no cyclic dep),
    // so the same byte layout is reproduced here for its own type. Variant
    // indices/field order MUST match the mirror in bull_sdk's `simple.rs`.
    impl IntoDart for SpNotification {
        fn into_dart(self) -> DartAbi {
            use crate::api::types::CoinSource;
            fn header_phase_idx(phase: crate::api::types::HeaderProgressPhase) -> i32 {
                match phase {
                    crate::api::types::HeaderProgressPhase::Replay => 0,
                    crate::api::types::HeaderProgressPhase::InitialSync => 1,
                }
            }
            match self {
                SpNotification::ScanStarted { from, to } => {
                    vec![0.into_dart(), from.into_dart(), to.into_dart()].into_dart()
                }
                SpNotification::ScanReceiveProgress { current, end } => {
                    vec![1.into_dart(), current.into_dart(), end.into_dart()].into_dart()
                }
                SpNotification::ScanCompleted => vec![2.into_dart()].into_dart(),
                SpNotification::ScanStopped {
                    last_scanned,
                    last_spend,
                } => vec![
                    3.into_dart(),
                    last_scanned.into_dart(),
                    last_spend.into_dart(),
                ]
                .into_dart(),
                SpNotification::ScanFailed { message } => {
                    vec![4.into_dart(), message.into_dart()].into_dart()
                }
                SpNotification::NewOutput {
                    outpoint,
                    amount_sat,
                } => vec![5.into_dart(), outpoint.into_dart(), amount_sat.into_dart()].into_dart(),
                SpNotification::OutputSpent { outpoint } => {
                    vec![6.into_dart(), outpoint.into_dart()].into_dart()
                }
                SpNotification::Broadcasted { txid } => {
                    vec![7.into_dart(), txid.into_dart()].into_dart()
                }
                SpNotification::BroadcastFailed { message } => {
                    vec![8.into_dart(), message.into_dart()].into_dart()
                }
                SpNotification::ElectrumTx {
                    kind,
                    txid,
                    amount_sat,
                    height,
                } => {
                    let kind_idx: i32 = match kind {
                        CoinSource::Sp => 0,
                        CoinSource::Segwit => 1,
                        CoinSource::Taproot => 2,
                        CoinSource::Other => 3,
                    };
                    vec![
                        9.into_dart(),
                        kind_idx.into_dart(),
                        txid.into_dart(),
                        amount_sat.into_dart(),
                        height.into_dart(),
                    ]
                    .into_dart()
                }
                SpNotification::ScanSpendProgress { current, end } => {
                    vec![10.into_dart(), current.into_dart(), end.into_dart()].into_dart()
                }
                SpNotification::HeaderProgressStarted { phase, start, end } => vec![
                    11.into_dart(),
                    header_phase_idx(phase).into_dart(),
                    start.into_dart(),
                    end.into_dart(),
                ]
                .into_dart(),
                SpNotification::HeaderProgress {
                    phase,
                    current,
                    end,
                } => vec![
                    12.into_dart(),
                    header_phase_idx(phase).into_dart(),
                    current.into_dart(),
                    end.into_dart(),
                ]
                .into_dart(),
                SpNotification::HeaderProgressCompleted { phase } => {
                    vec![13.into_dart(), header_phase_idx(phase).into_dart()].into_dart()
                }
                SpNotification::HeaderProgressFailed { phase } => {
                    vec![14.into_dart(), header_phase_idx(phase).into_dart()].into_dart()
                }
                SpNotification::PaymentHistoryUpdated => vec![15.into_dart()].into_dart(),
                SpNotification::ElectrumDisconnected => vec![16.into_dart()].into_dart(),
                SpNotification::Reorg { fork_height } => {
                    vec![17.into_dart(), fork_height.into_dart()].into_dart()
                }
                SpNotification::HeaderCheckpointMismatch => vec![18.into_dart()].into_dart(),
                SpNotification::ElectrumConnected => vec![19.into_dart()].into_dart(),
            }
        }
    }

    impl flutter_rust_bridge::for_generated::IntoDartExceptPrimitive for SpNotification {}

    impl IntoIntoDart<SpNotification> for SpNotification {
        fn into_into_dart(self) -> SpNotification {
            self
        }
    }
}
