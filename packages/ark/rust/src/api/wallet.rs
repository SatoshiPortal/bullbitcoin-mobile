use std::path::PathBuf;
use std::str::FromStr;
use std::sync::Arc;

use bark::onchain::OnchainWallet;
use bark::payment_request::ArkAddressType;
use bark::persist::BarkPersister;
use bark::vtxo::VtxoState;
use bark::{Config, OpenWalletArgs, Wallet, WalletSeed};
use bitcoin::bip32::{Xpriv, Xpub};
use bitcoin::hashes::{Hash, sha256};
use bitcoin::secp256k1::Secp256k1;
use bitcoin::{Amount, Network, Psbt};
use flutter_rust_bridge::frb;
use tokio::sync::{Mutex, RwLock};
use zeroize::Zeroizing;

use super::exit::ScuttleExitProgressReview;

pub enum ScuttleNetwork {
    Bitcoin,
    Testnet,
    Signet,
    Regtest,
}

pub enum OpenMode {
    New,
    Existing,
}

/// Outcome reported by this open only, not a durable recovery receipt.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttleRecoveryStatus {
    Unknown,
    NotRun,
    Complete,
    Incomplete,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttleVtxoState {
    Spendable,
    Locked,
    Spent,
    Exited,
}

pub struct ScuttleVtxo {
    pub id: String,
    pub amount_sats: u64,
    pub expiry_height: u32,
    pub state: ScuttleVtxoState,
}

/// Local inventory and chain tip, not proof of a complete or current sync.
pub struct ScuttleObservation {
    pub tip_height: u32,
    pub last_known_spendable_sats: u64,
    pub vtxos: Vec<ScuttleVtxo>,
}

#[frb(opaque)]
pub struct ScuttleWallet {
    pub(super) wallet: Mutex<Option<ScuttleSession>>,
    pub(super) account_id: String,
}

#[frb(ignore)]
pub(super) struct ScuttleSession {
    pub(super) wallet: Wallet,
    pub(super) db: Arc<bark::persist::sqlite::SqliteClient>,
    pub(super) onchain: Arc<RwLock<OnchainWallet>>,
    pub(super) progress_review: Option<ScuttleExitProgressReview>,
    pub(super) recovery_status: ScuttleRecoveryStatus,
}

#[frb(ignore)]
fn map_recovery(status: bark::RecoveryStatus) -> ScuttleRecoveryStatus {
    match status {
        bark::RecoveryStatus::NotRun => ScuttleRecoveryStatus::NotRun,
        bark::RecoveryStatus::Failed(_) => ScuttleRecoveryStatus::Failed,
        bark::RecoveryStatus::InProgress(_) => ScuttleRecoveryStatus::Incomplete,
        bark::RecoveryStatus::Completed(report) if report.is_complete() => {
            ScuttleRecoveryStatus::Complete
        }
        bark::RecoveryStatus::Completed(_) => ScuttleRecoveryStatus::Incomplete,
    }
}

impl std::ops::Deref for ScuttleSession {
    type Target = Wallet;

    fn deref(&self) -> &Wallet {
        &self.wallet
    }
}

/// The caller must durably store the complete token before funding the address.
pub struct ScuttleBoardFunding {
    pub address: String,
    pub expiry_height: u32,
    pub token: String,
}

/// Live parameters for quoting a board, not evidence about the VTXO inventory.
pub struct ScuttleBoardTerms {
    pub server_key: String,
    pub tip_height: u32,
    pub tip_hash: String,
    pub required_confirmations: u32,
    pub gross_sats: u64,
    pub fee_sats: u64,
    pub net_sats: u64,
}

pub struct ScuttleBoardAnchor {
    pub height: u32,
    pub hash: String,
}

pub struct ScuttleBoardResult {
    pub funding_txid: String,
    pub movement_id: u32,
    pub amount_sats: u64,
    pub vtxo_ids: Vec<String>,
}

impl ScuttleWallet {
    /// The mnemonic is child-only material; the caller remains responsible for its copy.
    pub async fn open(
        network: ScuttleNetwork,
        mode: OpenMode,
        datadir: String,
        server_address: String,
        esplora_address: String,
        child_mnemonic: String,
        allow_unreachable_server: bool,
    ) -> Result<Self, String> {
        let child_mnemonic = Zeroizing::new(child_mnemonic);
        let seed_bytes = Zeroizing::new(
            bark::bip39::Mnemonic::parse_in_normalized(
                bark::bip39::Language::English,
                &child_mnemonic,
            )
            .map_err(|_| "Invalid child mnemonic")?
            .to_seed(""),
        );
        let network = match network {
            ScuttleNetwork::Bitcoin => Network::Bitcoin,
            ScuttleNetwork::Testnet => Network::Testnet,
            ScuttleNetwork::Signet => Network::Signet,
            ScuttleNetwork::Regtest => Network::Regtest,
        };
        let account_id = child_account_id(network, &seed_bytes)?;
        let seed = WalletSeed::new_from_seed(network, &seed_bytes);
        drop(child_mnemonic);

        let path = PathBuf::from(datadir);
        if matches!(mode, OpenMode::New) {
            std::fs::create_dir_all(&path).map_err(|_| "Cannot prepare wallet directory")?;
        }
        let path = path
            .canonicalize()
            .map_err(|_| "Cannot access wallet directory")?;
        let lock = bark::lock_manager::platform_default(Some(&path), Some(seed.fingerprint()))
            .map_err(|_| "Cannot lock wallet directory")?;
        let db_exists = path.join(bark::persist::sqlite::DEFAULT_DB_FILE).exists();
        match (mode, db_exists) {
            (OpenMode::New, true) => return Err("Wallet data already exists".into()),
            (OpenMode::Existing, false) => return Err("Wallet data not found".into()),
            _ => {}
        }
        let db = Arc::new(
            bark::persist::sqlite::SqliteClient::open(
                path.join(bark::persist::sqlite::DEFAULT_DB_FILE),
            )
            .map_err(|_| "Cannot open wallet")?,
        );
        let properties = db
            .read_properties()
            .await
            .map_err(|_| "Cannot open wallet")?;
        if db_exists {
            match properties {
                Some(properties)
                    if properties.network == network
                        && properties.fingerprint == seed.fingerprint() => {}
                _ => return Err("Cannot open wallet".into()),
            }
        } else if properties.is_some() {
            return Err("Cannot open wallet".into());
        }
        // Scuttle and bark-ffi 0.8.1 both use the same child BIP39 seed with BIP86.
        // Loading initializes BDK tables even when no wallet changeset exists.
        let onchain = Arc::new(RwLock::new(
            OnchainWallet::load_or_create(network, *seed_bytes, db.clone())
                .await
                .map_err(|_| "Cannot open wallet")?,
        ));
        drop(seed_bytes);
        let config = Config {
            server_address,
            esplora_address: Some(esplora_address),
            ..Config::network_default(network)
        };
        let recovery_status = Arc::new(std::sync::Mutex::new(ScuttleRecoveryStatus::Unknown));
        let callback_status = Arc::clone(&recovery_status);
        let wallet = Wallet::open(
            network,
            seed,
            config,
            OpenWalletArgs {
                datadir: Some(path),
                persister: Some(db.clone()),
                lock_manager: Some(lock),
                onchain: Some(onchain.clone()),
                create_if_not_exists: !db_exists,
                create_without_server: allow_unreachable_server,
                run_daemon: false,
                on_recovery_finished: Some(Box::new(move |status| {
                    if let Ok(mut result) = callback_status.lock() {
                        *result = map_recovery(status);
                    }
                })),
                ..Default::default()
            },
        )
        .await
        .map_err(|_| "Cannot open wallet")?;
        if wallet.network().await.map_err(|_| "Cannot open wallet")? != network {
            return Err("Cannot open wallet".into());
        }
        let recovery_status = *recovery_status
            .lock()
            .map_err(|_| "Cannot read recovery status")?;
        Ok(Self {
            wallet: Mutex::new(Some(ScuttleSession {
                wallet,
                db,
                onchain,
                progress_review: None,
                recovery_status,
            })),
            account_id,
        })
    }

    pub async fn fingerprint(&self) -> Result<String, String> {
        let guard = self.wallet.lock().await;
        guard
            .as_ref()
            .map(|wallet| wallet.fingerprint().to_string())
            .ok_or_else(|| "Wallet closed".into())
    }

    /// Reports the recovery callback from this particular open.
    pub async fn recovery_status(&self) -> Result<ScuttleRecoveryStatus, String> {
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        Ok(session.recovery_status)
    }

    /// Performs the native initial scan, which can also rebroadcast stored transactions.
    pub async fn initial_scan(&self) -> Result<(), String> {
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        let mut onchain = session.onchain.write().await;
        onchain
            .initial_wallet_scan(session.wallet.chain(), None)
            .await
            .map(|_| ())
            .map_err(|_| "Cannot scan onchain wallet".into())
    }

    /// Reads the chain source tip and cached native inventory without synchronizing it.
    pub async fn observation(&self) -> Result<ScuttleObservation, String> {
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        let tip = session
            .wallet
            .chain()
            .tip()
            .await
            .map_err(|_| "Cannot observe chain tip")?;
        let vtxos = session
            .wallet
            .all_vtxos()
            .await
            .map_err(|_| "Cannot observe VTXOs")?;
        let balance = session
            .wallet
            .balance()
            .await
            .map_err(|_| "Cannot observe wallet balance")?;
        Ok(ScuttleObservation {
            tip_height: tip.to_u32(),
            last_known_spendable_sats: balance.summary().spendable.to_sat(),
            vtxos: vtxos
                .into_iter()
                .map(|vtxo| ScuttleVtxo {
                    id: vtxo.id().to_string(),
                    amount_sats: vtxo.amount().to_sat(),
                    expiry_height: vtxo.expiry_height().to_u32(),
                    state: match vtxo.state {
                        VtxoState::Spendable => ScuttleVtxoState::Spendable,
                        VtxoState::Locked { .. } => ScuttleVtxoState::Locked,
                        VtxoState::Spent => ScuttleVtxoState::Spent,
                        VtxoState::Exited => ScuttleVtxoState::Exited,
                    },
                })
                .collect(),
        })
    }

    /// Waits for an admitted operation to finish before dropping the wallet.
    pub async fn close(&self) -> Result<(), String> {
        let mut guard = self.wallet.lock().await;
        drop(guard.take());
        Ok(())
    }

    /// Checks the server identity, fee schedule and chain tip without initiating a board.
    pub async fn board_terms(
        &self,
        amount_sats: u64,
        anchor: Option<ScuttleBoardAnchor>,
    ) -> Result<ScuttleBoardTerms, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .refresh_server()
            .await
            .map_err(|_| "Cannot refresh board server")?;
        let info = wallet
            .require_ark_info()
            .await
            .map_err(|_| "Cannot read board server")?;
        let fee = wallet
            .estimate_board_offchain_fee(Amount::from_sat(amount_sats))
            .await
            .map_err(|_| "Cannot estimate board fee")?;
        wallet.chain().invalidate_caches().await;
        let tip = wallet
            .chain()
            .tip_ref()
            .await
            .map_err(|_| "Cannot observe board chain tip")?;
        if let Some(anchor) = anchor {
            let expected = bitcoin::BlockHash::from_str(&anchor.hash)
                .map_err(|_| "Invalid board chain anchor")?;
            if anchor.height > tip.height.to_u32() {
                return Err("Board chain is behind the quote".into());
            }
            let observed = wallet
                .chain()
                .block_ref(anchor.height.into())
                .await
                .map_err(|_| "Cannot observe board chain anchor")?;
            let current = wallet
                .chain()
                .block_ref(tip.height)
                .await
                .map_err(|_| "Cannot recheck board chain tip")?;
            if observed.hash != expected || current.hash != tip.hash {
                return Err("Board chain anchor changed".into());
            }
        }
        Ok(ScuttleBoardTerms {
            server_key: info.server_pubkey.to_string(),
            tip_height: tip.height.to_u32(),
            tip_hash: tip.hash.to_string(),
            required_confirmations: info
                .required_board_confirmations
                .try_into()
                .map_err(|_| "Invalid board confirmation threshold")?,
            gross_sats: fee.gross_amount.to_sat(),
            fee_sats: fee.fee.to_sat(),
            net_sats: fee.net_amount.to_sat(),
        })
    }

    /// Derives and persists a new Scuttle board key; requires server and chain access.
    pub async fn prepare_board(&self) -> Result<ScuttleBoardFunding, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let funding = wallet
            .board()
            .funding_address()
            .await
            .map_err(|_| "Cannot prepare board")?;
        let token = encode_funding(&self.account_id, &funding)?;
        Ok(ScuttleBoardFunding {
            address: funding.address().to_string(),
            expiry_height: funding.expiry_height().to_u32(),
            token,
        })
    }

    /// Admits only a wholly unsigned native-segwit PSBT. The host owns signing and broadcast.
    /// A failure after native admission must be treated as an unknown outcome, not retried.
    pub async fn register_board(
        &self,
        funding_token: String,
        unsigned_psbt: Vec<u8>,
    ) -> Result<ScuttleBoardResult, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let funding = decode_funding(&self.account_id, &funding_token)?;
        let psbt = Psbt::deserialize(&unsigned_psbt).map_err(|_| "Invalid board proposal")?;
        validate_unsigned_board(&psbt, &funding)?;
        let pending = wallet
            .board_psbt(psbt, &funding)
            .await
            .map_err(|_| "Board outcome unknown")?;
        Ok(ScuttleBoardResult {
            funding_txid: pending.funding_tx.compute_txid().to_string(),
            movement_id: pending.movement_id.0,
            amount_sats: pending.amount.to_sat(),
            vtxo_ids: pending.vtxos.iter().map(ToString::to_string).collect(),
        })
    }

    /// Finalizes an externally funded regtest board after confirmation.
    /// Scuttle scans all pending boards here; refuse any wallet with boards
    /// capable of broadcasting funding or approaching exit salvage.
    pub async fn finalize_regtest_board(
        &self,
        funding_txid: String,
    ) -> Result<Option<String>, String> {
        let txid = bitcoin::Txid::from_str(&funding_txid)
            .map_err(|_| "Invalid board funding transaction")?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        if wallet.network().await.map_err(|_| "Cannot read network")? != Network::Regtest {
            return Err("Board finalization restricted to regtest".into());
        }
        wallet
            .refresh_server()
            .await
            .map_err(|_| "Cannot refresh board server")?;
        let info = wallet
            .require_ark_info()
            .await
            .map_err(|_| "Cannot read board server")?;
        wallet.chain().invalidate_caches().await;
        let tip = wallet
            .chain()
            .tip()
            .await
            .map_err(|_| "Cannot read board chain tip")?;
        let Some(height) = wallet
            .chain()
            .tx_confirmed(txid)
            .await
            .map_err(|_| "Cannot read board funding confirmation")?
        else {
            return Ok(None);
        };
        let confirmations = tip
            .checked_blocks_since(height)
            .ok_or("Board confirmation ahead of chain tip")?
            .saturating_add(1);
        if (confirmations as usize) < info.required_board_confirmations {
            return Ok(None);
        }

        let pending = wallet
            .db
            .get_all_wallet_action_checkpoints()
            .await
            .map_err(|_| "Cannot read pending boards")?
            .into_iter()
            .filter_map(|checkpoint| checkpoint.into_board())
            .collect::<Vec<_>>();
        let matches_pending = pending
            .iter()
            .map(|board| board.funding_txid())
            .collect::<Result<Vec<_>, _>>()
            .map_err(|_| "Cannot identify pending board")?
            .into_iter()
            .filter(|funding| *funding == txid)
            .count();
        if matches_pending > 1 {
            return Err("Ambiguous pending board".into());
        }
        if matches_pending == 1 {
            let safe_margin = wallet.config().vtxo_exit_margin.to_u32().saturating_add(12);
            for board in &pending {
                // The public PendingBoard projects the unsigned transaction
                // even for a final PSBT. Inspect the actual action checkpoint.
                if board
                    .to_broadcast()
                    .map_err(|_| "Cannot verify pending funding")?
                    .is_some()
                {
                    return Err("Board wallet has unsupported pending funding".into());
                }
                let vtxo = wallet
                    .get_vtxo_by_id(board.vtxo_id)
                    .await
                    .map_err(|_| "Cannot verify pending board VTXO")?;
                if vtxo.expiry_height().checked_blocks_since(tip).unwrap_or(0) <= safe_margin
                    || wallet.exit_mgr().is_exiting(vtxo.id()).await
                {
                    return Err("Board wallet contains a pending exit or expiring board".into());
                }
            }
            wallet
                .sync_pending_boards()
                .await
                .map_err(|_| "Cannot finalize board")?;
        }
        let spendable = wallet
            .spendable_vtxos()
            .await
            .map_err(|_| "Cannot read finalized VTXOs")?;
        let mut matches = spendable
            .iter()
            .filter(|vtxo| vtxo.chain_anchor().txid == txid);
        match (matches.next(), matches.next()) {
            (Some(vtxo), None) => Ok(Some(vtxo.id().to_string())),
            (None, None) => Ok(None),
            _ => Err("Ambiguous finalized board".into()),
        }
    }

    /// Derives and stores a fresh full Ark mailbox address.
    pub async fn new_ark_address(&self) -> Result<String, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .new_address()
            .await
            .map(|address| address.to_string())
            .map_err(|_| "Cannot create Ark address".into())
    }

    /// A failure after native admission must be treated as an unknown outcome, not retried.
    pub async fn send_ark(&self, address: String, amount_sats: u64) -> Result<u32, String> {
        if amount_sats == 0 {
            return Err("Invalid payment amount".into());
        }
        let destination = match ArkAddressType::from_str(&address) {
            Ok(ArkAddressType::Bark(address)) => address,
            _ => return Err("Invalid Ark address".into()),
        };
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        wallet
            .send_arkoor_payment(&destination, Amount::from_sat(amount_sats))
            .await
            .map(|movement| movement.0)
            .map_err(|_| "Payment outcome unknown".into())
    }
}

#[frb(ignore)]
fn child_account_id(network: Network, seed: &[u8; 64]) -> Result<String, String> {
    let master = Xpriv::new_master(network, seed).map_err(|_| "Invalid child seed")?;
    let public = Xpub::from_priv(&Secp256k1::new(), &master);
    Ok(sha256::Hash::hash(format!("scuttle-account-v1:{network}:{public}").as_bytes()).to_string())
}

#[frb(ignore)]
fn encode_funding(account_id: &str, funding: &bark::BoardFundingAddress) -> Result<String, String> {
    serde_json::to_string(&serde_json::json!({
        "account": account_id,
        "funding": funding,
        "version": 1,
    }))
    .map_err(|_| "Invalid board funding".into())
}

#[frb(ignore)]
fn decode_funding(account_id: &str, token: &str) -> Result<bark::BoardFundingAddress, String> {
    if token.len() > 16_384 {
        return Err("Invalid board funding".into());
    }
    let value: serde_json::Value =
        serde_json::from_str(token).map_err(|_| "Invalid board funding")?;
    let object = value.as_object().ok_or("Invalid board funding")?;
    if object.len() != 3
        || object.get("version").and_then(|v| v.as_u64()) != Some(1)
        || object.get("account").and_then(|v| v.as_str()) != Some(account_id)
        || serde_json::to_string(&value).map_err(|_| "Invalid board funding")? != token
    {
        return Err("Invalid board funding".into());
    }
    let funding: bark::BoardFundingAddress = serde_json::from_value(
        object
            .get("funding")
            .cloned()
            .ok_or("Invalid board funding")?,
    )
    .map_err(|_| "Invalid board funding")?;
    if encode_funding(account_id, &funding)? != token {
        return Err("Invalid board funding".into());
    }
    Ok(funding)
}

#[frb(ignore)]
fn validate_unsigned_board(psbt: &Psbt, funding: &bark::BoardFundingAddress) -> Result<(), String> {
    if psbt.inputs.is_empty()
        || psbt.inputs.len() != psbt.unsigned_tx.input.len()
        || psbt.inputs.iter().any(|input| {
            input.final_script_sig.is_some()
                || input.final_script_witness.is_some()
                || !input.partial_sigs.is_empty()
                || input.tap_key_sig.is_some()
                || !input.tap_script_sigs.is_empty()
                || !input
                    .witness_utxo
                    .as_ref()
                    .is_some_and(|output| output.script_pubkey.is_witness_program())
        })
        || psbt
            .unsigned_tx
            .output
            .iter()
            .filter(|output| output.script_pubkey == funding.address().script_pubkey())
            .count()
            != 1
    {
        return Err("Invalid board proposal".into());
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use bark::onchain::OnchainWalletTrait;
    use bark::onchain::bdk_wallet::{KeychainKind, template::Bip86};
    use bitcoin::absolute::LockTime;
    use bitcoin::hashes::Hash;
    use bitcoin::transaction::Version;
    use bitcoin::{OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, WPubkeyHash, Witness};
    use std::sync::Arc;

    #[test]
    fn recovery_callback_does_not_invent_completeness() {
        assert_eq!(
            map_recovery(bark::RecoveryStatus::NotRun),
            ScuttleRecoveryStatus::NotRun
        );
        assert_eq!(
            map_recovery(bark::RecoveryStatus::InProgress(
                bark::RecoveryReport::default()
            )),
            ScuttleRecoveryStatus::Incomplete
        );
        assert_eq!(
            map_recovery(bark::RecoveryStatus::Completed(
                bark::RecoveryReport::default()
            )),
            ScuttleRecoveryStatus::Complete
        );
        let mut incomplete = bark::RecoveryReport::default();
        incomplete.push_failed(
            bitcoin::OutPoint::new(bitcoin::Txid::all_zeros(), 0).into(),
            None,
        );
        assert_eq!(
            map_recovery(bark::RecoveryStatus::Completed(incomplete)),
            ScuttleRecoveryStatus::Incomplete
        );
    }

    fn funding() -> bark::BoardFundingAddress {
        serde_json::from_value(serde_json::json!({
            "address": "mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn",
            "user_pubkey": "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
            "expiry_height": 500,
        }))
        .unwrap()
    }

    fn proposal(funding: &bark::BoardFundingAddress) -> Psbt {
        let tx = Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input: vec![TxIn {
                previous_output: OutPoint::null(),
                script_sig: ScriptBuf::new(),
                sequence: Sequence::MAX,
                witness: Witness::default(),
            }],
            output: vec![TxOut {
                value: Amount::from_sat(10_000),
                script_pubkey: funding.address().script_pubkey(),
            }],
        };
        let mut psbt = Psbt::from_unsigned_tx(tx).unwrap();
        psbt.inputs[0].witness_utxo = Some(TxOut {
            value: Amount::from_sat(20_000),
            script_pubkey: ScriptBuf::new_p2wpkh(&WPubkeyHash::from_byte_array([1; 20])),
        });
        psbt
    }

    #[test]
    fn funding_token_is_canonical_and_account_bound() {
        let funding = funding();
        let account = child_account_id(Network::Regtest, &[0; 64]).unwrap();
        let other = child_account_id(Network::Regtest, &[1; 64]).unwrap();
        let other_network = child_account_id(Network::Testnet, &[0; 64]).unwrap();
        assert_ne!(account, other);
        assert_ne!(account, other_network);
        let token = encode_funding(&account, &funding).unwrap();
        assert_eq!(decode_funding(&account, &token).unwrap(), funding);
        assert!(decode_funding(&other, &token).is_err());
        assert!(decode_funding(&other_network, &token).is_err());
        assert!(decode_funding(&account, &format!(" {token}")).is_err());
        assert!(decode_funding(&account, &"x".repeat(16_385)).is_err());
    }

    #[test]
    fn full_ark_address_preserves_mailbox_delivery() {
        // Public vector from Scuttle lib/src/address.rs::address_roundtrip.
        let full = "tark1pwh9vsmezqqpharv69q4z8m6x364d5m5prnmcalcalq9pdmzw0y7mpveck4pcfhezqypczkrrj3lkx5ue4qrf4jc7ztpt9htdttmh2judhqnu7aue8p0y9mq47jn9z";
        let ArkAddressType::Bark(address) = ArkAddressType::from_str(full).unwrap() else {
            panic!("expected a Scuttle address");
        };
        assert_eq!(address.to_string(), full);
        assert_eq!(address.delivery().len(), 1);
    }

    #[test]
    fn only_unsigned_native_segwit_psbts_paying_funding_once_are_accepted() {
        let funding = funding();
        let valid = proposal(&funding);
        assert!(validate_unsigned_board(&valid, &funding).is_ok());
        let mut finalised = valid.clone();
        finalised.inputs[0].final_script_witness = Some(Witness::new());
        assert!(validate_unsigned_board(&finalised, &funding).is_err());
        let mut non_witness = valid.clone();
        non_witness.inputs[0].witness_utxo = None;
        assert!(validate_unsigned_board(&non_witness, &funding).is_err());
        let mut duplicate = valid.clone();
        duplicate
            .unsigned_tx
            .output
            .push(duplicate.unsigned_tx.output[0].clone());
        assert!(validate_unsigned_board(&duplicate, &funding).is_err());
        let mut other = valid;
        other.unsigned_tx.output[0].script_pubkey = ScriptBuf::new();
        assert!(validate_unsigned_board(&other, &funding).is_err());
    }

    #[tokio::test]
    async fn close_waits_until_the_admitted_operation_releases_the_wallet() {
        let wallet = Arc::new(ScuttleWallet {
            wallet: Mutex::new(None),
            account_id: "account-a".into(),
        });
        let admitted = wallet.wallet.lock().await;
        let closing = {
            let wallet = Arc::clone(&wallet);
            tokio::spawn(async move { wallet.close().await })
        };
        tokio::task::yield_now().await;
        assert!(!closing.is_finished());
        drop(admitted);
        closing.await.unwrap().unwrap();
    }

    #[tokio::test]
    async fn child_bip86_reserve_reopens_with_the_same_persisted_address() {
        let dir = tempfile::tempdir().unwrap();
        let db = Arc::new(
            bark::persist::sqlite::SqliteClient::open(dir.path().join("db.sqlite")).unwrap(),
        );
        let seed = [0u8; 64];
        let mut onchain = OnchainWallet::load_or_create(Network::Regtest, seed, db.clone())
            .await
            .unwrap();
        assert!(onchain.list_unspent().is_empty());
        let first = OnchainWalletTrait::address(&mut onchain).await.unwrap();

        // bark-ffi 0.8.1 passes this same child seed to Bip86/External.
        let master = Xpriv::new_master(Network::Regtest, &seed).unwrap();
        let mut reference =
            bark::onchain::bdk_wallet::Wallet::create_single(Bip86(master, KeychainKind::External))
                .network(Network::Regtest)
                .create_wallet_no_persist()
                .unwrap();
        assert_eq!(
            first,
            reference
                .reveal_next_address(KeychainKind::External)
                .address
        );
        drop(onchain);

        let reopened = OnchainWallet::load_or_create(Network::Regtest, seed, db)
            .await
            .unwrap();
        assert!(reopened.list_unspent().is_empty());
        assert_eq!(reopened.derivation_index(KeychainKind::External), Some(0));
        assert_eq!(
            reopened.peek_address(KeychainKind::External, 0).address,
            first
        );
    }
}
