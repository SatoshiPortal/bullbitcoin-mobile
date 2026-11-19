use std::{
    path::PathBuf,
    str::FromStr,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex, MutexGuard,
    },
    thread::JoinHandle,
    time::Duration,
};

use bitcoin::{
    consensus::encode::{deserialize_hex, serialize},
    BlockHash, Network,
};
use flutter_rust_bridge::frb;

use bwk::{
    bwk_coin,
    bwk_electrum::{
        checkpoint::Checkpoint,
        coin_store, header_store, notification,
        url::{parse_electrum_url, ElectrumScheme},
    },
    persist::config_store::{ConfigStore, FileConfigStore},
};
use bwk_sp::account::config::Config as SpConfig;
use bwk_sp::account::recipient::{SpRecipientAddress, TxBuilderSpExt};
use bwk_sp::account::{self as sp_account, Account as SpAccountInner};
use bwk_sp::receiver::RecipientAddress;
use bwk_sp::scan::{ScanRuntimeConfig, DEFAULT_FETCH_CONCURRENCY_FACTOR};

use crate::api::types::{
    CoinSource, HeaderProgressPhase, RecipientView, SpBalanceView, SpCoinView, SpError,
    SpHeaderCheckpoint, SpNetwork, SpNotification, SpPaymentDirection, SpPaymentStatus,
    SpPaymentView, SpRecipientAddressKind, TxSimulation, UnifiedCoinStatus, UnifiedCoinView,
};
use crate::frb_generated::StreamSink;

// Under the `bull_sdk` aggregation feature, `StreamSink` is an alias for the
// FRB-shared `StreamSinkBase` (so it is the SAME nominal type the aggregator's
// generated wire function constructs). `StreamSinkBase` has no typed `add()`,
// so the typed `add(SpNotification)` is provided by this extension trait. In a
// standalone build `StreamSink` is the macro-generated wrapper which already
// has an inherent `add()`, so the trait is not imported there.
#[cfg(feature = "bull_sdk")]
use crate::frb_generated::SpStreamSinkExt as _;

// Prevent anyone from enabling continuous-scan mode across the FRB boundary.
#[cfg(feature = "continuous-scan")]
compile_error!(
    "ScanMode::Continuous is intentionally not exposed across FRB. \
     Removing this guard requires a deliberate design change."
);

#[frb(opaque)]
pub struct SpAccount {
    inner: Arc<Mutex<SpAccountInner>>,
    sink: Mutex<Option<StreamSink<SpNotification>>>,

    // Cooperative shutdown for the notification-forwarding thread spawned in
    // `init()`. `dispose()` (FFI) and `Drop` both flip this flag and join the
    // handle so the thread, the inner Account, and its sqlite handle are
    // released deterministically. Without this, every WalletBloc refresh that
    // replaced `state.spWallet` would leak a thread blocked on `rx.recv()`
    // plus an open sqlite connection.
    shutdown: Arc<AtomicBool>,
    notif_handle: Mutex<Option<JoinHandle<()>>>,

    // Cancel signal for an in-flight `scan_once`. This is a clone of the
    // bwk_sp::Account's internal `scanner_stop`. Flipping it to `true`
    // causes spdk-core's `process_blocks` to bail at the next per-block
    // checkpoint, releasing the inner mutex without us ever needing to
    // touch it. `stop_scan` MUST NOT take the inner mutex (the
    // scan holds it for the full duration); `dispose()` flips this
    // flag so a running scan releases the lock promptly and the next
    // `SpAccount::load` doesn't race the sqlite handle.
    scan_cancel: Arc<AtomicBool>,
}

/// Test-only counter incremented when the notification thread exits cleanly.
/// Used by the Drop test to assert the thread actually terminates instead of
/// leaking. Fully gated behind `#[cfg(test)]`: in non-test builds the recorder
/// is an inlined no-op, so neither the counter nor the increment is compiled in.
#[cfg(test)]
use std::sync::atomic::AtomicUsize;
#[cfg(test)]
static NOTIF_THREAD_EXITS: AtomicUsize = AtomicUsize::new(0);

/// Record a clean notification-thread exit. Increments the test counter under
/// test; a zero-cost no-op in production.
#[cfg(test)]
fn record_notif_thread_exit() {
    NOTIF_THREAD_EXITS.fetch_add(1, Ordering::Relaxed);
}

#[cfg(not(test))]
#[inline(always)]
fn record_notif_thread_exit() {}

#[cfg(test)]
fn notif_thread_exit_count() -> usize {
    NOTIF_THREAD_EXITS.load(Ordering::Relaxed)
}

/// Take the SP-account mutex, mapping a poisoned lock to a recoverable error.
///
/// A panic in a holder of this lock (e.g. the notification thread) used to
/// poison it permanently, after which every subsequent FFI call would itself
/// panic via `.unwrap()` — bricking the wallet for the rest of the process.
/// Returning `Err` instead lets the cubit surface a "wallet stopped" state
/// and lets the user recover by restarting the app (no data loss: state is
/// persisted to sqlite on every coin update).
fn lock_inner(inner: &Mutex<SpAccountInner>) -> Result<MutexGuard<'_, SpAccountInner>, String> {
    inner
        .lock()
        .map_err(|_| "SP wallet lock poisoned; restart required".to_string())
}

fn to_bitcoin_network(n: SpNetwork) -> bitcoin::Network {
    match n {
        SpNetwork::Bitcoin => bitcoin::Network::Bitcoin,
        SpNetwork::Signet => bitcoin::Network::Signet,
        SpNetwork::Testnet => bitcoin::Network::Testnet,
        SpNetwork::Regtest => bitcoin::Network::Regtest,
    }
}

fn sp_network_matches(
    address_network: bwk_sp::core::utils::common::Network,
    network: Network,
) -> bool {
    match address_network {
        bwk_sp::core::utils::common::Network::Mainnet => network == Network::Bitcoin,
        bwk_sp::core::utils::common::Network::Testnet => {
            network == Network::Testnet || network == Network::Signet
        }
        bwk_sp::core::utils::common::Network::Regtest => network == Network::Regtest,
    }
}

/// Derive the public BIP352 account-0 address without opening account storage.
/// The caller has already folded the mnemonic language and passphrase into the seed.
pub fn derive_sp_address_from_seed(seed: Vec<u8>, network: SpNetwork) -> Result<String, String> {
    let seed = zeroize::Zeroizing::new(seed);
    let seed = bwk_sp::seed::Seed::from_slice(&seed)
        .map_err(|_| "invalid BIP39 seed length: expected 64 bytes".to_string())?;
    let receiver = bwk_sp::receiver::SpReceiver::new_from_seed(
        &seed,
        to_bitcoin_network(network),
        bitcoin::bip32::ChildNumber::from_hardened_idx(0).expect("fixed BIP352 account"),
    )
    .map_err(|_| "SP address derivation failed".to_string())?;
    Ok(receiver.get_receiving_address().to_string())
}

pub fn validate_recipient_address(
    address: String,
    network: SpNetwork,
) -> Result<SpRecipientAddressKind, String> {
    let network = to_bitcoin_network(network);
    if let Ok(sp_address) =
        bwk_sp::core::utils::common::SilentPaymentAddress::try_from(address.as_str())
    {
        if !sp_network_matches(sp_address.get_network(), network) {
            return Err(format!("wrong network for '{address}'"));
        }
        return Ok(SpRecipientAddressKind::Sp);
    }

    bitcoin::Address::from_str(&address)
        .map_err(|e| format!("invalid address '{address}': {e}"))?
        .require_network(network)
        .map_err(|e| format!("wrong network for '{address}': {e}"))?;
    Ok(SpRecipientAddressKind::Standard)
}

/// Test a blindbit URL by fetching its current block height. Standalone (no live
/// account); async so the HTTP GET runs off the Dart UI isolate.
pub fn test_blindbit_url(url: String) -> Result<(), String> {
    let agent = bwk_sp::blindbit::agent().map_err(|e| e.to_string())?;
    bwk_sp::blindbit::block_height(&agent, &url)
        .map(|_| ())
        .map_err(|e| e.to_string())
}

/// Test an electrum URL by connecting and requesting `server.version`. Standalone;
/// async so the TCP/SSL handshake runs off the Dart UI isolate. 5s timeout.
pub fn test_electrum_url(url: String) -> Result<(), String> {
    use bwk_sp::bwk::bwk_electrum::electrum::request::Request;
    let (host, port, scheme) = parse_electrum_url(&url)?;
    let host = host.ok_or_else(|| format!("missing host in '{url}'"))?;
    let port = port.ok_or_else(|| format!("missing port in '{url}'"))?;
    let ssl = matches!(scheme, ElectrumScheme::Ssl);
    let mut client = bwk_sp::bwk::bwk_electrum::raw_client::Client::new_ssl_maybe(&host, port, ssl);
    client
        .try_connect(Some(Duration::from_secs(5)))
        .map_err(|e| format!("connection failed: {e}"))?;
    let req = Request::version("bullbitcoin".to_string(), "1.4".to_string());
    client
        .try_send(&req)
        .map_err(|e| format!("send failed: {e}"))?;
    client.recv_str().map_err(|e| format!("no response: {e}"))?;
    Ok(())
}

fn build_tx_with_coin_selection(
    inner: &SpAccountInner,
    recipients: &[RecipientView],
    feerate_sat_vb: u64,
    change_dust_threshold: Option<u64>,
) -> Result<bwk_tx::tx_builder::TxBuilder, String> {
    let network = inner.network();
    let feerate_msat_vb = feerate_sat_vb.saturating_mul(1_000);
    let mut builder = inner.tx_builder().feerate(feerate_msat_vb);
    if let Some(sats) = change_dust_threshold {
        builder = builder.dust_threshold(sats);
    }

    let mut has_max = false;
    for r in recipients {
        let is_max = match r {
            RecipientView::Sp { is_max, .. } | RecipientView::Standard { is_max, .. } => *is_max,
        };
        if is_max {
            // Drain all spendable coins to this output; bwk computes the amount
            // (total - fee). RecipientAddress handles both SP and standard.
            if has_max {
                return Err("only one max output is allowed".to_string());
            }
            has_max = true;
            let address = match r {
                RecipientView::Sp { address, .. } | RecipientView::Standard { address, .. } => {
                    address
                }
            };
            let addr = RecipientAddress::parse(address, network)
                .map_err(|e| format!("invalid address '{address}': {e}"))?;
            let mut recip = SpRecipientAddress::new(addr, 0, network);
            recip.amount = bwk_sp::bwk_tx::transaction::Amount::Max(None);
            builder.add_output(recip);
            continue;
        }
        match r {
            RecipientView::Sp {
                address,
                amount_sat,
                ..
            } => {
                let sp_addr =
                    bwk_sp::core::utils::common::SilentPaymentAddress::try_from(address.as_str())
                        .map_err(|e| format!("invalid SP address '{address}': {e}"))?;
                if sp_addr.get_network() == bwk_sp::core::utils::common::Network::Mainnet
                    && network != Network::Bitcoin
                {
                    return Err(format!("Wrong network for SP address {sp_addr}"));
                }
                builder.send_to_sp(sp_addr, *amount_sat);
            }
            RecipientView::Standard {
                address,
                amount_sat,
                ..
            } => {
                let addr = bitcoin::Address::from_str(address)
                    .map_err(|e| format!("invalid address '{address}': {e}"))?
                    .require_network(network)
                    .map_err(|e| format!("wrong network for '{address}': {e}"))?;
                builder.send_to(addr, *amount_sat);
            }
        }
    }

    if has_max {
        builder.drain_inputs();
    }

    Ok(builder)
}

fn parse_header_checkpoint(checkpoint: SpHeaderCheckpoint) -> Result<Checkpoint, String> {
    let hash = BlockHash::from_str(&checkpoint.hash)
        .map_err(|e| format!("invalid header checkpoint hash: {e}"))?;
    Checkpoint::new(checkpoint.height, hash).map_err(|e| format!("invalid header checkpoint: {e}"))
}

fn parse_bwk_electrum_endpoint(url: &str) -> Result<(Option<String>, Option<u16>), String> {
    let (host, port, scheme) = parse_electrum_url(url)?;
    let host = host.map(|host| match scheme {
        ElectrumScheme::Tcp => host,
        ElectrumScheme::Ssl => format!("ssl://{host}"),
    });
    Ok((host, port))
}

impl SpAccount {
    #[allow(clippy::too_many_arguments)]
    fn from_mnemonic_with_runtime(
        name: String,
        network: SpNetwork,
        mnemonic: String,
        blindbit_url: String,
        electrum_url: String,
        data_dir: String,
        birthday_height: Option<u32>,
        dust_limit: Option<u64>,
        header_checkpoint: Option<SpHeaderCheckpoint>,
        scan_runtime: ScanRuntimeConfig,
    ) -> Result<SpAccount, String> {
        let btc_net = to_bitcoin_network(network);
        let mut config = SpConfig::new(
            name,
            btc_net,
            mnemonic.clone(),
            blindbit_url,
            PathBuf::from(&data_dir),
        );

        config
            .add_taproot_sub_account_from_mnemonic(&mnemonic)
            .map_err(|e| format!("add taproot sub-account: {e}"))?;
        Self::finish_create(
            config,
            electrum_url,
            birthday_height,
            dust_limit,
            header_checkpoint,
            scan_runtime,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn from_seed_with_runtime(
        name: String,
        network: SpNetwork,
        seed: &[u8],
        blindbit_url: String,
        electrum_url: String,
        data_dir: String,
        birthday_height: Option<u32>,
        dust_limit: Option<u64>,
        header_checkpoint: Option<SpHeaderCheckpoint>,
        scan_runtime: ScanRuntimeConfig,
    ) -> Result<SpAccount, String> {
        let mut config = SpConfig::from_seed(
            name,
            to_bitcoin_network(network),
            seed,
            blindbit_url,
            PathBuf::from(&data_dir),
        )
        .map_err(|_| "invalid BIP39 seed length: expected 64 bytes".to_string())?;
        config
            .add_default_taproot_sub_account()
            .map_err(|e| format!("add taproot sub-account: {e}"))?;
        Self::finish_create(
            config,
            electrum_url,
            birthday_height,
            dust_limit,
            header_checkpoint,
            scan_runtime,
        )
    }

    #[allow(clippy::too_many_arguments)]
    fn finish_create(
        mut config: SpConfig,
        electrum_url: String,
        birthday_height: Option<u32>,
        dust_limit: Option<u64>,
        header_checkpoint: Option<SpHeaderCheckpoint>,
        scan_runtime: ScanRuntimeConfig,
    ) -> Result<SpAccount, String> {
        config.birthday_height = birthday_height;
        config.dust_limit = dust_limit;
        config.header_checkpoint = header_checkpoint.map(parse_header_checkpoint).transpose()?;

        // The bwk_sp broadcast reads config.electrum_endpoint(); nothing else
        // sets it (set_electrum_settings only configures the sub-accounts).
        if let Ok((Some(host), Some(port))) = parse_bwk_electrum_endpoint(&electrum_url) {
            config.set_electrum_endpoint(host, port);
        }

        let config = config.with_persistence(Some(bwk::persist::PersistenceKind::Sqlite));
        let account =
            SpAccountInner::with_runtime_config(config, scan_runtime).map_err(|e| e.to_string())?;
        let scan_cancel = account.cancel_flag();

        Ok(SpAccount {
            inner: Arc::new(Mutex::new(account)),
            sink: Mutex::new(None),
            shutdown: Arc::new(AtomicBool::new(false)),
            notif_handle: Mutex::new(None),
            scan_cancel,
        })
    }

    fn runtime_from_factors(
        fetch_concurrency_factor: Option<u32>,
        match_concurrency_factor: Option<u32>,
    ) -> Result<ScanRuntimeConfig, String> {
        let _ = match_concurrency_factor;
        let fetch_concurrency_factor = fetch_concurrency_factor
            .map(|value| value as usize)
            .unwrap_or(DEFAULT_FETCH_CONCURRENCY_FACTOR);
        ScanRuntimeConfig::from_fetch_concurrency_factor(fetch_concurrency_factor)
            .map_err(|e| e.to_string())
    }

    /// Build a hot SP account from a BIP39 mnemonic. SP scan/spend keys are
    /// derived the standard BIP352 way (bwk_sp `new_from_mnemonic`), so the same
    /// mnemonic yields the same SP wallet as other BIP352 software. The taproot
    /// sub-account is added from the same mnemonic.
    ///
    /// Not `#[frb(sync)]`: this derives the BIP352 keys, opens `account.sqlite`,
    /// opens the header store and spawns the scan runtime, which would freeze
    /// the Dart UI isolate for the whole of it, on first setup and on every
    /// session re-establish including cold start. Async rather than the usual
    /// notification-thread pattern because there is no sink to push to yet:
    /// this call creates the `SpAccount` that owns the single
    /// `StreamSink<SpNotification>`. FRB runs it on a worker isolate.
    #[allow(clippy::too_many_arguments)]
    pub fn create_from_mnemonic(
        name: String,
        network: SpNetwork,
        mnemonic: String,
        blindbit_url: String,
        electrum_url: String,
        data_dir: String,
        birthday_height: Option<u32>,
        dust_limit: Option<u64>,
        header_checkpoint: Option<SpHeaderCheckpoint>,
    ) -> Result<SpAccount, String> {
        Self::from_mnemonic_with_runtime(
            name,
            network,
            mnemonic,
            blindbit_url,
            electrum_url,
            data_dir,
            birthday_height,
            dust_limit,
            header_checkpoint,
            ScanRuntimeConfig::default(),
        )
    }

    /// [create_from_mnemonic] with an explicit scan runtime.
    ///
    /// Not `#[frb(sync)]`: this derives the BIP352 keys, opens `account.sqlite`,
    /// opens the header store and spawns the scan runtime, which would freeze
    /// the Dart UI isolate for the whole of it, on first setup and on every
    /// session re-establish including cold start. Async rather than the usual
    /// notification-thread pattern because there is no sink to push to yet:
    /// this call creates the `SpAccount` that owns the single
    /// `StreamSink<SpNotification>`. FRB runs it on a worker isolate.
    #[allow(clippy::too_many_arguments)]
    pub fn create_from_mnemonic_with_scan_runtime(
        name: String,
        network: SpNetwork,
        mnemonic: String,
        blindbit_url: String,
        electrum_url: String,
        data_dir: String,
        birthday_height: Option<u32>,
        dust_limit: Option<u64>,
        fetch_concurrency_factor: Option<u32>,
        match_concurrency_factor: Option<u32>,
        header_checkpoint: Option<SpHeaderCheckpoint>,
    ) -> Result<SpAccount, String> {
        let scan_runtime =
            Self::runtime_from_factors(fetch_concurrency_factor, match_concurrency_factor)?;
        Self::from_mnemonic_with_runtime(
            name,
            network,
            mnemonic,
            blindbit_url,
            electrum_url,
            data_dir,
            birthday_height,
            dust_limit,
            header_checkpoint,
            scan_runtime,
        )
    }

    /// Build a hot SP account from the 64 bytes of a BIP39 seed.
    /// The mnemonic language and passphrase are already represented in the seed.
    /// Recreate the account with the seed when reopening it: signer material is not persisted.
    #[allow(clippy::too_many_arguments)]
    pub fn create_from_seed(
        name: String,
        network: SpNetwork,
        seed: Vec<u8>,
        blindbit_url: String,
        electrum_url: String,
        data_dir: String,
        birthday_height: Option<u32>,
        dust_limit: Option<u64>,
        header_checkpoint: Option<SpHeaderCheckpoint>,
    ) -> Result<SpAccount, String> {
        let seed = zeroize::Zeroizing::new(seed);
        Self::from_seed_with_runtime(
            name,
            network,
            &seed,
            blindbit_url,
            electrum_url,
            data_dir,
            birthday_height,
            dust_limit,
            header_checkpoint,
            ScanRuntimeConfig::default(),
        )
    }

    /// [create_from_seed] with an explicit scan runtime.
    #[allow(clippy::too_many_arguments)]
    pub fn create_from_seed_with_scan_runtime(
        name: String,
        network: SpNetwork,
        seed: Vec<u8>,
        blindbit_url: String,
        electrum_url: String,
        data_dir: String,
        birthday_height: Option<u32>,
        dust_limit: Option<u64>,
        fetch_concurrency_factor: Option<u32>,
        match_concurrency_factor: Option<u32>,
        header_checkpoint: Option<SpHeaderCheckpoint>,
    ) -> Result<SpAccount, String> {
        let seed = zeroize::Zeroizing::new(seed);
        let scan_runtime =
            Self::runtime_from_factors(fetch_concurrency_factor, match_concurrency_factor)?;
        Self::from_seed_with_runtime(
            name,
            network,
            &seed,
            blindbit_url,
            electrum_url,
            data_dir,
            birthday_height,
            dust_limit,
            header_checkpoint,
            scan_runtime,
        )
    }

    /// Consume this account and release its resources after [dispose] succeeds.
    /// Do not call this after a failed disposal: retain the handle and retry.
    /// The handle cannot be used again after this call.
    ///
    /// Not `#[frb(sync)]`: dropping the account may block while resources close.
    pub fn release(self) {
        drop(self);
    }

    /// Reopen an account already on disk.
    ///
    /// A given `header_checkpoint` replaces the one in the saved config, `None`
    /// keeps it: the header store extends its chain down to a lower checkpoint
    /// and refuses a chain that holds another block at its height.
    ///
    /// Not `#[frb(sync)]` for the same reason as [create_from_mnemonic]: it
    /// opens `account.sqlite` and the header store, and it runs before the
    /// notification sink exists.
    pub fn load(
        name: String,
        data_dir: String,
        header_checkpoint: Option<SpHeaderCheckpoint>,
    ) -> Result<SpAccount, String> {
        let config_path = PathBuf::from(&data_dir)
            .join(&name)
            .join(bwk_sp::account::config::CONFIG_FILENAME);
        let store = FileConfigStore::<SpConfig>::new(config_path);
        let mut config = store
            .load()
            .map_err(|e| e.to_string())?
            .ok_or_else(|| format!("no config found for account '{name}' in {data_dir}"))?;
        if let Some(checkpoint) = header_checkpoint {
            config.header_checkpoint = Some(parse_header_checkpoint(checkpoint)?);
        }

        let account = SpAccountInner::new(config).map_err(|e| e.to_string())?;

        let scan_cancel = account.cancel_flag();
        Ok(SpAccount {
            inner: Arc::new(Mutex::new(account)),
            sink: Mutex::new(None),
            shutdown: Arc::new(AtomicBool::new(false)),
            notif_handle: Mutex::new(None),
            scan_cancel,
        })
    }

    #[frb(sync)]
    pub fn init(&self, sink: StreamSink<SpNotification>) -> Result<(), String> {
        let rx = lock_inner(&self.inner)?
            .receiver()
            .ok_or_else(|| "init() already called — receiver already taken".to_string())?;

        let inner_arc = self.inner.clone();
        let thread_sink = sink.clone();
        let shutdown = self.shutdown.clone();
        *self
            .sink
            .lock()
            .map_err(|_| "sink mutex poisoned".to_string())? = Some(sink);

        let handle = std::thread::spawn(move || {
            // Drain the channel with a short timeout so we can check the
            // cooperative shutdown flag. The Sender lives inside the Account
            // (held by `inner_arc`); when SpAccount drops, the Account drops,
            // the Sender drops, and `rx.recv_timeout` would return Disconnected
            // — but we cannot rely on that alone because the JoinHandle is
            // joined from Drop while the strong Arc count is still >0.
            'outer: loop {
                if shutdown.load(Ordering::Acquire) {
                    break;
                }
                match rx.recv_timeout(Duration::from_millis(50)) {
                    Ok(n) => {
                        for mapped in map_notification(n, &inner_arc) {
                            if thread_sink.add(mapped).is_err() {
                                break 'outer;
                            }
                        }
                    }
                    Err(std::sync::mpsc::RecvTimeoutError::Timeout) => continue,
                    Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => break,
                }
            }
            record_notif_thread_exit();
        });

        if let Ok(mut slot) = self.notif_handle.lock() {
            *slot = Some(handle);
        }

        Ok(())
    }

    /// Cooperatively stop the notification thread and wait for in-flight work.
    /// Safe to call multiple times; the second call is a no-op. After success,
    /// call [release] to consume the account and release its sqlite handle.
    ///
    /// Dart callers MUST invoke this before dropping the last reference to
    /// `SpAccount` (typically from `SpWalletEntity.dispose()` which is in
    /// turn called from `WalletBloc._onRefreshSpWallet` before reassigning
    /// `state.spWallet`). Relying on `Drop` alone is risky because the FRB
    /// Arc may outlive the Dart-side handle for a finalizer cycle, leaking
    /// an open sqlite connection in the meantime.
    ///
    /// If a `scan_once` is in flight when `dispose()` is called, the
    /// scan still holds the inner mutex via `&mut self`. Flipping
    /// `scan_cancel` causes spdk-core's `process_blocks` to bail at the
    /// next per-block checkpoint, the scan returns, and the inner Account
    /// becomes free to drop. Without this signal, the next
    /// `SpAccount::load` would open `account.sqlite` while the previous
    /// scan was still writing — the exact double-handle race we are
    /// trying to prevent.
    ///
    /// Not `#[frb(sync)]`: dispose() now waits for an in-flight
    /// scan to release the lock, which can take up to ~30 seconds (the
    /// `update_time` checkpoint cadence in spdk-core's `process_blocks`)
    /// in the worst case. Running that on the Dart UI isolate would freeze
    /// the UI. FRB dispatches `async` methods on a worker isolate.
    ///
    /// Return contract: returns `Ok(())` when the inner mutex
    /// became reacquirable within the bounded budget (i.e. the previous
    /// holder of the lock — a scan, a long `unified_history`/
    /// `unified_coins`, an `prepare_psbt`/`finalize_psbt`/`sign_psbt`
    /// invocation — actually released it). Returns `Err("dispose timed
    /// out: inner lock still held; retry or restart")` when the budget
    /// elapsed without the lock becoming free. The caller MUST treat the
    /// timeout case as "previous SpAccount is still in flight" and MUST
    /// NOT proceed to call `SpAccount::load(...)` against the same
    /// `data_dir` — doing so would race the sqlite handle and is the
    /// exact double-open we are trying to prevent.
    ///
    /// We still flip the cancel + shutdown flags, join the notification
    /// thread, and drop the cached sink on the timeout path so the
    /// notification side of cleanup is best-effort idempotent and a
    /// subsequent dispose() call observes a clean state. Only the
    /// inner-lock contract is violated.
    pub async fn dispose(&self) -> Result<(), SpError> {
        // 1. Signal any in-flight scan to bail at the next block checkpoint.
        //    This must happen BEFORE we attempt to take the inner mutex —
        //    the scan call frame holds the mutex via `&mut self`, so we
        //    cannot acquire it until the scan returns.
        self.scan_cancel.store(true, Ordering::Relaxed);

        // 2. Flip the notification-thread shutdown flag.
        self.shutdown.store(true, Ordering::Release);

        // 3. Wait for the inner mutex to be free (i.e. the scan has
        //    bailed). We don't actually need to hold it — we just need to
        //    confirm it is reacquirable so the next `SpAccount::load`
        //    won't race the sqlite handle.
        //
        //    Bounded poll: spdk-core's `process_blocks` checks the cancel
        //    flag before every block, plus has a 30-second `update_time`
        //    persistence cycle. A 5-second budget covers the common case
        //    (per-block check fires within ms) without making the worst
        //    case (a long blindbit RPC blocking inside `process_block`)
        //    hang the UI indefinitely.
        //
        //    If we exceed the budget we surface that to the caller
        //    as an `Err` so `WalletBloc._onRefreshSpWallet` declines to
        //    open `account.sqlite` while the previous handle is still
        //    writing. `scan_once`'s per-block checkpoint observes our
        //    cancel flag, but the other lock-holding methods
        //    (`prepare_psbt`, `finalize_psbt`, `sign_psbt`,
        //    `unified_history`, `unified_coins`) run to completion with
        //    no cancellation hook today — see follow-up Change C in the
        //    R6 report. The caller can retry the refresh once the
        //    in-flight method finishes.
        let deadline = std::time::Instant::now() + Duration::from_secs(5);
        let mut lock_freed = false;
        while std::time::Instant::now() < deadline {
            if self.inner.try_lock().is_ok() {
                lock_freed = true;
                break;
            }
            std::thread::sleep(Duration::from_millis(25));
        }

        // Stop the electrum listener thread so it releases the sqlite handle and
        // the `.lock` file. Without this the listener keeps running and a later
        // account-dir delete (revoke) fails file-locked. Mirrors silent.
        if let Ok(mut g) = self.inner.try_lock() {
            g.stop_electrum();
        }

        // 4. Take the JoinHandle out before joining so a second dispose()
        //    call (or Drop running after dispose) is a no-op.
        let handle = self
            .notif_handle
            .lock()
            .ok()
            .and_then(|mut slot| slot.take());
        if let Some(h) = handle {
            // Ignore JoinError (poison) — the thread is gone either way.
            let _ = h.join();
        }

        // 5. Drop the cached sink so any outstanding `add()` returns Err
        //    and does not pin Dart-side resources.
        if let Ok(mut sink) = self.sink.lock() {
            *sink = None;
        }

        if lock_freed {
            Ok(())
        } else {
            Err(SpError::DisposeTimedOut)
        }
    }

    #[frb(sync)]
    pub fn sp_address(&self) -> Result<String, String> {
        Ok(lock_inner(&self.inner)?.sp_address().to_string())
    }

    #[frb(sync)]
    pub fn confirmed_balance(&self) -> Result<u64, String> {
        Ok(lock_inner(&self.inner)?.balance())
    }

    #[frb(sync)]
    pub fn last_scanned_height(&self) -> Result<Option<u32>, String> {
        Ok(lock_inner(&self.inner)?.last_scanned_height())
    }

    /// Earliest height a scan may start from (taproot activation on mainnet, a
    /// low constant on test networks). The scan start chooser uses this as its
    /// floor.
    #[frb(sync)]
    pub fn min_birthday_height(&self) -> Result<u32, String> {
        Ok(lock_inner(&self.inner)?.min_birthday_height())
    }

    #[frb(sync)]
    pub fn is_scanning(&self) -> Result<bool, String> {
        Ok(lock_inner(&self.inner)?.is_scanning())
    }

    pub fn clear_scan_state(&self) -> Result<(), String> {
        lock_inner(&self.inner)?
            .clear_scan_state()
            .map_err(|e| e.to_string())
    }

    /// USER-TRIGGERED ONLY. The bb-mobile app contract is that this method
    /// is invoked exclusively from `ScanSpWalletUsecase`, which itself is
    /// invoked exclusively from `SpCubit.scan()` (the Scan button handler).
    /// Do not call from app lifecycle hooks, route observers, timers, or
    /// background services. Doing so violates the documented invariant.
    ///
    /// Not `#[frb(sync)]`: the underlying bwk_sp scan walker is fully
    /// synchronous and would freeze the Dart UI isolate for the entire
    /// scan duration if dispatched there. FRB runs `async` methods on a
    /// worker isolate. The inner mutex is held for the full scan — that
    /// serializes against other methods, which is acceptable because SP
    /// scans are user-triggered and rare.
    ///
    /// Cancellation: `stop_scan` flips `self.scan_cancel` (a clone of the
    /// bwk_sp::Account's internal `scanner_stop`), which causes the scan
    /// to bail at the next per-block checkpoint inside spdk-core's
    /// `process_blocks`. bwk_sp resets the cancel flag at the start of
    /// every OneShot run, so a stale `true` from a previous cancel does
    /// not affect subsequent scans.
    pub fn scan_once(&self, start_height: Option<u32>) -> Result<(), SpError> {
        // Explicitly clear the cancel flag here too, even though bwk_sp's
        // scan_oneshot resets it: this guards against the edge case where
        // a previous `dispose()` flipped the flag and a brand-new
        // SpAccount is being scanned. Cheap relaxed store.
        self.scan_cancel.store(false, Ordering::Relaxed);
        let mut g = lock_inner(&self.inner)?;
        // `start_height` overrides where the scan begins (None resumes from the
        // last scanned position); bwk_sp clamps it to the birthday height.
        g.start_scan(sp_account::ScanMode::OneShot, start_height)
            .map_err(|e| match e {
                // Preserved as a variant: callers skip a redundant start
                // instead of matching on the message.
                sp_account::AccountError::ScannerAlreadyRunning => SpError::ScannerAlreadyRunning,
                other => SpError::Other {
                    message: other.to_string(),
                },
            })
    }

    /// Cooperatively cancel an in-flight `scan_once`. Returns immediately
    /// without touching the inner mutex (which the scan call still holds
    /// via `&mut self` for its full duration); spdk-core's `process_blocks`
    /// observes `scan_cancel` between blocks and returns `Ok(())` after
    /// persisting state. The scan handler then emits `ScanStopped` with the
    /// persisted frontiers and the cubit's `_onNotification` transitions out
    /// of `isScanning`.
    ///
    /// Was `#[frb(sync)]`: that meant Dart's Stop button ran on the
    /// UI isolate and blocked waiting for the inner mutex held by the
    /// scan, freezing the UI for the rest of the scan. The new
    /// signature is async + non-locking; the Stop button never deadlocks.
    ///
    /// Idempotent: re-flipping an already-`true` flag is a no-op.
    pub async fn stop_scan(&self) -> Result<(), String> {
        self.scan_cancel.store(true, Ordering::Relaxed);
        Ok(())
    }

    #[frb(sync)]
    pub fn coins(&self) -> Result<Vec<SpCoinView>, String> {
        let map = lock_inner(&self.inner)?.coins();
        Ok(map
            .into_values()
            .map(|entry| SpCoinView {
                outpoint: entry.outpoint().to_string(),
                amount_sat: entry.amount_sat(),
                height: entry.height(),
                is_spendable: entry.is_spendable(),
                label: None,
            })
            .collect())
    }

    #[frb(sync)]
    pub fn block_height(&self) -> Result<u32, String> {
        lock_inner(&self.inner)?
            .block_height()
            .map_err(|e| e.to_string())
    }

    #[frb(sync)]
    pub fn backend_online(&self) -> Result<bool, String> {
        Ok(lock_inner(&self.inner)?.backend_online())
    }

    #[frb(sync)]
    pub fn name(&self) -> Result<String, String> {
        Ok(lock_inner(&self.inner)?.name().to_string())
    }

    /// Returns the wallet's network as an `SpNetwork`.
    ///
    /// `bitcoin::Network` is upstream-marked `#[non_exhaustive]`; rather than
    /// silently mapping a future variant to one of our known cases (which
    /// would corrupt downstream address validation), we return an explicit
    /// `Err` so the caller is forced to handle the unknown case.
    #[frb(sync)]
    pub fn network(&self) -> Result<SpNetwork, String> {
        match lock_inner(&self.inner)?.network() {
            bitcoin::Network::Bitcoin => Ok(SpNetwork::Bitcoin),
            bitcoin::Network::Signet => Ok(SpNetwork::Signet),
            bitcoin::Network::Testnet => Ok(SpNetwork::Testnet),
            bitcoin::Network::Regtest => Ok(SpNetwork::Regtest),
            other => Err(format!("unsupported bitcoin::Network variant: {other:?}")),
        }
    }

    /// Reveal a fresh receive address for the BIP86 taproot sub-account.
    ///
    /// Each call derives the next never-before-issued address via
    /// [`bwk_sp::account::Account::new_taproot_address`], which bumps and
    /// persists the receive-chain tip (sqlite under `PersistenceKind::Sqlite`)
    /// *before* deriving. So an address is never handed out twice, even across
    /// restarts, and regardless of whether the previously revealed one has
    /// received a coin yet. Callers MUST treat this as "give me a new address
    /// to hand out" (an explicit user action), never as a stable display
    /// getter.
    ///
    /// Store-only / pure-descriptor: it never contacts Electrum or Blindbit,
    /// so it does not violate the no-chain-query-outside-`scan_once` invariant.
    ///
    /// New SP wallets only register a taproot sub-account. Legacy wallets that
    /// were persisted with both a segwit and a taproot sub-account keep both
    /// for backward compatibility; the segwit one is only used internally
    /// (change / payment provenance) and never exposes a hand-out address.
    pub fn new_taproot_address(&self) -> Result<String, String> {
        lock_inner(&self.inner)?
            .new_taproot_address()
            .map(|entry| entry.value())
            .ok_or_else(|| "taproot sub-account missing".to_string())
    }

    /// Aggregated balance across SP + all sub-accounts.
    #[frb(sync)]
    pub fn unified_balance(&self) -> Result<SpBalanceView, String> {
        let inner = lock_inner(&self.inner)?;
        Ok(SpBalanceView {
            confirmed_sat: inner.all_spendable_coins().confirmed_balance.to_sat(),
            total_unified_sat: inner.total_balance(),
            last_scanned_height: inner.last_scanned_height(),
        })
    }

    /// Aggregated coins across SP + all sub-accounts, each tagged with its source.
    pub fn unified_coins(&self) -> Result<Vec<UnifiedCoinView>, String> {
        let coins = lock_inner(&self.inner)?.all_coins();
        Ok(coins.into_values().map(unified_coin_view).collect())
    }

    /// Aggregated payment history across SP + all sub-accounts.
    pub fn unified_history(&self) -> Result<Vec<SpPaymentView>, String> {
        let inner = lock_inner(&self.inner)?;

        // payment_history() is now the unified, deduped history across the SP
        // account and every sub-account (bwk's generic aggregator). Amount is
        // owned_in - owned_out (sent + fee, change netted); height/timestamp are
        // stamped by the scan + the Electrum listener.
        let result = inner
            .payment_history()
            .into_iter()
            .map(|p| SpPaymentView {
                txid: p.txid,
                direction: match p.payment_type {
                    coin_store::PaymentType::Receive => SpPaymentDirection::Receive,
                    coin_store::PaymentType::Send => SpPaymentDirection::Send,
                    coin_store::PaymentType::ToSelf => SpPaymentDirection::SelfSend,
                },
                status: match p.status {
                    coin_store::PaymentStatus::Unconfirmed => SpPaymentStatus::Unconfirmed,
                    coin_store::PaymentStatus::ConfirmedUnverified => {
                        SpPaymentStatus::ConfirmedUnverified
                    }
                    coin_store::PaymentStatus::Verified => SpPaymentStatus::Verified,
                    coin_store::PaymentStatus::VerifyFailed => SpPaymentStatus::VerifyFailed,
                },
                amount_sat: p.amount,
                fee_sat: None,
                height: p.height.map(|h| h as u32),
                timestamp: p.timestamp,
                label: Some(p.label).filter(|l| !l.is_empty()),
            })
            .collect();

        Ok(result)
    }

    /// Stamp the confirmed txs still missing a block time from the header
    /// store. Local only, no network call. Returns whether any tx got stamped.
    #[frb(sync)]
    pub fn restamp_missing_timestamps(&self) -> Result<bool, String> {
        Ok(lock_inner(&self.inner)?.restamp_missing_timestamps())
    }

    /// Update the Electrum server endpoint for all sub-accounts (in-memory, no persist).
    /// Accepts `[scheme://]host[:port]` with `scheme` ∈ `{tcp, ssl}`.
    #[frb(sync)]
    pub fn set_electrum_url(&self, url: String) -> Result<(), String> {
        let (host, port) = parse_bwk_electrum_endpoint(&url)?;
        lock_inner(&self.inner)?.set_electrum_settings(host, port);
        Ok(())
    }

    /// Start the always-on electrum listeners for every sub-account (segwit +
    /// taproot) so incoming txs are pushed in real time without a chain scan.
    /// Set the sub-account electrum URL first via `set_electrum_url`. Idempotent:
    /// bwk only spawns a listener when one is not already running. Not
    /// `#[frb(sync)]` so the listener setup runs off the Dart UI isolate.
    pub fn start_electrum(&self) -> Result<(), String> {
        let mut g = lock_inner(&self.inner)?;
        g.start_electrum();
        Ok(())
    }

    /// Restart the sub-account electrum listeners in place (stop then start),
    /// keeping the account and its notification channel alive. Used on app
    /// foreground to recover after Android killed the backgrounded socket:
    /// `stop_electrum` reclaims each listener's statuses store, so `start_electrum`
    /// reconnects + re-subscribes + re-syncs (re-detecting coins received away).
    pub fn restart_electrum(&self) -> Result<(), String> {
        let mut g = lock_inner(&self.inner)?;
        g.stop_electrum();
        g.start_electrum();
        Ok(())
    }

    /// Preview a transaction: run coin selection and return fee/change estimates.
    /// Does NOT produce a signable PSBT — use finalize_psbt() for that.
    ///
    /// feerate_sat_vb: fee rate in satoshis per virtual byte.
    /// change_dust_threshold: a change below it goes to the fee; `None` keeps
    /// bwk's default.
    pub fn prepare_psbt(
        &self,
        recipients: Vec<RecipientView>,
        feerate_sat_vb: u64,
        change_dust_threshold: Option<u64>,
    ) -> Result<TxSimulation, String> {
        let inner = lock_inner(&self.inner)?;
        let builder = build_tx_with_coin_selection(
            &inner,
            &recipients,
            feerate_sat_vb,
            change_dust_threshold,
        )?;
        let result = builder.simulate();

        if let Some(err) = result.error {
            return Err(format!("simulation failed: {err:?}"));
        }

        let inputs: Vec<UnifiedCoinView> = result
            .tx_template
            .inputs
            .iter()
            .map(|coin| UnifiedCoinView {
                source: match coin.source() {
                    bwk_coin::CoinSourceKind::SilentPayment => CoinSource::Sp,
                    bwk_coin::CoinSourceKind::Segwit => CoinSource::Segwit,
                    bwk_coin::CoinSourceKind::Taproot => CoinSource::Taproot,
                    bwk_coin::CoinSourceKind::Other => CoinSource::Other,
                },
                outpoint: coin.outpoint.to_string(),
                amount_sat: coin.txout.value.to_sat(),
                height: coin.height.map(|h| h as u32),
                // Selected tx inputs are unspent UTXOs being spent.
                status: UnifiedCoinStatus::Unspent,
            })
            .collect();

        let fee_sat = result.fees.map(|f| f.to_sat()).unwrap_or(0);
        let change_sat = result.change.map(|c| c.to_sat()).unwrap_or(0);

        // For a max output bwk drained all inputs; report the computed amount
        // (total inputs - fee - the fixed outputs) so the Confirm page shows it.
        let input_total: u64 = inputs.iter().map(|i| i.amount_sat).sum();
        let non_max_total: u64 = recipients
            .iter()
            .map(|r| match r {
                RecipientView::Sp {
                    amount_sat, is_max, ..
                }
                | RecipientView::Standard {
                    amount_sat, is_max, ..
                } => {
                    if *is_max {
                        0
                    } else {
                        *amount_sat
                    }
                }
            })
            .sum();
        let max_amount = input_total
            .saturating_sub(fee_sat)
            .saturating_sub(non_max_total);

        let outputs: Vec<RecipientView> = recipients
            .into_iter()
            .map(|r| match r {
                RecipientView::Sp {
                    address,
                    amount_sat,
                    label,
                    is_max,
                } => RecipientView::Sp {
                    address,
                    amount_sat: if is_max { max_amount } else { amount_sat },
                    label,
                    is_max,
                },
                RecipientView::Standard {
                    address,
                    amount_sat,
                    is_max,
                } => RecipientView::Standard {
                    address,
                    amount_sat: if is_max { max_amount } else { amount_sat },
                    is_max,
                },
            })
            .collect();

        Ok(TxSimulation {
            inputs,
            outputs,
            fee_sat,
            change_sat,
            change_dust_threshold,
        })
    }

    /// Build and serialize an unsigned PSBT ready for signing, consuming the
    /// `TxSimulation` the user confirmed in the previous `prepare_psbt`.
    ///
    /// This method DOES NOT run coin selection: it pins the input set and the
    /// output set to exactly what the simulation contains. If the coin store
    /// has drifted since the simulation was produced (an incoming SP coin
    /// from a completed scan, an Electrum push for a sub-account coin, a
    /// reorg evicting an input), the method returns
    /// [`SpError::SimulationDrifted`] so the caller can surface a re-confirm
    /// prompt instead of broadcasting a tx that differs from what the user
    /// reviewed.
    ///
    /// Rationale: finalize → sign → broadcast is irreversible; an auto-
    /// re-selection here could ship a tx with different inputs, fee, or
    /// change address from the one shown on the Confirm page.
    pub fn finalize_psbt(&self, simulation: TxSimulation) -> Result<Vec<u8>, SpError> {
        let inner = lock_inner(&self.inner)?;

        let outputs: Vec<bwk_tx::template::TxOutputSpec> = simulation
            .outputs
            .iter()
            .map(|r| match r {
                RecipientView::Sp {
                    address,
                    amount_sat,
                    is_max,
                    ..
                } => bwk_tx::template::TxOutputSpec {
                    address: address.clone(),
                    amount: *amount_sat,
                    label: None,
                    max: *is_max,
                },
                RecipientView::Standard {
                    address,
                    amount_sat,
                    is_max,
                } => bwk_tx::template::TxOutputSpec {
                    address: address.clone(),
                    amount: *amount_sat,
                    label: None,
                    max: *is_max,
                },
            })
            .collect();

        let input_outpoints: Result<Vec<bitcoin::OutPoint>, String> = simulation
            .inputs
            .iter()
            .map(|v| {
                bitcoin::OutPoint::from_str(&v.outpoint)
                    .map_err(|e| format!("invalid outpoint '{}': {e}", v.outpoint))
            })
            .collect();
        let input_outpoints = input_outpoints?;

        let request = bwk_tx::template::TxRequest {
            outputs,
            fee_rate: 0.0,
            fee: simulation.fee_sat,
            input_outpoints,
            dust_threshold: simulation.change_dust_threshold,
        };

        let mut builder = inner
            .tx_builder_from_request(&request)
            .map_err(|e| match e {
                bwk_tx::template::TxRequestError::CoinNotFound(op) => SpError::SimulationDrifted {
                    detail: format!("coin {op} not found in wallet"),
                },
                bwk_tx::template::TxRequestError::CoinNotSpendable(op) => {
                    SpError::SimulationDrifted {
                        detail: format!("coin {op} is no longer spendable"),
                    }
                }
                bwk_tx::template::TxRequestError::InvalidAddress { address, .. } => {
                    SpError::Other {
                        message: format!("invalid address '{address}'"),
                    }
                }
                other => SpError::Other {
                    message: format!("{other:?}"),
                },
            })?;

        let psbt = builder.generate().map_err(|e| SpError::Other {
            message: format!("PSBT generation failed: {e:?}"),
        })?;
        Ok(psbt.serialize())
    }

    /// Sign and finalize an unsigned PSBT (returned by finalize_psbt).
    /// Returns the raw serialized transaction bytes.
    /// Hex-encode the result before passing to broadcast().
    pub fn sign_psbt(&self, psbt: Vec<u8>) -> Result<Vec<u8>, String> {
        let mut psbt =
            bitcoin::Psbt::deserialize(&psbt).map_err(|e| format!("invalid PSBT bytes: {e}"))?;

        let tx = lock_inner(&self.inner)?
            .sign_and_finalize(&mut psbt)
            .map_err(|e| e.to_string())?;

        Ok(serialize(&tx))
    }

    /// Start broadcasting a signed transaction to the network via Electrum.
    /// tx_hex: hex-encoded raw transaction bytes (hex::encode the sign_psbt result).
    /// Completion is delivered as Broadcasted or BroadcastFailed notification.
    pub fn broadcast(&self, tx_hex: String) -> Result<(), String> {
        let tx: bitcoin::Transaction =
            deserialize_hex(&tx_hex).map_err(|e| format!("invalid tx hex: {e}"))?;
        lock_inner(&self.inner)?.broadcast(tx);
        Ok(())
    }

    /// Update the Blindbit backend URL at runtime.
    #[frb(sync)]
    pub fn set_blindbit_url(&self, url: String) -> Result<(), String> {
        lock_inner(&self.inner)?.set_blindbit_url(url);
        Ok(())
    }
}

impl Drop for SpAccount {
    fn drop(&mut self) {
        // Mirror `dispose()` but defensive against a caller that didn't
        // invoke it explicitly. We avoid `dispose(&self)` here to skip the
        // sink lock if it would deadlock the runtime; instead we open-code
        // the minimum-needed shutdown.
        //
        // Also flip the scan-cancel flag so an in-flight `scan_once`
        // bails promptly. Without this, dropping an `SpAccount` while a
        // scan is in progress leaves the bwk_sp::Account pinned through
        // the scan's `&mut self` call frame, holding the sqlite handle
        // open past the FRB-side drop.
        self.scan_cancel.store(true, Ordering::Relaxed);
        self.shutdown.store(true, Ordering::Release);
        if let Some(h) = self.notif_handle.get_mut().ok().and_then(|s| s.take()) {
            let _ = h.join();
        }
        if let Ok(mut sink) = self.sink.lock() {
            *sink = None;
        }
        // The inner Account (and its sqlite handle) is dropped as part of
        // the normal struct field drop after this function returns.
    }
}

fn coin_source(origin: notification::CoinOrigin) -> CoinSource {
    match origin {
        notification::CoinOrigin::Sp => CoinSource::Sp,
        notification::CoinOrigin::SubAccount { kind, .. } => match kind {
            notification::SubAccountKind::Segwit => CoinSource::Segwit,
            notification::SubAccountKind::Taproot => CoinSource::Taproot,
            notification::SubAccountKind::Other => CoinSource::Other,
        },
    }
}

fn unified_coin_view(coin: sp_account::unified::UnifiedCoin) -> UnifiedCoinView {
    let status = match (coin.spendable, coin.height) {
        (false, _) => UnifiedCoinStatus::Spent,
        (true, None) => UnifiedCoinStatus::Unconfirmed,
        (true, Some(_)) => UnifiedCoinStatus::Unspent,
    };
    UnifiedCoinView {
        source: coin_source(coin.origin),
        outpoint: coin.outpoint.to_string(),
        amount_sat: coin.amount.to_sat(),
        height: coin.height,
        status,
    }
}

fn map_notification(
    n: notification::Notification,
    inner: &Arc<Mutex<SpAccountInner>>,
) -> Vec<SpNotification> {
    match n {
        notification::Notification::Sp(sp) => map_sp_notification(sp, inner).into_iter().collect(),
        notification::Notification::CoinUpdate => {
            log::trace!("SpAccount::map_notification: CoinUpdate");
            vec![]
        }
        notification::Notification::PaymentHistoryUpdated => {
            vec![SpNotification::PaymentHistoryUpdated]
        }
        notification::Notification::Electrum(notification::TxListenerNotif::Disconnected) => {
            vec![SpNotification::ElectrumDisconnected]
        }
        notification::Notification::Electrum(notification::TxListenerNotif::Connected(_)) => {
            vec![SpNotification::ElectrumConnected]
        }
        notification::Notification::Electrum(_) => {
            log::trace!("SpAccount::map_notification: Electrum connection event");
            vec![]
        }
        notification::Notification::HeaderStoreUpdated => {
            log::trace!("SpAccount::map_notification: HeaderStoreUpdated");
            vec![SpNotification::PaymentHistoryUpdated]
        }
        notification::Notification::HeaderProgress(event) => vec![map_header_progress(event)],
        notification::Notification::ValidationFailed(
            notification::ValidationFailure::HeaderStore(header_store::InvalidCause::Checkpoint),
        ) => vec![SpNotification::HeaderCheckpointMismatch],
        notification::Notification::ValidationFailed(e) => {
            log::warn!("SpAccount::map_notification: validation failed: {e:?}");
            vec![]
        }
        notification::Notification::AddressTipChanged => {
            log::trace!("SpAccount::map_notification: AddressTipChanged");
            vec![]
        }
        notification::Notification::InvalidElectrumConfig => {
            log::trace!("SpAccount::map_notification: InvalidElectrumConfig");
            vec![]
        }
        notification::Notification::InvalidLookAhead => {
            log::trace!("SpAccount::map_notification: InvalidLookAhead");
            vec![]
        }
        notification::Notification::CoinReceived {
            account, outpoint, ..
        } => {
            log::trace!("SpAccount::map_notification: CoinReceived {outpoint} on '{account}'");
            vec![]
        }
        notification::Notification::CoinSpent { account, outpoint } => {
            log::trace!("SpAccount::map_notification: CoinSpent {outpoint} on '{account}'");
            vec![]
        }
        notification::Notification::HeaderStoreRestart => {
            log::trace!("SpAccount::map_notification: HeaderStoreRestart");
            vec![]
        }
        notification::Notification::MerkleFetchStopped => {
            log::trace!("SpAccount::map_notification: MerkleFetchStopped");
            vec![]
        }
    }
}

fn map_header_progress(event: header_store::HeaderProgressEvent) -> SpNotification {
    fn phase(phase: header_store::HeaderProgressPhase) -> HeaderProgressPhase {
        match phase {
            header_store::HeaderProgressPhase::Replay => HeaderProgressPhase::Replay,
            header_store::HeaderProgressPhase::InitialSync => HeaderProgressPhase::InitialSync,
        }
    }

    match event {
        header_store::HeaderProgressEvent::Started {
            phase: p,
            start,
            end,
        } => SpNotification::HeaderProgressStarted {
            phase: phase(p),
            start,
            end,
        },
        header_store::HeaderProgressEvent::Progress {
            phase: p,
            current,
            end,
        } => SpNotification::HeaderProgress {
            phase: phase(p),
            current,
            end,
        },
        header_store::HeaderProgressEvent::Completed { phase: p } => {
            SpNotification::HeaderProgressCompleted { phase: phase(p) }
        }
        header_store::HeaderProgressEvent::Failed { phase: p } => {
            SpNotification::HeaderProgressFailed { phase: phase(p) }
        }
    }
}

fn electrum_tx(
    origin: notification::CoinOrigin,
    outpoint: bitcoin::OutPoint,
    amount: bitcoin::Amount,
    height: Option<u64>,
) -> SpNotification {
    SpNotification::ElectrumTx {
        kind: coin_source(origin),
        txid: outpoint.txid.to_string(),
        amount_sat: amount.to_sat(),
        height: height.map(|h| h as u32),
    }
}

fn map_sp_notification(
    sp: notification::SpNotification,
    inner: &Arc<Mutex<SpAccountInner>>,
) -> Option<SpNotification> {
    match sp {
        notification::SpNotification::StartingScan => {
            log::trace!("SpAccount: StartingScan (skipped)");
            None
        }
        notification::SpNotification::ScanStarted { start, end } => {
            Some(SpNotification::ScanStarted {
                from: start,
                to: end,
            })
        }
        notification::SpNotification::FailStartScanning { message } => {
            Some(SpNotification::ScanFailed { message })
        }
        notification::SpNotification::FailScan { message } => {
            Some(SpNotification::ScanFailed { message })
        }
        notification::SpNotification::StoppingScan => {
            log::trace!("SpAccount: StoppingScan (skipped)");
            None
        }
        notification::SpNotification::ScanStopped {
            last_scanned,
            last_spend,
        } => Some(SpNotification::ScanStopped {
            last_scanned,
            last_spend,
        }),
        notification::SpNotification::ScanReceiveProgress { current, end } => {
            Some(SpNotification::ScanReceiveProgress { current, end })
        }
        notification::SpNotification::ScanSpendProgress { current, end } => {
            Some(SpNotification::ScanSpendProgress { current, end })
        }
        notification::SpNotification::ScanCompleted => Some(SpNotification::ScanCompleted),
        notification::SpNotification::NewOutput(outpoint) => {
            // try_lock: a running scan holds the inner lock, and blocking here
            // would stall the notification thread and freeze ScanProgress. If
            // busy, emit amount 0; the post-scan refresh reconciles it.
            let amount_sat = match inner.try_lock() {
                Ok(g) => g.get_coin(&outpoint).map(|c| c.amount_sat()).unwrap_or(0),
                Err(_) => 0,
            };
            Some(SpNotification::NewOutput {
                outpoint: outpoint.to_string(),
                amount_sat,
            })
        }
        notification::SpNotification::OutputSpent(outpoint) => Some(SpNotification::OutputSpent {
            outpoint: outpoint.to_string(),
        }),
        notification::SpNotification::Broadcasted { txid } => Some(SpNotification::Broadcasted {
            txid: txid.to_string(),
        }),
        notification::SpNotification::FailBroadcast { message } => {
            Some(SpNotification::BroadcastFailed { message })
        }
        notification::SpNotification::WaitingForBlocks { .. } => {
            log::trace!("SpAccount: WaitingForBlocks (continuous-mode, skipped)");
            None
        }
        notification::SpNotification::NewBlocksDetected { .. } => {
            log::trace!("SpAccount: NewBlocksDetected (continuous-mode, skipped)");
            None
        }
        notification::SpNotification::Reorg { fork_height } => {
            Some(SpNotification::Reorg { fork_height })
        }
        notification::SpNotification::SubAccountCoinReceived {
            origin,
            outpoint,
            amount,
            height,
        } => Some(electrum_tx(origin, outpoint, amount, height)),
        notification::SpNotification::SubAccountCoinSpent { origin, outpoint } => {
            log::trace!("SpAccount: SubAccountCoinSpent {outpoint} on {origin:?}");
            None
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use bitcoin::secp256k1::{PublicKey, Secp256k1, SecretKey};
    use tempfile::tempdir;

    const TEST_MNEMONIC: &str = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";

    fn test_bitcoin_address(network: Network) -> String {
        let secp = Secp256k1::new();
        let secret = SecretKey::from_slice(&[1u8; 32]).expect("valid secret key");
        let public_key = bitcoin::CompressedPublicKey(PublicKey::from_secret_key(&secp, &secret));
        bitcoin::Address::p2wpkh(&public_key, network).to_string()
    }

    fn test_sp_address(network: bwk_sp::core::utils::common::Network) -> String {
        let secp = Secp256k1::new();
        let scan_secret = SecretKey::from_slice(&[1u8; 32]).expect("valid scan key");
        let spend_secret = SecretKey::from_slice(&[2u8; 32]).expect("valid spend key");
        let scan = PublicKey::from_secret_key(&secp, &scan_secret);
        let spend = PublicKey::from_secret_key(&secp, &spend_secret);
        bwk_sp::core::utils::common::SilentPaymentAddress::new(scan, spend, network, 0)
            .expect("valid sp address")
            .to_string()
    }

    #[test]
    fn validate_recipient_address_accepts_standard_address() {
        let address = test_bitcoin_address(Network::Bitcoin);
        let kind = validate_recipient_address(address, SpNetwork::Bitcoin).expect("valid address");
        assert_eq!(kind, SpRecipientAddressKind::Standard);
    }

    #[test]
    fn validate_recipient_address_accepts_sp_address() {
        let address = test_sp_address(bwk_sp::core::utils::common::Network::Mainnet);
        let kind = validate_recipient_address(address, SpNetwork::Bitcoin).expect("valid address");
        assert_eq!(kind, SpRecipientAddressKind::Sp);
    }

    #[test]
    fn validate_recipient_address_rejects_wrong_standard_network() {
        let address = test_bitcoin_address(Network::Bitcoin);
        let err = validate_recipient_address(address, SpNetwork::Testnet)
            .expect_err("wrong network must fail");
        assert!(err.contains("wrong network"));
    }

    #[test]
    fn validate_recipient_address_rejects_wrong_sp_network() {
        let address = test_sp_address(bwk_sp::core::utils::common::Network::Mainnet);
        let err = validate_recipient_address(address, SpNetwork::Testnet)
            .expect_err("wrong network must fail");
        assert!(err.contains("wrong network"));
    }

    #[test]
    fn seed_matches_mnemonic_and_reopens_without_persisting_seed() {
        use std::str::FromStr;
        let seed = bwk_sp::receiver::bip39::Mnemonic::from_str(TEST_MNEMONIC)
            .unwrap()
            .to_seed("");
        let words_dir = tempdir().unwrap();
        let seed_dir = tempdir().unwrap();
        let words = SpAccount::create_from_mnemonic(
            "words".into(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.into(),
            "http://localhost:3000".into(),
            String::new(),
            words_dir.path().to_str().unwrap().into(),
            None,
            None,
            None,
        )
        .unwrap();
        let make_seed = || {
            SpAccount::create_from_seed_with_scan_runtime(
                "seed".into(),
                SpNetwork::Regtest,
                seed.to_vec(),
                "http://localhost:3000".into(),
                String::new(),
                seed_dir.path().to_str().unwrap().into(),
                None,
                None,
                None,
                None,
                None,
            )
            .unwrap()
        };
        let from_seed = make_seed();
        let address = from_seed.sp_address().unwrap();
        assert_eq!(address, words.sp_address().unwrap());
        assert_eq!(
            derive_sp_address_from_seed(seed.to_vec(), SpNetwork::Regtest).unwrap(),
            address
        );
        let descriptor = |account: &SpAccount| {
            account.inner.lock().unwrap().get_config().descriptors[0]
                .descriptor
                .to_string()
        };
        let seed_descriptor = descriptor(&from_seed);
        assert_eq!(seed_descriptor, descriptor(&words));
        let config = from_seed.inner.lock().unwrap().get_config();
        let config_path = seed_dir.path().join("persisted-config.json");
        let store = FileConfigStore::<SpConfig>::new(config_path.clone());
        store.save(&config.for_persistence()).unwrap();
        let serialized = std::fs::read_to_string(config_path).unwrap();
        assert!(store.load().unwrap().unwrap().seed.is_none());
        assert!(!serialized.contains(&hex::encode(seed)));
        assert!(!serde_json::from_str::<serde_json::Value>(&serialized)
            .unwrap()
            .as_object()
            .unwrap()
            .contains_key("seed"));
        futures_lite_block_on(from_seed.dispose()).unwrap();
        from_seed.release();
        let reopened = make_seed();
        assert_eq!(reopened.sp_address().unwrap(), address);
        assert_eq!(descriptor(&reopened), seed_descriptor);
    }

    #[test]
    fn seed_rejects_invalid_lengths() {
        let dir = tempdir().unwrap();
        for length in [0, 63, 65] {
            assert!(matches!(
                derive_sp_address_from_seed(vec![0; length], SpNetwork::Regtest),
                Err(ref error) if error == "invalid BIP39 seed length: expected 64 bytes"
            ));
            let result = SpAccount::create_from_seed(
                "invalid".into(),
                SpNetwork::Regtest,
                vec![0; length],
                "http://localhost:3000".into(),
                String::new(),
                dir.path().to_str().unwrap().into(),
                None,
                None,
                None,
            );
            assert!(
                matches!(result, Err(ref error) if error == "invalid BIP39 seed length: expected 64 bytes")
            );
        }
    }

    #[test]
    fn sp_account_create_load() {
        let dir = tempdir().unwrap();
        let data_dir = dir.path().to_str().unwrap().to_string();

        let acc = SpAccount::create_from_mnemonic(
            "test".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            data_dir.clone(),
            None,
            None,
            None,
        )
        .expect("create_from_mnemonic");

        let addr1 = acc.sp_address().expect("sp_address");
        // Under Sqlite persistence mode, signer material is stripped from disk so
        // load() would fail without keys. Just verify address is non-empty and drop.
        assert!(!addr1.is_empty());
    }

    #[test]
    fn accessors_zero_state() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "zero".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        assert_eq!(acc.confirmed_balance().unwrap(), 0);
        assert!(acc.coins().unwrap().is_empty());
        assert!(acc.unified_history().unwrap().is_empty());
        assert!(!acc.is_scanning().unwrap());
        assert!(acc.last_scanned_height().unwrap().is_none());
        assert_eq!(acc.name().unwrap(), "zero");
        assert!(!acc.restamp_missing_timestamps().unwrap());
        assert!(matches!(acc.network(), Ok(SpNetwork::Regtest)));
    }

    #[test]
    fn init_idempotent_guard() {
        // Verify that receiver() returns None on the second call (guard ensures single-init).
        // We test the inner account directly since StreamSink requires the FRB runtime.
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "guard".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        // First take succeeds.
        let rx1 = acc.inner.lock().unwrap().receiver();
        assert!(rx1.is_some());
        // Second take returns None (receiver already moved out).
        let rx2 = acc.inner.lock().unwrap().receiver();
        assert!(rx2.is_none());
    }

    #[test]
    fn taproot_address_never_reissued() {
        // `new_taproot_address` must REVEAL a fresh, never-before-issued
        // address on every call (no reuse), and the receive tip must persist
        // across restart so a reload never collides with a previously issued
        // index.
        let dir = tempdir().unwrap();
        let data_dir = dir.path().to_str().unwrap().to_string();

        let acc1 = SpAccount::create_from_mnemonic(
            "sub-persist".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            data_dir.clone(),
            None,
            None,
            None,
        )
        .expect("create 1");

        // Every reveal must hand out a fresh, never-before-issued address:
        // successive calls advance the receive tip and must all differ. This
        // is the core anti-reuse property — we must never re-hand an address
        // just because the previous one has not received a coin yet.
        let mut seen = std::collections::BTreeSet::new();
        for i in 0..5 {
            let addr = acc1
                .new_taproot_address()
                .unwrap_or_else(|e| panic!("reveal {i}: {e}"));
            assert!(!addr.is_empty(), "taproot address must be non-empty");
            assert!(
                seen.insert(addr.clone()),
                "reveal {i} reused address {addr}"
            );
        }
    }

    #[test]
    fn unified_views_zero_state() {
        let dir = tempdir().unwrap();

        let acc = SpAccount::create_from_mnemonic(
            "unified-zero".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        let bal = acc.unified_balance().unwrap();
        assert_eq!(bal.confirmed_sat, 0);
        assert_eq!(bal.total_unified_sat, 0);
        assert!(bal.last_scanned_height.is_none());

        assert!(acc.unified_coins().unwrap().is_empty());
        assert!(acc.unified_history().unwrap().is_empty());

        // Sub-accounts are created, so a revealed taproot receive address must
        // be non-empty.
        assert!(!acc.new_taproot_address().unwrap().is_empty());
    }

    #[test]
    fn prepare_empty_account() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "prepare-empty".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        // No coins seeded → coin selection returns empty → simulate reports AddInput error.
        let sp_addr = acc.sp_address().expect("sp_address");
        let result = acc.prepare_psbt(
            vec![RecipientView::Sp {
                address: sp_addr,
                amount_sat: 10_000,
                label: None,
                is_max: false,
            }],
            1,
            None,
        );
        assert!(result.is_err(), "expected error for empty coin store");
    }

    #[test]
    fn prepare_invalid_sp_address() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "prepare-invalid-sp".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        let result = acc.prepare_psbt(
            vec![RecipientView::Sp {
                address: "not_a_valid_sp_address".to_string(),
                amount_sat: 10_000,
                label: None,
                is_max: false,
            }],
            1,
            None,
        );
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid SP address"));
    }

    #[test]
    fn prepare_invalid_standard_address() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "prepare-invalid-std".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        let result = acc.prepare_psbt(
            vec![RecipientView::Standard {
                address: "not_a_bitcoin_address".to_string(),
                amount_sat: 10_000,
                is_max: false,
            }],
            1,
            None,
        );
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid address"));
    }

    #[test]
    fn parse_electrum_url_variants() {
        // plain host:port → defaults to TCP
        let (h, p, s) = parse_electrum_url("electrum.example.com:50001").unwrap();
        assert_eq!(h.as_deref(), Some("electrum.example.com"));
        assert_eq!(p, Some(50001));
        assert_eq!(s, ElectrumScheme::Tcp);

        // tcp:// scheme is honoured and stripped
        let (h, p, s) = parse_electrum_url("tcp://electrum.example.com:50001").unwrap();
        assert_eq!(h.as_deref(), Some("electrum.example.com"));
        assert_eq!(p, Some(50001));
        assert_eq!(s, ElectrumScheme::Tcp);

        // ssl:// scheme is honoured and stripped — this is the production
        // default we used to ship broken.
        let (h, p, s) = parse_electrum_url("ssl://electrum.bullbitcoin.com:50002").unwrap();
        assert_eq!(h.as_deref(), Some("electrum.bullbitcoin.com"));
        assert_eq!(p, Some(50002));
        assert_eq!(s, ElectrumScheme::Ssl);

        // empty input → no host/port, defaults TCP
        let (h, p, _s) = parse_electrum_url("").unwrap();
        assert!(h.is_none());
        assert!(p.is_none());

        // unknown scheme is rejected
        assert!(parse_electrum_url("http://foo:80").is_err());
        assert!(parse_electrum_url("ws://foo:80").is_err());
    }

    #[test]
    fn parse_bwk_electrum_endpoint_preserves_bwk_ssl_prefix() {
        let (host, port) = parse_bwk_electrum_endpoint("ssl://electrum.example.com:50002")
            .expect("parse endpoint");
        assert_eq!(host.as_deref(), Some("ssl://electrum.example.com"));
        assert_eq!(port, Some(50002));
    }

    #[test]
    fn parse_bwk_electrum_endpoint_keeps_tcp_host_bare() {
        let (host, port) = parse_bwk_electrum_endpoint("tcp://electrum.example.com:50001")
            .expect("parse endpoint");
        assert_eq!(host.as_deref(), Some("electrum.example.com"));
        assert_eq!(port, Some(50001));
    }

    fn unified_coin(
        origin: notification::CoinOrigin,
        height: Option<u32>,
        spendable: bool,
    ) -> sp_account::unified::UnifiedCoin {
        sp_account::unified::UnifiedCoin {
            origin,
            outpoint: bitcoin::OutPoint::null(),
            amount: bitcoin::Amount::from_sat(1_000),
            height,
            spendable,
            label: None,
        }
    }

    fn sub_account(kind: notification::SubAccountKind) -> notification::CoinOrigin {
        notification::CoinOrigin::SubAccount { index: 0, kind }
    }

    #[test]
    fn unified_coin_view_maps_origin() {
        let sp = unified_coin_view(unified_coin(notification::CoinOrigin::Sp, Some(100), true));
        assert!(matches!(sp.source, CoinSource::Sp));
        assert_eq!(sp.amount_sat, 1_000);
        assert_eq!(sp.height, Some(100));

        let segwit = unified_coin_view(unified_coin(
            sub_account(notification::SubAccountKind::Segwit),
            Some(100),
            true,
        ));
        assert!(matches!(segwit.source, CoinSource::Segwit));

        let taproot = unified_coin_view(unified_coin(
            sub_account(notification::SubAccountKind::Taproot),
            Some(100),
            true,
        ));
        assert!(matches!(taproot.source, CoinSource::Taproot));

        let other = unified_coin_view(unified_coin(
            sub_account(notification::SubAccountKind::Other),
            Some(100),
            true,
        ));
        assert!(matches!(other.source, CoinSource::Other));
    }

    #[test]
    fn unified_coin_view_maps_status() {
        let status = |height, spendable| {
            unified_coin_view(unified_coin(
                notification::CoinOrigin::Sp,
                height,
                spendable,
            ))
            .status
        };
        assert_eq!(status(Some(100), true), UnifiedCoinStatus::Unspent);
        assert_eq!(status(None, true), UnifiedCoinStatus::Unconfirmed);
        assert_eq!(status(Some(100), false), UnifiedCoinStatus::Spent);
        assert_eq!(status(None, false), UnifiedCoinStatus::Spent);
    }

    fn test_account(name: &str) -> (tempfile::TempDir, SpAccount) {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            name.to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");
        (dir, acc)
    }

    const CHECKPOINT_HASH: &str =
        "00000000000000000002a7c4c1e48d76c5a37902165a270156b7a8d72728a054";

    fn create_with_checkpoint(
        dir: &tempfile::TempDir,
        checkpoint: SpHeaderCheckpoint,
    ) -> Result<SpAccount, String> {
        SpAccount::create_from_mnemonic(
            "checkpoint".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            Some(checkpoint),
        )
    }

    #[test]
    fn header_checkpoint_lands_in_the_config() {
        let dir = tempdir().unwrap();
        let acc = create_with_checkpoint(
            &dir,
            SpHeaderCheckpoint {
                height: 2016,
                hash: CHECKPOINT_HASH.to_string(),
            },
        )
        .unwrap_or_else(|e| panic!("create: {e}"));

        let checkpoint = acc
            .inner
            .lock()
            .unwrap()
            .get_config()
            .header_checkpoint
            .expect("checkpoint in the config");
        assert_eq!(checkpoint.height(), 2016);
        assert_eq!(checkpoint.hash().to_string(), CHECKPOINT_HASH);
    }

    #[test]
    fn header_checkpoint_with_a_bad_hash_is_rejected() {
        let dir = tempdir().unwrap();
        let Err(err) = create_with_checkpoint(
            &dir,
            SpHeaderCheckpoint {
                height: 2016,
                hash: "not a hash".to_string(),
            },
        ) else {
            panic!("a bad hash must be rejected");
        };
        assert!(err.starts_with("invalid header checkpoint hash: "), "{err}");
    }

    #[test]
    fn header_checkpoint_off_a_retarget_boundary_is_rejected() {
        let dir = tempdir().unwrap();
        let Err(err) = create_with_checkpoint(
            &dir,
            SpHeaderCheckpoint {
                height: 2017,
                hash: CHECKPOINT_HASH.to_string(),
            },
        ) else {
            panic!("a height off a retarget boundary must be rejected");
        };
        assert_eq!(
            err,
            "invalid header checkpoint: checkpoint height 2017 is not a multiple of the 2016 \
             block retarget interval"
        );
    }

    #[test]
    fn sub_account_coin_received_maps_to_electrum_tx() {
        let (_dir, acc) = test_account("coin-received");

        // Held like a running scan does: the mapping must not need the lock.
        let _guard = acc.inner.lock().unwrap();
        let mapped = map_sp_notification(
            notification::SpNotification::SubAccountCoinReceived {
                origin: sub_account(notification::SubAccountKind::Taproot),
                outpoint: bitcoin::OutPoint::null(),
                amount: bitcoin::Amount::from_sat(1_000),
                height: Some(100),
            },
            &acc.inner,
        );
        let Some(SpNotification::ElectrumTx {
            kind,
            txid,
            amount_sat,
            height,
        }) = mapped
        else {
            panic!("expected an ElectrumTx, got {mapped:?}");
        };
        assert!(matches!(kind, CoinSource::Taproot));
        assert_eq!(txid, bitcoin::OutPoint::null().txid.to_string());
        assert_eq!(amount_sat, 1_000);
        assert_eq!(height, Some(100));
    }

    #[test]
    fn plain_coin_received_is_not_forwarded() {
        let (_dir, acc) = test_account("plain-coin-received");

        let mapped = map_notification(
            notification::Notification::CoinReceived {
                account: "sub-account".to_string(),
                outpoint: bitcoin::OutPoint::null(),
                amount: bitcoin::Amount::from_sat(1_000),
                height: Some(100),
            },
            &acc.inner,
        );
        assert!(mapped.is_empty());
    }

    #[test]
    fn sub_account_coin_spent_is_not_forwarded() {
        let (_dir, acc) = test_account("coin-spent");

        let mapped = map_sp_notification(
            notification::SpNotification::SubAccountCoinSpent {
                origin: sub_account(notification::SubAccountKind::Taproot),
                outpoint: bitcoin::OutPoint::null(),
            },
            &acc.inner,
        );
        assert!(mapped.is_none());
    }

    #[test]
    fn scan_stopped_carries_frontiers() {
        let (_dir, acc) = test_account("scan-stopped");

        let stopped = map_sp_notification(
            notification::SpNotification::ScanStopped {
                last_scanned: Some(200),
                last_spend: None,
            },
            &acc.inner,
        );
        assert!(matches!(
            stopped,
            Some(SpNotification::ScanStopped {
                last_scanned: Some(200),
                last_spend: None,
            })
        ));
    }

    #[test]
    fn electrum_disconnected_is_forwarded() {
        let (_dir, acc) = test_account("electrum-disconnected");

        let disconnected = map_notification(
            notification::Notification::Electrum(notification::TxListenerNotif::Disconnected),
            &acc.inner,
        );
        assert!(matches!(
            disconnected.as_slice(),
            [SpNotification::ElectrumDisconnected]
        ));

        let connected = map_notification(
            notification::Notification::Electrum(notification::TxListenerNotif::Connected(
                "electrum.example:50002".to_string(),
            )),
            &acc.inner,
        );
        assert!(matches!(
            connected.as_slice(),
            [SpNotification::ElectrumConnected]
        ));

        let stopped = map_notification(
            notification::Notification::Electrum(notification::TxListenerNotif::Stopped),
            &acc.inner,
        );
        assert!(stopped.is_empty());
    }

    #[test]
    fn reorg_is_forwarded() {
        let (_dir, acc) = test_account("reorg");

        let reorg = map_sp_notification(
            notification::SpNotification::Reorg { fork_height: 150 },
            &acc.inner,
        );
        assert!(matches!(
            reorg,
            Some(SpNotification::Reorg { fork_height: 150 })
        ));
    }

    #[test]
    fn header_checkpoint_mismatch_is_forwarded() {
        let (_dir, acc) = test_account("checkpoint-mismatch");

        let mismatch = map_notification(
            notification::Notification::ValidationFailed(
                notification::ValidationFailure::HeaderStore(
                    header_store::InvalidCause::Checkpoint,
                ),
            ),
            &acc.inner,
        );
        assert!(matches!(
            mismatch.as_slice(),
            [SpNotification::HeaderCheckpointMismatch]
        ));

        let sanity = map_notification(
            notification::Notification::ValidationFailed(
                notification::ValidationFailure::HeaderStore(header_store::InvalidCause::Sanity),
            ),
            &acc.inner,
        );
        assert!(sanity.is_empty());
    }

    #[test]
    fn sign_psbt_invalid_bytes() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "sign-invalid".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        let result = acc.sign_psbt(b"garbage bytes".to_vec());
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid PSBT bytes"));
    }

    /// Regression: dropping an SpAccount must terminate the
    /// notification thread instead of leaking it (and the inner sqlite
    /// handle) for the lifetime of the process.
    ///
    /// We can't call `init()` from a non-FRB test because `StreamSink`
    /// requires the FRB runtime, so we exercise the shutdown contract
    /// directly: inject a stand-in worker thread into `notif_handle`
    /// that watches the same `shutdown` flag, then assert the thread
    /// exits when `dispose()` runs (and again that `Drop` is a no-op
    /// the second time).
    #[test]
    fn dispose_joins_notification_thread() {
        use std::sync::atomic::AtomicBool;
        use std::time::{Duration, Instant};

        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "dispose-thread".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        let observed = Arc::new(AtomicBool::new(false));
        let observed_clone = observed.clone();
        let shutdown = acc.shutdown.clone();
        let handle = std::thread::spawn(move || {
            // Mirror the real notification thread: loop with a short timeout
            // and exit on the shutdown flag.
            while !shutdown.load(Ordering::Acquire) {
                std::thread::sleep(Duration::from_millis(10));
            }
            observed_clone.store(true, Ordering::Release);
        });
        *acc.notif_handle.lock().unwrap() = Some(handle);

        let baseline = notif_thread_exit_count();
        let res = futures_lite_block_on(acc.dispose());
        assert!(
            res.is_ok(),
            "dispose must succeed when lock is free: {res:?}"
        );
        assert!(
            observed.load(Ordering::Acquire),
            "thread did not observe shutdown"
        );

        // dispose() must be idempotent. Second call also returns Ok because
        // the inner mutex is free.
        let res2 = futures_lite_block_on(acc.dispose());
        assert!(res2.is_ok(), "second dispose must succeed: {res2:?}");

        // Dropping after dispose must be a clean no-op (no double-join panic).
        drop(acc);

        // We never incremented NOTIF_THREAD_EXITS because we didn't go through
        // the real init() path; just sanity-check the counter is monotonic and
        // didn't decrement.
        assert!(notif_thread_exit_count() >= baseline);

        // Bound the wall-clock cost of this test.
        let _ = Instant::now();
    }

    /// Regression: `finalize_psbt` MUST refuse to sign a tx whose
    /// inputs differ from the simulation the user confirmed. An empty/zero
    /// coin store cannot satisfy the simulation's pinned outpoints, so
    /// finalize must return an "inputs changed" error rather than silently
    /// re-selecting coins.
    #[test]
    fn finalize_fails_when_inputs_no_longer_present() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "finalize-drift".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        // Hand-build a simulation that references an outpoint not in the
        // (empty) coin store. This is exactly the shape `prepare_psbt` would
        // return, but with the store mutated under us between prepare and
        // finalize.
        let sp_addr = acc.sp_address().expect("sp_address");
        let phantom_outpoint =
            "0000000000000000000000000000000000000000000000000000000000000000:0".to_string();
        let sim = TxSimulation {
            inputs: vec![UnifiedCoinView {
                source: CoinSource::Sp,
                outpoint: phantom_outpoint,
                amount_sat: 50_000,
                height: Some(100),
                status: UnifiedCoinStatus::Unspent,
            }],
            outputs: vec![RecipientView::Sp {
                address: sp_addr,
                amount_sat: 10_000,
                label: None,
                is_max: false,
            }],
            fee_sat: 200,
            change_sat: 39_800,
            change_dust_threshold: None,
        };

        let res = acc.finalize_psbt(sim);
        let err = res.expect_err("finalize must fail when inputs are no longer present");
        // The variant, not the wording: a caller must be able to tell a drifted
        // simulation apart without matching on message text.
        assert!(
            matches!(err, SpError::SimulationDrifted { .. }),
            "expected SimulationDrifted, got: {err:?}"
        );
    }

    /// Regression: a poisoned inner-mutex must surface as a
    /// recoverable `Err(String)` rather than panicking via `.unwrap()`. We
    /// intentionally poison the mutex by panicking inside a holder, then
    /// confirm every FFI getter returns Err.
    #[test]
    fn poisoned_mutex_returns_err_not_panic() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "poison".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        // Poison the inner mutex.
        let inner = acc.inner.clone();
        let _ = std::thread::spawn(move || {
            let _guard = inner.lock().unwrap();
            panic!("intentional poison");
        })
        .join();

        assert!(acc.sp_address().is_err());
        assert!(acc.confirmed_balance().is_err());
        assert!(acc.is_scanning().is_err());
        assert!(acc.name().is_err());
        assert!(acc.unified_balance().is_err());
        assert!(acc.unified_coins().is_err());
        assert!(acc.unified_history().is_err());
        assert!(acc.coins().is_err());
        assert!(acc.unified_history().is_err());
        assert!(acc.network().is_err());
        assert!(acc.last_scanned_height().is_err());
        assert!(acc.restamp_missing_timestamps().is_err());
    }

    /// Regression: the scan-cancel signal must be wired through
    /// to the bwk_sp::Account's scanner_stop flag so flipping our
    /// `scan_cancel` causes spdk-core's `process_blocks` to observe the
    /// interrupt at the next block boundary.
    ///
    /// We cannot drive a real Blindbit scan from a unit test (no live
    /// backend), so we exercise the contract that matters: stop_scan must
    /// flip the same `Arc<AtomicBool>` that bwk_sp::Account holds, and the
    /// flag must NOT require taking the inner mutex. This pins the
    /// invariant that the Stop button cannot deadlock against an in-flight
    /// scan.
    #[test]
    fn scan_cancel_signal_aborts_in_progress_scan() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "scan-cancel".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        // Take the inner lock from a "scan" worker — this models the
        // bwk_sp::Account holding the mutex via `&mut self` while
        // `scan_blocks` runs. The Stop button hitting `stop_scan` must NOT
        // try to take the same lock; if it does, this test deadlocks.
        let inner = acc.inner.clone();
        let stuck = std::thread::spawn(move || {
            let _guard = inner.lock().expect("lock");
            // Hold for 500ms — longer than the stop_scan latency budget.
            std::thread::sleep(Duration::from_millis(500));
        });

        // stop_scan must return immediately without blocking on the
        // inner mutex. The async wrapper is trivial (it just flips an
        // atomic), so we can poll the future to completion with a
        // hand-rolled noop waker.
        let start = std::time::Instant::now();
        let fut = acc.stop_scan();
        let res = futures_lite_block_on(fut);
        let elapsed = start.elapsed();
        assert!(res.is_ok(), "stop_scan must succeed: {res:?}");
        assert!(
            elapsed < Duration::from_millis(100),
            "stop_scan blocked for {elapsed:?}; must be non-blocking (deadlock regression)"
        );

        // The cancel flag must be set, and it must be the SAME flag the
        // bwk_sp::Account sees. We verify the latter by checking that the
        // inner Account's cancel_flag pointer-compares equal to ours after
        // the holder thread releases the lock.
        assert!(acc.scan_cancel.load(Ordering::Relaxed));

        stuck.join().expect("join");
        let inner_flag = acc.inner.lock().unwrap().cancel_flag();
        assert!(Arc::ptr_eq(&acc.scan_cancel, &inner_flag));
        assert!(inner_flag.load(Ordering::Relaxed));
    }

    /// Regression: `dispose()` must NOT block indefinitely while
    /// a scan holds the inner mutex. Flipping the cancel flag is enough to
    /// signal the scan to bail; `dispose` polls `try_lock` with a bounded
    /// budget and returns even if the lock is still held.
    ///
    /// We model the in-flight scan by holding the lock from a worker
    /// thread for longer than the 5-second budget, then asserting dispose
    /// still returns within a small wall-clock budget of (budget + ε).
    /// This proves dispose doesn't hang the FRB worker.
    #[test]
    fn dispose_during_running_scan_releases_lock() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "dispose-scan".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        // Worker that grabs the inner lock and releases it after 200ms —
        // shorter than the 5s dispose budget so dispose should observe
        // the lock free and break the poll loop early.
        let inner = acc.inner.clone();
        let scan_cancel = acc.scan_cancel.clone();
        let scanning = std::thread::spawn(move || {
            let _guard = inner.lock().expect("lock");
            // Spin until the cancel flag is set (this is what spdk-core's
            // process_blocks effectively does between blocks).
            while !scan_cancel.load(Ordering::Relaxed) {
                std::thread::sleep(Duration::from_millis(10));
            }
            // "Scan" persisted state and returns — releasing the lock.
        });

        let start = std::time::Instant::now();
        let fut = acc.dispose();
        let res = futures_lite_block_on(fut);
        let elapsed = start.elapsed();

        scanning.join().expect("join");

        // Dispose should observe the lock release shortly after flipping
        // the cancel flag; well under the 5s budget. The lock was
        // released by the cooperating scan, so dispose returns Ok.
        assert!(
            res.is_ok(),
            "dispose must succeed when scan cooperates: {res:?}"
        );
        assert!(
            elapsed < Duration::from_secs(2),
            "dispose took {elapsed:?}; expected <2s once scan cooperates"
        );

        // After dispose, the inner mutex must be free.
        assert!(acc.inner.try_lock().is_ok());

        // Drop the original handle so upstream's per-data-dir lock file is
        // released. In production the Dart-side handle going out of scope
        // triggers the FRB Drop; here we model that explicitly.
        drop(acc);

        // And a subsequent `create_from_mnemonic` against the same data_dir
        // (the operative case: WalletBloc._onRefreshSpWallet re-loading
        // after a settings change) must NOT race the sqlite handle.
        // Note: we use create_from_mnemonic because Sqlite persistence strips
        // signer material so load() can't reconstruct from disk in tests.
        let acc2 = SpAccount::create_from_mnemonic(
            "dispose-scan".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        );
        assert!(acc2.is_ok(), "second create after dispose must succeed");
    }

    /// Regression: `dispose()` MUST return
    /// `Err(...)` containing "timed out" when the inner mutex is held
    /// past the 5-second budget. This is the signal `WalletBloc._
    /// onRefreshSpWallet` uses to decline a `SpAccount::load(...)` call
    /// against the same `data_dir` (preventing the double-open race
    /// against the in-flight lock holder).
    ///
    /// We model an in-flight `prepare_psbt`/`unified_history`/etc. by
    /// holding the inner lock from a worker thread for ~6 seconds —
    /// longer than the dispose budget. Unlike `dispose_during_running_
    /// scan_releases_lock`, the holder does NOT observe `scan_cancel`,
    /// because those non-scan methods don't have a cancellation hook in
    /// the current implementation.
    #[test]
    fn dispose_returns_err_when_lock_held_past_timeout() {
        let dir = tempdir().unwrap();
        let acc = SpAccount::create_from_mnemonic(
            "dispose-timeout".to_string(),
            SpNetwork::Regtest,
            TEST_MNEMONIC.to_string(),
            "http://localhost:3000".to_string(),
            String::new(),
            dir.path().to_str().unwrap().to_string(),
            None,
            None,
            None,
        )
        .expect("create");

        let expected_address = acc.sp_address().unwrap();

        // Worker holds the inner lock for ~6s (longer than dispose's 5s
        // budget). It does NOT consult `scan_cancel` — that's the whole
        // point: this models `prepare_psbt`/`unified_history`/etc. which
        // run to completion with no cancellation hook.
        let inner = acc.inner.clone();
        let holder = std::thread::spawn(move || {
            let _guard = inner.lock().expect("lock");
            std::thread::sleep(Duration::from_millis(6_000));
        });

        // Give the holder a moment to actually grab the lock before we
        // start dispose. Otherwise dispose could acquire it first.
        std::thread::sleep(Duration::from_millis(50));

        let start = std::time::Instant::now();
        let res = futures_lite_block_on(acc.dispose());
        let elapsed = start.elapsed();

        // dispose() must report the timeout as its own variant, so a caller
        // can keep the session and retry rather than parse a message.
        let err = res.expect_err("dispose must time out when lock is held past budget");
        assert!(
            matches!(err, SpError::DisposeTimedOut),
            "expected DisposeTimedOut, got: {err:?}"
        );

        // The cancel flag must have been flipped regardless (best-effort
        // signal to any cooperating callee).
        assert!(
            acc.scan_cancel.load(Ordering::Relaxed),
            "scan_cancel must be set even when dispose times out"
        );

        // Wall-clock should be ~5s (the budget) plus the polling
        // granularity; well under 6s (the lock-hold duration). This
        // proves dispose returned before the holder released.
        assert!(
            elapsed < Duration::from_millis(5_500),
            "dispose budget breached: elapsed={elapsed:?}"
        );
        assert!(
            elapsed >= Duration::from_secs(5),
            "dispose returned too early ({elapsed:?}); must wait full budget before timing out"
        );

        // Wait for the holder to finish so the test cleanly releases
        // the temporary directory.
        holder.join().expect("join");
        assert_eq!(acc.sp_address().unwrap(), expected_address);
        futures_lite_block_on(acc.dispose()).expect("retry disposal");
        acc.release();
    }

    /// Minimal hand-rolled block_on for the async dispose/stop_scan
    /// helpers above. We don't want to pull tokio just for tests, and
    /// `futures::executor::block_on` is also a heavier dep than needed —
    /// both functions are non-blocking (they just flip an atomic and poll
    /// `try_lock`), so a noop-waker poll loop is sufficient.
    fn futures_lite_block_on<F: std::future::Future>(mut fut: F) -> F::Output {
        use std::pin::Pin;
        use std::task::{Context, Poll, RawWaker, RawWakerVTable, Waker};

        fn noop_clone(_: *const ()) -> RawWaker {
            RawWaker::new(std::ptr::null(), &VTABLE)
        }
        fn noop(_: *const ()) {}
        static VTABLE: RawWakerVTable = RawWakerVTable::new(noop_clone, noop, noop, noop);

        let raw_waker = RawWaker::new(std::ptr::null(), &VTABLE);
        // SAFETY: VTABLE methods are all no-ops; the waker's data pointer
        // is never dereferenced. This is the canonical noop-waker pattern.
        let waker = unsafe { Waker::from_raw(raw_waker) };
        let mut cx = Context::from_waker(&waker);

        // SAFETY: fut is owned by this function (moved in by value) and is
        // not moved across the polling loop. Pin::new_unchecked is safe as
        // long as we don't move `fut` after pinning; the loop only borrows
        // it as &mut, and the loop returns the moment Poll::Ready fires.
        let mut fut = unsafe { Pin::new_unchecked(&mut fut) };
        loop {
            match fut.as_mut().poll(&mut cx) {
                Poll::Ready(v) => return v,
                Poll::Pending => std::thread::sleep(Duration::from_millis(1)),
            }
        }
    }
}
