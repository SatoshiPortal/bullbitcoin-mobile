use std::collections::{HashMap, HashSet};
use std::str::FromStr;
use std::sync::Arc;

use bark::exit::ExitState;
use bark::onchain::bdk_wallet::{
    Update,
    chain::{BlockId, ConfirmationBlockTime},
};
use bark::onchain::{MakeCpfpFees, OnchainWallet, OnchainWalletTrait, TxBuilderExt};
use bark::persist::BarkPersister;
use bitcoin::address::NetworkUnchecked;
use bitcoin::consensus::{deserialize, serialize};
use bitcoin::{Address, FeeRate, Network, OutPoint, Psbt, Transaction, TxOut, Txid};
use flutter_rust_bridge::frb;

use super::wallet::{ScuttleSession, ScuttleWallet};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ScuttleExitState {
    Start,
    Processing,
    AwaitingDelta,
    Claimable,
    ClaimInProgress,
    Claimed,
    VtxoAlreadySpent,
    VtxoSwept,
    Canceled,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScuttleExit {
    pub vtxo_id: String,
    pub amount_sats: u64,
    pub state: ScuttleExitState,
    pub tip_height: u32,
    pub claimable_height: Option<u32>,
    pub claim_txid: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScuttleReserveCoin {
    pub outpoint: String,
    pub amount_sats: u64,
    pub confirmation_height: u32,
}

/// A snapshot of local BDK state, not proof that the chain view is current.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScuttleExitProgressReview {
    pub account_id: String,
    pub fee_rate_sat_per_vb: u64,
    pub active_exits: Vec<ScuttleExit>,
    pub confirmed_coins: Vec<ScuttleReserveCoin>,
}

pub struct ScuttleExitProgress {
    pub exit: ScuttleExit,
    pub failed: bool,
}

pub struct ScuttleExitFeeEstimate {
    pub exit_broadcast_fee_sats: u64,
    pub claim_fee_sats: u64,
    pub total_fee_sats: u64,
    pub broadcast_rate_sat_per_kwu: u64,
    pub transactions_to_broadcast: u64,
}

pub struct ScuttleExitClaimInput {
    pub vtxo_id: String,
    pub amount_sats: u64,
}

pub struct ScuttleExitClaim {
    pub signed_psbt: Vec<u8>,
    pub raw_transaction: Vec<u8>,
    pub txid: String,
    pub fee_sats: u64,
    pub inputs: Vec<ScuttleExitClaimInput>,
}

pub struct ScuttleMixedClaimReview {
    pub reserve: Vec<ScuttleReserveCoin>,
    pub amount_sats: u64,
    pub fee_sats: u64,
}

pub struct ScuttleMixedClaim {
    pub signed_psbt: Vec<u8>,
    pub raw_transaction: Vec<u8>,
    pub txid: String,
    pub fee_sats: u64,
    pub inputs: Vec<ScuttleExitClaimInput>,
}

pub struct ScuttleExitCpfpCandidate {
    pub exit_txid: String,
    pub child_txid: String,
    pub raw_transaction: Vec<u8>,
    pub fee_sats: u64,
    pub reserve_inputs: Vec<String>,
}

pub struct ScuttleExitCpfpStep {
    pub vtxo_id: String,
    pub parent_txid: String,
}

impl ScuttleWallet {
    /// Reveals and persists a new BIP86 address for the dedicated child reserve.
    pub async fn reserve_address(&self) -> Result<String, String> {
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        let mut onchain = session.onchain.write().await;
        OnchainWalletTrait::address(&mut *onchain)
            .await
            .map(|address| address.to_string())
            .map_err(|_| "Cannot create reserve address".into())
    }

    /// Verifies the locally known confirmed reserve outputs without syncing or broadcasting.
    pub async fn confirmed_reserve(&self) -> Result<Vec<ScuttleReserveCoin>, String> {
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        confirmed_coins(session).await
    }

    /// Verifies one host-journaled reserve funding transaction without running
    /// a wallet sync. This is not an import into BDK or spending authority.
    pub async fn verify_regtest_reserve_funding(
        &self,
        txid: String,
        destination: String,
        amount_sats: u64,
    ) -> Result<Option<ScuttleReserveCoin>, String> {
        self.regtest_reserve_funding(txid, destination, amount_sats, false)
            .await
    }

    /// Imports only the initial, confirmed, host-journaled reserve funding.
    /// Repeated imports of the same funding are safe; no transaction is broadcast.
    pub async fn import_initial_regtest_reserve_funding(
        &self,
        txid: String,
        destination: String,
        amount_sats: u64,
    ) -> Result<Option<ScuttleReserveCoin>, String> {
        self.regtest_reserve_funding(txid, destination, amount_sats, true)
            .await
    }

    #[frb(ignore)]
    async fn regtest_reserve_funding(
        &self,
        txid: String,
        destination: String,
        amount_sats: u64,
        import: bool,
    ) -> Result<Option<ScuttleReserveCoin>, String> {
        let txid = Txid::from_str(&txid).map_err(|_| "Invalid reserve funding transaction")?;
        let destination = parse_destination(&destination, Network::Regtest)?;
        if amount_sats == 0 {
            return Err("Invalid reserve funding amount".into());
        }
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        if session.network().await.map_err(|_| "Cannot read network")? != Network::Regtest {
            return Err("Reserve funding verification restricted to regtest".into());
        }
        let script = destination.script_pubkey();
        if !session.onchain.read().await.inner.is_mine(script.clone()) {
            return Err("Funding destination does not belong to this reserve".into());
        }
        let chain = session.chain();
        let Some(block) = chain
            .tx_status(txid)
            .await
            .map_err(|_| "Cannot observe reserve funding")?
            .confirmed_in()
        else {
            return Ok(None);
        };
        let tx = chain
            .get_tx(&txid)
            .await
            .map_err(|_| "Cannot read reserve funding transaction")?
            .ok_or("Missing reserve funding transaction")?;
        if tx.compute_txid() != txid {
            return Err("Reserve funding transaction identity changed".into());
        }
        let mut outputs = tx
            .output
            .iter()
            .enumerate()
            .filter(|(_, output)| output.script_pubkey == script);
        let (index, output) = outputs.next().ok_or("Missing reserve funding output")?;
        if outputs.next().is_some() || output.value.to_sat() != amount_sats {
            return Err("Reserve funding does not match the review".into());
        }
        let point = OutPoint::new(
            txid,
            index.try_into().map_err(|_| "Invalid reserve output")?,
        );
        let height = block.height.to_u32();
        verify_confirmed_inputs(session, &[(point, output, Some(height))]).await?;
        if import {
            let mut onchain = session.onchain.write().await;
            if onchain
                .list_transactions()
                .iter()
                .any(|known| known.compute_txid() != txid)
            {
                return Err("Reserve already has other transactions".into());
            }
            persist_confirmed_reserve_transaction(session, &mut onchain, tx, height, block.hash)
                .await?;
        }
        Ok(Some(ScuttleReserveCoin {
            outpoint: point.to_string(),
            amount_sats,
            confirmation_height: height,
        }))
    }

    /// Capture a local review; the host must bind and persist it with its own admission.
    pub async fn exit_progress_review(
        &self,
        fee_rate_sat_per_vb: u64,
    ) -> Result<ScuttleExitProgressReview, String> {
        parse_rate(Some(fee_rate_sat_per_vb))?;
        let mut guard = self.wallet.lock().await;
        let session = guard.as_mut().ok_or("Wallet closed")?;
        let review = progress_review(session, &self.account_id, fee_rate_sat_per_vb).await?;
        session.progress_review = Some(review.clone());
        Ok(review)
    }

    /// Compare the entire local review under admission, then progress at its exact rate.
    /// Scuttle may use any confirmed reserve UTXOs and provides no hard fee cap.
    /// An error after native admission must be treated as an unknown outcome.
    pub async fn progress_exits(
        &self,
        review: ScuttleExitProgressReview,
    ) -> Result<Option<Vec<ScuttleExitProgress>>, String> {
        let rate = parse_rate(Some(review.fee_rate_sat_per_vb))?.ok_or("Invalid fee rate")?;
        let mut guard = self.wallet.lock().await;
        let session = guard.as_mut().ok_or("Wallet closed")?;
        let current =
            progress_review(session, &self.account_id, review.fee_rate_sat_per_vb).await?;
        if !review_matches(&current, &review, session.progress_review.as_ref()) {
            return Err("Stale exit review".into());
        }
        session.progress_review = None;
        let statuses = session
            .exit_mgr()
            .progress_exits_with_cpfp(&session.wallet, Some(rate))
            .await
            .map_err(|_| "Exit progress outcome unknown")?;
        let Some(statuses) = statuses else {
            return Ok(None);
        };
        let mut result = Vec::with_capacity(statuses.len());
        for status in statuses {
            let vtxo = session
                .get_vtxo_by_id(status.vtxo_id)
                .await
                .map_err(|_| "Exit progress outcome unknown")?;
            result.push(ScuttleExitProgress {
                exit: project_exit(
                    status.vtxo_id.to_string(),
                    vtxo.amount().to_sat(),
                    &status.state,
                ),
                failed: status.error.is_some(),
            });
        }
        Ok(Some(result))
    }

    /// Lists due first-attempt children without signing or broadcasting.
    pub async fn due_regtest_exit_cpfp(
        &self,
        vtxo_ids: Vec<String>,
    ) -> Result<Vec<ScuttleExitCpfpStep>, String> {
        let selection = parse_selection(&vtxo_ids)?;
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        if session.network().await.map_err(|_| "Cannot read network")? != Network::Regtest {
            return Err("Exit CPFP restricted to regtest".into());
        }
        Ok(session
            .exit_mgr()
            .exits_needing_cpfp()
            .await
            .into_iter()
            .filter(|request| {
                request.rbf_requirement.is_none() && selection.contains(&request.vtxo_id.to_point())
            })
            .map(|request| ScuttleExitCpfpStep {
                vtxo_id: request.vtxo_id.to_string(),
                parent_txid: request.exit_tx.compute_txid().to_string(),
            })
            .collect())
    }

    /// Builds a non-replacement child for one reviewed regtest exit without
    /// broadcasting it. The host must durably admit the exact bytes and debit
    /// its cumulative exit budget before any later delivery.
    pub async fn prepare_regtest_exit_cpfp(
        &self,
        vtxo_id: String,
        exit_txid: String,
        fee_rate_sat_per_vb: u64,
        remaining_fee_sats: u64,
    ) -> Result<ScuttleExitCpfpCandidate, String> {
        let selection = parse_selection(std::slice::from_ref(&vtxo_id))?;
        let expected_parent = Txid::from_str(&exit_txid).map_err(|_| "Invalid exit transaction")?;
        let rate = parse_rate(Some(fee_rate_sat_per_vb))?.ok_or("Invalid fee rate")?;
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        if session.network().await.map_err(|_| "Cannot read network")? != Network::Regtest {
            return Err("CPFP preparation restricted to regtest".into());
        }
        let request = session
            .exit_mgr()
            .exits_needing_cpfp()
            .await
            .into_iter()
            .find(|request| {
                selection.contains(&request.vtxo_id.to_point())
                    && request.exit_tx.compute_txid() == expected_parent
            })
            .ok_or("No matching exit step needs CPFP")?;
        if request.rbf_requirement.is_some() {
            return Err("CPFP replacement requires a new review".into());
        }
        let mut onchain = session.onchain.write().await;
        let reserve = onchain.list_unspent();
        let verified = reserve
            .iter()
            .filter_map(|coin| {
                coin.chain_position
                    .confirmation_height_upper_bound()
                    .map(|height| (coin.outpoint, &coin.txout, Some(height)))
            })
            .collect::<Vec<_>>();
        if verified.is_empty() {
            return Err("No confirmed reserve input".into());
        }
        verify_confirmed_inputs(session, &verified).await?;
        let child = onchain
            .make_signed_p2a_cpfp(&request.exit_tx, MakeCpfpFees::Effective(rate))
            .await
            .map_err(|_| "Cannot prepare exit CPFP")?;
        let coins = verified
            .into_iter()
            .map(|(point, output, _)| (point, output))
            .collect();
        let (fee, mut reserve_inputs) = verify_cpfp_candidate(
            &request.exit_tx,
            &child,
            &coins,
            remaining_fee_sats,
            |change| onchain.inner.is_mine(change.script_pubkey.clone()),
        )?;
        // Preserve any derived change address before the bytes leave this
        // method, but do not record the child as broadcast.
        if let Some(changes) = onchain.inner.staged() {
            session
                .db
                .store_bdk_wallet_changeset(changes)
                .await
                .map_err(|_| "Cannot persist CPFP change address")?;
            let _ = onchain.inner.take_staged();
        }
        reserve_inputs.sort_unstable();
        Ok(ScuttleExitCpfpCandidate {
            exit_txid,
            child_txid: child.compute_txid().to_string(),
            raw_transaction: serialize(&child),
            fee_sats: fee,
            reserve_inputs: reserve_inputs.iter().map(ToString::to_string).collect(),
        })
    }

    /// Delivers only the exact child previously admitted by the host. A
    /// response error is not proof that the package failed to reach the chain.
    pub async fn deliver_regtest_exit_cpfp(
        &self,
        vtxo_id: String,
        exit_txid: String,
        child_txid: String,
        raw_transaction: Vec<u8>,
        admitted_fee_sats: u64,
    ) -> Result<(), String> {
        let selection = parse_selection(&[vtxo_id])?;
        let parent_id = Txid::from_str(&exit_txid).map_err(|_| "Invalid exit transaction")?;
        let child_id = Txid::from_str(&child_txid).map_err(|_| "Invalid exit child")?;
        let child: Transaction = deserialize(&raw_transaction).map_err(|_| "Invalid exit child")?;
        if child.compute_txid() != child_id || serialize(&child) != raw_transaction {
            return Err("Exit child does not match admission".into());
        }
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        if session.network().await.map_err(|_| "Cannot read network")? != Network::Regtest {
            return Err("CPFP delivery restricted to regtest".into());
        }
        let chain = session.chain();
        chain.invalidate_caches().await;
        let status = chain
            .tx_status(child_id)
            .await
            .map_err(|_| "Cannot observe exit child")?;
        if status.is_known() {
            let observed = chain
                .get_tx(&child_id)
                .await
                .map_err(|_| "Cannot verify exit child")?;
            return if observed.as_ref() == Some(&child) {
                Ok(())
            } else {
                Err("Observed exit child does not match admission".into())
            };
        }
        let request = session
            .exit_mgr()
            .exits_needing_cpfp()
            .await
            .into_iter()
            .find(|request| {
                selection.contains(&request.vtxo_id.to_point())
                    && request.exit_tx.compute_txid() == parent_id
            })
            .ok_or("No matching exit step needs CPFP")?;
        if request.rbf_requirement.is_some() {
            return Err("CPFP replacement requires a new review".into());
        }
        let onchain = session.onchain.read().await;
        let reserve = onchain.list_unspent();
        let verified = reserve
            .iter()
            .filter_map(|coin| {
                coin.chain_position
                    .confirmation_height_upper_bound()
                    .map(|height| (coin.outpoint, &coin.txout, Some(height)))
            })
            .collect::<Vec<_>>();
        let coins = verified
            .iter()
            .map(|&(point, txout, _)| (point, txout))
            .collect();
        let (fee, selected) = verify_cpfp_candidate(
            &request.exit_tx,
            &child,
            &coins,
            admitted_fee_sats,
            |change| onchain.inner.is_mine(change.script_pubkey.clone()),
        )?;
        if fee != admitted_fee_sats {
            return Err("Exit child fee does not match admission".into());
        }
        let prevouts = verified
            .into_iter()
            .filter(|(point, _, _)| selected.contains(point))
            .collect::<Vec<_>>();
        verify_confirmed_inputs(session, &prevouts).await?;
        chain
            .broadcast_package(&[request.exit_tx, child])
            .await
            .map_err(|_| "Exit package delivery outcome unknown".into())
    }

    /// Imports confirmed change from the host's exact journaled child. This
    /// updates only the reserve graph and never runs the native wallet sync.
    pub async fn import_confirmed_regtest_cpfp_change(
        &self,
        child_txid: String,
        raw_transaction: Vec<u8>,
    ) -> Result<Option<ScuttleReserveCoin>, String> {
        let txid = Txid::from_str(&child_txid).map_err(|_| "Invalid exit child")?;
        let tx: Transaction = deserialize(&raw_transaction).map_err(|_| "Invalid exit child")?;
        if tx.compute_txid() != txid || serialize(&tx) != raw_transaction || tx.output.len() != 1 {
            return Err("Exit child does not match admission".into());
        }
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        if session.network().await.map_err(|_| "Cannot read network")? != Network::Regtest {
            return Err("CPFP change import restricted to regtest".into());
        }
        let chain = session.chain();
        chain.invalidate_caches().await;
        let Some(block) = chain
            .tx_status(txid)
            .await
            .map_err(|_| "Cannot observe exit child")?
            .confirmed_in()
        else {
            return Ok(None);
        };
        let mut reserve = session.onchain.write().await;
        if !reserve.inner.is_mine(tx.output[0].script_pubkey.clone())
            || !tx.input.iter().any(|input| {
                let point = input.previous_output;
                reserve
                    .inner
                    .get_tx(point.txid)
                    .and_then(|known| known.tx_node.tx.output.get(point.vout as usize).cloned())
                    .is_some_and(|prevout| reserve.inner.is_mine(prevout.script_pubkey))
            })
        {
            return Err("Exit child is not a reserve spend".into());
        }
        let coin = ScuttleReserveCoin {
            outpoint: OutPoint::new(txid, 0).to_string(),
            amount_sats: tx.output[0].value.to_sat(),
            confirmation_height: block.height.to_u32(),
        };
        persist_confirmed_reserve_transaction(
            session,
            &mut reserve,
            tx,
            block.height.to_u32(),
            block.hash,
        )
        .await?;
        Ok(Some(coin))
    }

    /// Returns persisted live and terminal exits. A missing VTXO fails the whole observation.
    pub async fn exit_inventory(&self) -> Result<Vec<ScuttleExit>, String> {
        self.exits(false).await
    }

    /// Advances exit states from chain observations, then returns the inventory.
    /// Never broadcasts, rebroadcasts, evicts or creates a CPFP: every
    /// transaction is delivered through the host's admission journal.
    pub async fn refresh_exit_inventory(&self) -> Result<Vec<ScuttleExit>, String> {
        self.exits(true).await
    }

    #[frb(ignore)]
    async fn exits(&self, refresh: bool) -> Result<Vec<ScuttleExit>, String> {
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        if refresh {
            wallet
                .exit_mgr()
                .progress_exits_without_broadcast(wallet)
                .await
                .map_err(|_| "Cannot refresh exits")?;
        }
        let statuses = wallet
            .exit_mgr()
            .list_all(false, false)
            .await
            .map_err(|_| "Cannot observe exits")?;
        let mut result = Vec::with_capacity(statuses.len());
        for status in statuses {
            let vtxo = wallet
                .get_vtxo_by_id(status.vtxo_id)
                .await
                .map_err(|_| "Cannot observe exits")?;
            result.push(project_exit(
                status.vtxo_id.to_string(),
                vtxo.amount().to_sat(),
                &status.state,
            ));
        }
        Ok(result)
    }

    /// Estimates the selected exits at an optional exact integer sats/vB rate.
    pub async fn estimate_exit(
        &self,
        vtxo_ids: Vec<String>,
        fee_rate_sat_per_vb: Option<u64>,
        destination: Option<String>,
    ) -> Result<ScuttleExitFeeEstimate, String> {
        let points = parse_selection(&vtxo_ids)?;
        let rate = parse_rate(fee_rate_sat_per_vb)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let address = match destination {
            Some(address) => Some(parse_destination(
                &address,
                wallet.network().await.map_err(|_| "Cannot estimate exit")?,
            )?),
            None => None,
        };
        let ids = points.into_iter().map(Into::into).collect::<Vec<_>>();
        let estimate = wallet
            .exit_mgr()
            .estimate_emergency_exit_fee(&ids, wallet, rate, address, None)
            .await
            .map_err(|_| "Cannot estimate exit")?;
        Ok(ScuttleExitFeeEstimate {
            exit_broadcast_fee_sats: estimate.exit_broadcast_fee.to_sat(),
            claim_fee_sats: estimate.claim_fee.to_sat(),
            total_fee_sats: estimate.total().to_sat(),
            broadcast_rate_sat_per_kwu: estimate.fee_rate.to_sat_per_kwu(),
            transactions_to_broadcast: estimate.txs_to_broadcast as u64,
        })
    }

    /// Starts only the selected currently spendable VTXOs; an error after admission is unknown.
    pub async fn start_exit(&self, vtxo_ids: Vec<String>) -> Result<(), String> {
        let points = parse_selection(&vtxo_ids)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let chain = wallet.chain();
        chain.invalidate_caches().await;
        let tip = chain
            .tip_ref()
            .await
            .map_err(|_| "Cannot read exit chain")?;
        let spendable = wallet
            .spendable_vtxos()
            .await
            .map_err(|_| "Cannot select exits")?;
        let mut selected = Vec::with_capacity(points.len());
        for point in points {
            let vtxo = spendable
                .iter()
                .find(|vtxo| vtxo.id().to_point() == point)
                .ok_or("Invalid exit selection")?;
            if vtxo.expiry_height() <= tip.height || wallet.exit_mgr().is_exiting(vtxo.id()).await {
                return Err("Invalid exit selection".into());
            }
            let full = wallet
                .get_full_vtxo(vtxo.id())
                .await
                .map_err(|_| "Cannot verify selected exit")?;
            wallet
                .validate_vtxo(&full)
                .await
                .map_err(|_| "Cannot verify selected exit funding")?;
            let anchor = chain
                .tx_status(full.chain_anchor().txid)
                .await
                .map_err(|_| "Cannot verify selected exit funding")?
                .confirmed_in()
                .ok_or("Selected exit funding is not confirmed")?;
            if anchor.height > tip.height
                || chain
                    .block_ref(anchor.height)
                    .await
                    .map_err(|_| "Cannot verify selected exit funding block")?
                    != anchor
            {
                return Err("Selected exit funding is not on the active chain".into());
            }
            selected.push(vtxo.vtxo.clone());
        }
        if chain
            .block_ref(tip.height)
            .await
            .map_err(|_| "Cannot verify exit chain")?
            != tip
        {
            return Err("Exit chain changed during validation".into());
        }
        wallet
            .exit_mgr()
            .start_exit_for_vtxos(&selected)
            .await
            .map_err(|_| "Exit outcome unknown")?;
        for vtxo in &selected {
            if !wallet.exit_mgr().is_exiting(vtxo.id()).await {
                return Err("Exit outcome unknown".into());
            }
        }
        Ok(())
    }

    /// Signs only selected claimable exit inputs. Does not broadcast or use reserve coins.
    pub async fn prepare_exit_claim(
        &self,
        vtxo_ids: Vec<String>,
        destination: String,
        max_fee_sats: u64,
    ) -> Result<ScuttleExitClaim, String> {
        let points = parse_selection(&vtxo_ids)?;
        let guard = self.wallet.lock().await;
        let wallet = guard.as_ref().ok_or("Wallet closed")?;
        let network = wallet.network().await.map_err(|_| "Cannot prepare claim")?;
        let address = parse_destination(&destination, network)?;
        let claimable = wallet.exit_mgr().list_claimable().await;
        let mut selected = Vec::with_capacity(points.len());
        let mut evidence = Vec::with_capacity(points.len());
        for point in &points {
            let exit = claimable
                .iter()
                .find(|exit| exit.id().to_point() == *point)
                .ok_or("Invalid claim selection")?;
            selected.push(exit.clone());
            evidence.push(ScuttleExitClaimInput {
                vtxo_id: exit.id().to_string(),
                amount_sats: exit.amount().to_sat(),
            });
        }
        let psbt = wallet
            .exit_mgr()
            .drain_exits(&selected, wallet, address.clone(), None)
            .await
            .map_err(|_| "Cannot prepare claim")?;
        let fee = validate_claim(&psbt, &points, &evidence, &address, max_fee_sats)?;
        let tx = psbt
            .clone()
            .extract_tx()
            .map_err(|_| "Cannot verify claim")?;
        Ok(ScuttleExitClaim {
            signed_psbt: psbt.serialize(),
            raw_transaction: serialize(&tx),
            txid: tx.compute_txid().to_string(),
            fee_sats: fee,
            inputs: evidence,
        })
    }

    /// Reviews a single sweep of all claimable exits and the entire reserve,
    /// without signing or broadcasting.
    pub async fn review_regtest_mixed_claim(
        &self,
        vtxo_ids: Vec<String>,
        destination: String,
        fee_rate_sat_per_vb: u64,
        max_fee_sats: u64,
    ) -> Result<ScuttleMixedClaimReview, String> {
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        let reserve = confirmed_coins(session).await?;
        let draft = build_mixed_claim(
            session,
            &vtxo_ids,
            &reserve,
            &destination,
            fee_rate_sat_per_vb,
            max_fee_sats,
            false,
        )
        .await?;
        let fee = draft.fee().map_err(|_| "Cannot verify claim fee")?;
        let amount = draft.unsigned_tx.output[0]
            .value
            .checked_add(fee)
            .ok_or("Invalid claim amount")?;
        Ok(ScuttleMixedClaimReview {
            reserve,
            amount_sats: amount.to_sat(),
            fee_sats: fee.to_sat(),
        })
    }

    /// Signing is separate from review. The caller must first admit the quote
    /// exclusively and must record the resulting bytes before delivering them.
    pub async fn prepare_regtest_mixed_claim(
        &self,
        vtxo_ids: Vec<String>,
        destination: String,
        reserve_outpoints: Vec<String>,
        fee_rate_sat_per_vb: u64,
        expected_amount_sats: u64,
        expected_fee_sats: u64,
    ) -> Result<ScuttleMixedClaim, String> {
        let reviewed = parse_selection(&reserve_outpoints)?;
        let guard = self.wallet.lock().await;
        let session = guard.as_ref().ok_or("Wallet closed")?;
        let reserve = confirmed_coins(session).await?;
        if reserve.len() != reviewed.len()
            || reserve.iter().any(|coin| {
                OutPoint::from_str(&coin.outpoint).map_or(true, |point| !reviewed.contains(&point))
            })
        {
            return Err("Reserve no longer matches the claim review".into());
        }
        let psbt = build_mixed_claim(
            session,
            &vtxo_ids,
            &reserve,
            &destination,
            fee_rate_sat_per_vb,
            expected_fee_sats,
            true,
        )
        .await?;
        let fee = psbt.fee().map_err(|_| "Cannot verify claim fee")?;
        if fee.to_sat() != expected_fee_sats
            || psbt.unsigned_tx.output[0]
                .value
                .checked_add(fee)
                .is_none_or(|amount| amount.to_sat() != expected_amount_sats)
        {
            return Err("Claim no longer matches the reviewed amounts".into());
        }
        let inputs = psbt
            .unsigned_tx
            .input
            .iter()
            .zip(&psbt.inputs)
            .map(|(txin, input)| {
                let prevout = input.witness_utxo.as_ref().ok_or("Missing claim input")?;
                Ok(ScuttleExitClaimInput {
                    vtxo_id: txin.previous_output.to_string(),
                    amount_sats: prevout.value.to_sat(),
                })
            })
            .collect::<Result<Vec<_>, &str>>()?;
        let tx = psbt
            .clone()
            .extract_tx()
            .map_err(|_| "Cannot verify claim")?;
        Ok(ScuttleMixedClaim {
            signed_psbt: psbt.serialize(),
            raw_transaction: serialize(&tx),
            txid: tx.compute_txid().to_string(),
            fee_sats: fee.to_sat(),
            inputs,
        })
    }
}

#[frb(ignore)]
async fn persist_confirmed_reserve_transaction(
    session: &ScuttleSession,
    onchain: &mut OnchainWallet,
    tx: Transaction,
    height: u32,
    hash: bitcoin::BlockHash,
) -> Result<(), String> {
    let chain = session.chain();
    let block = chain
        .block(hash)
        .await
        .map_err(|_| "Cannot read reserve block")?
        .ok_or("Missing reserve block")?;
    if block.block_hash() != hash || !block.check_merkle_root() || !block.txdata.contains(&tx) {
        return Err("Reserve transaction not found in the confirmed block".into());
    }
    let previous = onchain.inner.latest_checkpoint();
    let previous_block = chain
        .block_ref(previous.height().into())
        .await
        .map_err(|_| "Cannot verify reserve checkpoint")?;
    let canonical = chain
        .block_ref(height.into())
        .await
        .map_err(|_| "Cannot recheck reserve block")?;
    if canonical.hash != hash || previous_block.hash != previous.hash() {
        return Err("Reserve chain changed during transaction import".into());
    }
    let block_id = BlockId { height, hash };
    let txid = tx.compute_txid();
    let mut update = Update {
        chain: Some(previous.insert(block_id)),
        ..Default::default()
    };
    update.tx_update.txs.push(Arc::new(tx));
    update.tx_update.anchors.insert((
        ConfirmationBlockTime {
            block_id,
            confirmation_time: u64::from(block.header.time),
        },
        txid,
    ));
    onchain
        .inner
        .apply_update(update)
        .map_err(|_| "Cannot apply reserve graph update")?;
    if let Some(changes) = onchain.inner.staged() {
        session
            .db
            .store_bdk_wallet_changeset(changes)
            .await
            .map_err(|_| "Cannot persist reserve graph update")?;
        let _ = onchain.inner.take_staged();
    }
    Ok(())
}

#[frb(ignore)]
fn verify_cpfp_candidate(
    parent: &Transaction,
    child: &Transaction,
    reserve: &HashMap<OutPoint, &TxOut>,
    remaining_fee_sats: u64,
    owns_change: impl FnOnce(&TxOut) -> bool,
) -> Result<(u64, Vec<OutPoint>), String> {
    if child.output.len() != 1 || !owns_change(&child.output[0]) {
        return Err("Exit CPFP must return change to the reserve".into());
    }
    let parent_id = parent.compute_txid();
    let p2a = bitcoin::ScriptBuf::new_p2a();
    let mut anchor = false;
    let mut selected = HashSet::new();
    let mut total = 0u64;
    for input in &child.input {
        let point = input.previous_output;
        let prevout = if point.txid == parent_id {
            let output = parent
                .output
                .get(point.vout as usize)
                .ok_or("Missing exit anchor")?;
            if anchor || output.script_pubkey != p2a {
                return Err("Invalid exit anchor".into());
            }
            anchor = true;
            output
        } else {
            if !selected.insert(point) || input.witness.is_empty() {
                return Err("Invalid signed reserve input".into());
            }
            reserve
                .get(&point)
                .copied()
                .ok_or("Unreviewed reserve input")?
        };
        total = total
            .checked_add(prevout.value.to_sat())
            .ok_or("Invalid CPFP input value")?;
    }
    if !anchor || selected.is_empty() {
        return Err("Exit CPFP requires an anchor and reserve input".into());
    }
    let fee = total
        .checked_sub(child.output[0].value.to_sat())
        .ok_or("Invalid CPFP fee")?;
    if fee == 0 || fee > remaining_fee_sats {
        return Err("CPFP fee exceeds remaining reviewed budget".into());
    }
    Ok((fee, selected.into_iter().collect()))
}

/// The caller owns admission, freshness, and exclusive reservation of both input sets.
/// This function neither synchronizes nor records or broadcasts the resulting transaction.
#[frb(ignore)]
async fn build_mixed_claim(
    session: &ScuttleSession,
    exit_ids: &[String],
    reserve: &[ScuttleReserveCoin],
    destination: &str,
    fee_rate_sat_per_vb: u64,
    max_fee_sats: u64,
    sign: bool,
) -> Result<Psbt, String> {
    let points = parse_selection(exit_ids)?;
    if reserve.is_empty() {
        return Err("Invalid reserve selection".into());
    }
    let rate = parse_rate(Some(fee_rate_sat_per_vb))?.ok_or("Invalid fee rate")?;
    let network = session
        .network()
        .await
        .map_err(|_| "Cannot prepare claim")?;
    if network != Network::Regtest {
        return Err("Mixed claim restricted to regtest".into());
    }
    let address = parse_destination(destination, network)?;
    let live = session
        .exit_mgr()
        .list_live(false, false)
        .await
        .map_err(|_| "Cannot verify active exits")?;
    if live.len() != points.len()
        || live.iter().any(|status| {
            !matches!(status.state, ExitState::Claimable(..))
                || !points.contains(&status.vtxo_id.to_point())
        })
    {
        return Err("Other active exits may need the reserve".into());
    }
    let claimable = session.exit_mgr().list_claimable().await;
    let mut selected = Vec::with_capacity(points.len());
    let mut expected = HashMap::new();
    for point in points {
        let exit = claimable
            .iter()
            .find(|exit| exit.id().to_point() == point)
            .ok_or("Invalid claim selection")?;
        if expected.insert(point, exit.amount().to_sat()).is_some() {
            return Err("Invalid claim selection".into());
        }
        selected.push(exit);
    }

    let mut onchain = session.onchain.write().await;
    let available = onchain.list_unspent();
    // Wait for any unconfirmed change instead of silently leaving it behind.
    if available.len() != reserve.len() {
        return Err("Reserve selection does not cover the wallet".into());
    }
    let mut reserve_points = Vec::with_capacity(reserve.len());
    for coin in reserve {
        let point = OutPoint::from_str(&coin.outpoint).map_err(|_| "Invalid reserve selection")?;
        let output = available
            .iter()
            .find(|output| output.outpoint == point)
            .ok_or("Invalid reserve selection")?;
        if output.txout.value.to_sat() != coin.amount_sats
            || output.chain_position.confirmation_height_upper_bound()
                != Some(coin.confirmation_height)
            || expected.insert(point, coin.amount_sats).is_some()
        {
            return Err("Invalid reserve selection".into());
        }
        reserve_points.push(point);
    }
    let mut builder = onchain.build_tx();
    builder.manually_selected_only();
    builder
        .add_utxos(&reserve_points)
        .map_err(|_| "Cannot prepare claim")?;
    builder
        .add_exit_claim_inputs(&session.wallet, &selected)
        .await
        .map_err(|_| "Cannot prepare claim")?;
    builder.drain_to(address.script_pubkey()).fee_rate(rate);
    let mut psbt = builder.finish().map_err(|_| "Cannot prepare claim")?;
    validate_claim_transaction_stage(&psbt, &expected, &address, max_fee_sats, false)?;
    let inputs = psbt
        .unsigned_tx
        .input
        .iter()
        .zip(&psbt.inputs)
        .map(|(txin, input)| {
            input
                .witness_utxo
                .as_ref()
                .map(|output| (txin.previous_output, output, None))
                .ok_or("Missing claim input evidence")
        })
        .collect::<Result<Vec<_>, _>>()?;
    verify_confirmed_inputs(session, &inputs).await?;
    if !sign {
        return Ok(psbt);
    }
    let unsigned = psbt.unsigned_tx.clone();
    session
        .exit_mgr()
        .sign_exit_claim_inputs(&mut psbt, &session.wallet)
        .await
        .map_err(|_| "Cannot sign claim")?;
    for (txin, input) in psbt.unsigned_tx.input.iter().zip(&psbt.inputs) {
        if !reserve_points.contains(&txin.previous_output)
            && input
                .final_script_witness
                .as_ref()
                .is_none_or(|witness| witness.is_empty())
        {
            return Err("Cannot sign claim".into());
        }
    }
    let psbt = OnchainWalletTrait::sign_psbt(&mut *onchain, psbt)
        .await
        .map_err(|_| "Cannot sign claim")?;
    if psbt.unsigned_tx != unsigned {
        return Err("Cannot verify claim".into());
    }
    validate_claim_transaction(&psbt, &expected, &address, max_fee_sats)?;
    Ok(psbt)
}

/// Verify the specific reviewed inputs on-chain without syncing the native
/// wallet (which may rebroadcast unrelated transactions).
#[frb(ignore)]
#[allow(deprecated)]
async fn verify_confirmed_inputs(
    session: &ScuttleSession,
    inputs: &[(OutPoint, &TxOut, Option<u32>)],
) -> Result<(), String> {
    let chain = session.chain();
    chain.invalidate_caches().await;
    let tip = chain
        .tip_ref()
        .await
        .map_err(|_| "Cannot read claim chain")?;
    for &(point, expected, expected_height) in inputs {
        let block = chain
            .tx_status(point.txid)
            .await
            .map_err(|_| "Cannot read claim input status")?
            .confirmed_in()
            .ok_or("Claim input is not confirmed")?;
        if expected_height.is_some_and(|height| height != block.height.to_u32())
            || block.height > tip.height
            || chain
                .block_ref(block.height)
                .await
                .map_err(|_| "Cannot verify claim input block")?
                != block
        {
            return Err("Claim input is not on the active chain".into());
        }
        let tx = chain
            .get_tx(&point.txid)
            .await
            .map_err(|_| "Cannot read claim input transaction")?
            .ok_or("Missing claim input transaction")?;
        let output = tx.output.get(point.vout as usize);
        if tx.compute_txid() != point.txid || output != Some(expected) {
            return Err("Claim input does not match the chain".into());
        }
        if chain
            .txs_spending_inputs([point], block.height)
            .await
            .map_err(|_| "Cannot verify claim input spend status")?
            .get(&point)
            .is_some()
        {
            return Err("Claim input is already spent".into());
        }
    }
    if chain
        .block_ref(tip.height)
        .await
        .map_err(|_| "Cannot verify claim chain")?
        != tip
    {
        return Err("Claim chain changed during input verification".into());
    }
    Ok(())
}

#[frb(ignore)]
fn review_matches(
    current: &ScuttleExitProgressReview,
    reviewed: &ScuttleExitProgressReview,
    stored: Option<&ScuttleExitProgressReview>,
) -> bool {
    current == reviewed && stored == Some(reviewed) && !current.active_exits.is_empty()
}

#[frb(ignore)]
async fn confirmed_coins(session: &ScuttleSession) -> Result<Vec<ScuttleReserveCoin>, String> {
    let onchain = session.onchain.read().await;
    let unspent = onchain.list_unspent();
    let mut inputs = Vec::new();
    let mut coins: Vec<_> = unspent
        .iter()
        .filter_map(|output| {
            output
                .chain_position
                .confirmation_height_upper_bound()
                .map(|height| {
                    inputs.push((output.outpoint, &output.txout, Some(height)));
                    ScuttleReserveCoin {
                        outpoint: output.outpoint.to_string(),
                        amount_sats: output.txout.value.to_sat(),
                        confirmation_height: height,
                    }
                })
        })
        .collect();
    if !inputs.is_empty() {
        verify_confirmed_inputs(session, &inputs).await?;
    }
    coins.sort_by(|a, b| a.outpoint.cmp(&b.outpoint));
    Ok(coins)
}

#[frb(ignore)]
async fn progress_review(
    session: &ScuttleSession,
    account_id: &str,
    fee_rate_sat_per_vb: u64,
) -> Result<ScuttleExitProgressReview, String> {
    let statuses = session
        .exit_mgr()
        .list_live(false, false)
        .await
        .map_err(|_| "Cannot observe exits")?;
    let mut active_exits = Vec::with_capacity(statuses.len());
    for status in statuses {
        let vtxo = session
            .get_vtxo_by_id(status.vtxo_id)
            .await
            .map_err(|_| "Cannot observe exits")?;
        active_exits.push(project_exit(
            status.vtxo_id.to_string(),
            vtxo.amount().to_sat(),
            &status.state,
        ));
    }
    active_exits.sort_by(|a, b| a.vtxo_id.cmp(&b.vtxo_id));
    Ok(ScuttleExitProgressReview {
        account_id: account_id.to_owned(),
        fee_rate_sat_per_vb,
        active_exits,
        confirmed_coins: confirmed_coins(session).await?,
    })
}

#[frb(ignore)]
fn parse_selection(ids: &[String]) -> Result<Vec<OutPoint>, String> {
    if ids.is_empty() {
        return Err("Invalid exit selection".into());
    }
    let mut seen = HashSet::with_capacity(ids.len());
    ids.iter()
        .map(|id| {
            let point = OutPoint::from_str(id).map_err(|_| "Invalid exit selection")?;
            if !seen.insert(point) {
                return Err("Invalid exit selection".into());
            }
            Ok(point)
        })
        .collect()
}

#[frb(ignore)]
fn parse_rate(rate: Option<u64>) -> Result<Option<FeeRate>, String> {
    rate.map(|value| {
        if value == 0 {
            return Err("Invalid fee rate".into());
        }
        FeeRate::from_sat_per_vb(value).ok_or_else(|| "Invalid fee rate".into())
    })
    .transpose()
}

#[frb(ignore)]
fn parse_destination(address: &str, network: Network) -> Result<Address, String> {
    let address =
        Address::<NetworkUnchecked>::from_str(address).map_err(|_| "Invalid claim destination")?;
    address
        .require_network(network)
        .map_err(|_| "Invalid claim destination".into())
}

#[frb(ignore)]
fn project_exit(vtxo_id: String, amount_sats: u64, state: &ExitState) -> ScuttleExit {
    let (kind, tip, txid) = match state {
        ExitState::Start(s) => (ScuttleExitState::Start, s.tip_height, None),
        ExitState::Processing(s) => (ScuttleExitState::Processing, s.tip_height, None),
        ExitState::AwaitingDelta(s) => (ScuttleExitState::AwaitingDelta, s.tip_height, None),
        ExitState::Claimable(s) => (ScuttleExitState::Claimable, s.tip_height, None),
        ExitState::ClaimInProgress(s) => (
            ScuttleExitState::ClaimInProgress,
            s.tip_height,
            Some(s.claim_txid.to_string()),
        ),
        ExitState::Claimed(s) => (
            ScuttleExitState::Claimed,
            s.tip_height,
            Some(s.txid.to_string()),
        ),
        ExitState::VtxoAlreadySpent(s) => (ScuttleExitState::VtxoAlreadySpent, s.tip_height, None),
        ExitState::VtxoSwept(s) => (ScuttleExitState::VtxoSwept, s.tip_height, None),
        ExitState::Canceled(s) => (ScuttleExitState::Canceled, s.tip_height, None),
    };
    ScuttleExit {
        vtxo_id,
        amount_sats,
        state: kind,
        tip_height: tip.to_u32(),
        claimable_height: state.claimable_height().map(|height| height.to_u32()),
        claim_txid: txid,
    }
}

#[frb(ignore)]
fn validate_claim(
    psbt: &Psbt,
    points: &[OutPoint],
    evidence: &[ScuttleExitClaimInput],
    address: &Address,
    max_fee_sats: u64,
) -> Result<u64, String> {
    if points.len() != evidence.len() {
        return Err("Cannot verify claim".into());
    }
    let expected: HashMap<OutPoint, u64> = points
        .iter()
        .copied()
        .zip(evidence.iter().map(|input| input.amount_sats))
        .collect();
    if expected.len() != points.len() {
        return Err("Cannot verify claim".into());
    }
    validate_claim_transaction(psbt, &expected, address, max_fee_sats)
}

/// Verifies the exact input set and amounts, whether funded by exits alone
/// or by exits and a separately admitted reserve selection.
fn validate_claim_transaction(
    psbt: &Psbt,
    expected: &HashMap<OutPoint, u64>,
    address: &Address,
    max_fee_sats: u64,
) -> Result<u64, String> {
    validate_claim_transaction_stage(psbt, expected, address, max_fee_sats, true)
}

fn validate_claim_transaction_stage(
    psbt: &Psbt,
    expected: &HashMap<OutPoint, u64>,
    address: &Address,
    max_fee_sats: u64,
    require_finalized: bool,
) -> Result<u64, String> {
    if expected.is_empty()
        || psbt.inputs.len() != expected.len()
        || psbt.unsigned_tx.input.len() != expected.len()
        || psbt.unsigned_tx.output.len() != 1
        || psbt.unsigned_tx.output[0].script_pubkey != address.script_pubkey()
    {
        return Err("Cannot verify claim".into());
    }
    let mut observed = HashSet::new();
    for (txin, input) in psbt.unsigned_tx.input.iter().zip(&psbt.inputs) {
        let Some(amount) = expected.get(&txin.previous_output) else {
            return Err("Cannot verify claim".into());
        };
        if !observed.insert(txin.previous_output)
            || (require_finalized
                && input
                    .final_script_witness
                    .as_ref()
                    .is_none_or(|witness| witness.is_empty()))
            || input
                .witness_utxo
                .as_ref()
                .is_none_or(|utxo| utxo.value.to_sat() != *amount)
        {
            return Err("Cannot verify claim".into());
        }
    }
    let fee = psbt.fee().map_err(|_| "Cannot verify claim")?.to_sat();
    if fee > max_fee_sats {
        return Err("Claim fee exceeds limit".into());
    }
    Ok(fee)
}

#[cfg(test)]
mod tests {
    use super::*;
    use bitcoin::absolute::LockTime;
    use bitcoin::transaction::Version;
    use bitcoin::{Amount, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Witness};

    #[test]
    fn cpfp_verifies_actual_fee_and_rejects_unreviewed_spends() {
        let anchor_output = TxOut {
            value: Amount::from_sat(10),
            script_pubkey: ScriptBuf::new_p2a(),
        };
        let parent = Transaction {
            version: Version(3),
            lock_time: LockTime::ZERO,
            input: vec![],
            output: vec![anchor_output],
        };
        let coin = OutPoint::new(Txid::from_str(&"01".repeat(32)).unwrap(), 0);
        let reserve_output = TxOut {
            value: Amount::from_sat(1_000),
            script_pubkey: ScriptBuf::from_bytes(vec![0x51]),
        };
        let reserve = HashMap::from([(coin, &reserve_output)]);
        let input = |point, witness| TxIn {
            previous_output: point,
            script_sig: ScriptBuf::new(),
            sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
            witness,
        };
        let child = Transaction {
            version: Version(3),
            lock_time: LockTime::ZERO,
            input: vec![
                input(OutPoint::new(parent.compute_txid(), 0), Witness::new()),
                input(coin, Witness::from_slice(&[[1_u8; 64]])),
            ],
            output: vec![TxOut {
                value: Amount::from_sat(800),
                script_pubkey: reserve_output.script_pubkey.clone(),
            }],
        };
        let check = |tx: &Transaction, budget| {
            verify_cpfp_candidate(&parent, tx, &reserve, budget, |change| {
                change.script_pubkey == reserve_output.script_pubkey
            })
        };
        assert_eq!(check(&child, 210).unwrap(), (210, vec![coin]));
        assert!(check(&child, 209).is_err());

        let mut invalid = child.clone();
        invalid.input[1].previous_output.vout = 1;
        assert!(check(&invalid, 210).is_err());
        let mut invalid = child.clone();
        invalid.input.push(child.input[1].clone());
        assert!(check(&invalid, 2_000).is_err());
        let mut invalid = child.clone();
        invalid.input[1].witness = Witness::new();
        assert!(check(&invalid, 210).is_err());
        let mut invalid = child.clone();
        invalid.output[0].script_pubkey = ScriptBuf::from_bytes(vec![0x52]);
        assert!(check(&invalid, 210).is_err());
        let mut invalid = child;
        invalid.output.push(invalid.output[0].clone());
        assert!(check(&invalid, 210).is_err());
    }

    #[test]
    fn selection_and_rates_reject_ambiguity() {
        let id = format!("{}:0", "01".repeat(32));
        assert_eq!(parse_selection(std::slice::from_ref(&id)).unwrap().len(), 1);
        assert!(parse_selection(&[]).is_err());
        assert!(parse_selection(&[id.clone(), id]).is_err());
        assert!(parse_selection(&["bad".into()]).is_err());
        assert!(parse_rate(Some(0)).is_err());
        assert!(parse_rate(Some(u64::MAX)).is_err());
        assert_eq!(parse_rate(Some(2)).unwrap().unwrap().to_sat_per_kwu(), 500);
    }

    #[test]
    fn reviewed_exit_set_and_confirmed_reserve_must_both_remain_unchanged() {
        let exit = ScuttleExit {
            vtxo_id: "test:0".into(),
            amount_sats: 1_000,
            state: ScuttleExitState::Start,
            tip_height: 100,
            claimable_height: None,
            claim_txid: None,
        };
        let coin = ScuttleReserveCoin {
            outpoint: "coin:0".into(),
            amount_sats: 500,
            confirmation_height: 90,
        };
        let current = ScuttleExitProgressReview {
            account_id: "account".into(),
            fee_rate_sat_per_vb: 2,
            active_exits: vec![exit],
            confirmed_coins: vec![coin],
        };
        assert!(review_matches(&current, &current, Some(&current)));
        assert!(!review_matches(&current, &current, None));
        let mut stale = current.clone();
        stale.confirmed_coins[0].amount_sats += 1;
        assert!(!review_matches(&current, &stale, Some(&current)));
        stale = current.clone();
        stale.active_exits.clear();
        assert!(!review_matches(&current, &stale, Some(&current)));
        stale = current.clone();
        stale.fee_rate_sat_per_vb += 1;
        assert!(!review_matches(&current, &stale, Some(&current)));
        stale = current.clone();
        stale.account_id.push('x');
        assert!(!review_matches(&current, &stale, Some(&current)));
        // Even if a caller mutates the rate and the fresh snapshot agrees,
        // it was not the stored review.
        stale = current.clone();
        stale.fee_rate_sat_per_vb += 1;
        assert!(!review_matches(&stale, &stale, Some(&current)));
    }

    #[test]
    fn start_and_canceled_states_are_distinct() {
        let start: ExitState =
            serde_json::from_value(serde_json::json!({"type":"start","tip_height":12})).unwrap();
        let canceled: ExitState =
            serde_json::from_value(serde_json::json!({"type":"canceled","tip_height":13})).unwrap();
        let start = project_exit("id".into(), 500, &start);
        let canceled = project_exit("id".into(), 500, &canceled);
        assert_eq!(start.state, ScuttleExitState::Start);
        assert_eq!(start.tip_height, 12);
        assert_eq!(start.claimable_height, None);
        assert_eq!(canceled.state, ScuttleExitState::Canceled);
        assert_eq!(canceled.tip_height, 13);
    }

    #[test]
    fn claim_proof_rejects_mixed_unfinalized_and_excess_fee() {
        let address = Address::<NetworkUnchecked>::from_str("mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn")
            .unwrap()
            .assume_checked();
        let point = OutPoint::from_str(&format!("{}:0", "01".repeat(32))).unwrap();
        let transaction = Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input: vec![TxIn {
                previous_output: point,
                script_sig: ScriptBuf::new(),
                sequence: Sequence::MAX,
                witness: Witness::new(),
            }],
            output: vec![TxOut {
                value: Amount::from_sat(9_900),
                script_pubkey: address.script_pubkey(),
            }],
        };
        let mut psbt = Psbt::from_unsigned_tx(transaction).unwrap();
        psbt.inputs[0].witness_utxo = Some(TxOut {
            value: Amount::from_sat(10_000),
            script_pubkey: ScriptBuf::new(),
        });
        psbt.inputs[0].final_script_witness = Some(Witness::from_slice(&[&[1u8][..]]));
        let evidence = vec![ScuttleExitClaimInput {
            vtxo_id: point.to_string(),
            amount_sats: 10_000,
        }];
        assert_eq!(
            validate_claim(&psbt, &[point], &evidence, &address, 100).unwrap(),
            100
        );
        assert!(validate_claim(&psbt, &[point], &evidence, &address, 99).is_err());
        let mut unsigned = psbt.clone();
        unsigned.inputs[0].final_script_witness = None;
        assert!(validate_claim(&unsigned, &[point], &evidence, &address, 100).is_err());
        let mut mixed = psbt;
        mixed.unsigned_tx.input[0].previous_output = OutPoint::null();
        assert!(validate_claim(&mixed, &[point], &evidence, &address, 100).is_err());
    }

    #[test]
    fn mixed_claim_proof_requires_every_reviewed_input_and_one_destination() {
        let address = Address::<NetworkUnchecked>::from_str("mipcBbFg9gMiCh81Kj8tqqdgoZub1ZJRfn")
            .unwrap()
            .assume_checked();
        let exit = OutPoint::from_str(&format!("{}:0", "01".repeat(32))).unwrap();
        let reserve = OutPoint::from_str(&format!("{}:1", "02".repeat(32))).unwrap();
        let expected = HashMap::from([(exit, 49_670), (reserve, 2_000)]);
        let tx = Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input: [reserve, exit]
                .into_iter()
                .map(|previous_output| TxIn {
                    previous_output,
                    script_sig: ScriptBuf::new(),
                    sequence: Sequence::from_consensus(1),
                    witness: Witness::new(),
                })
                .collect(),
            output: vec![TxOut {
                value: Amount::from_sat(51_500),
                script_pubkey: address.script_pubkey(),
            }],
        };
        let mut psbt = Psbt::from_unsigned_tx(tx).unwrap();
        for (input, amount) in psbt.inputs.iter_mut().zip([2_000, 49_670]) {
            input.witness_utxo = Some(TxOut {
                value: Amount::from_sat(amount),
                script_pubkey: ScriptBuf::new(),
            });
            input.final_script_witness = Some(Witness::from_slice(&[&[1u8][..]]));
        }
        let mut unsigned = psbt.clone();
        for input in &mut unsigned.inputs {
            input.final_script_witness = None;
        }
        assert_eq!(
            validate_claim_transaction_stage(&unsigned, &expected, &address, 170, false),
            Ok(170)
        );
        assert!(
            validate_claim_transaction_stage(&unsigned, &expected, &address, 169, false).is_err()
        );
        assert!(validate_claim_transaction(&unsigned, &expected, &address, 170).is_err());
        unsigned.unsigned_tx.output[0].script_pubkey = ScriptBuf::new();
        assert!(
            validate_claim_transaction_stage(&unsigned, &expected, &address, 170, false).is_err()
        );
        assert_eq!(
            validate_claim_transaction(&psbt, &expected, &address, 170),
            Ok(170)
        );
        assert!(validate_claim_transaction(&psbt, &expected, &address, 169).is_err());
        assert!(
            validate_claim_transaction(&psbt, &HashMap::from([(exit, 49_670)]), &address, 170)
                .is_err()
        );
        let mut duplicate = psbt.clone();
        duplicate.unsigned_tx.input[0].previous_output = exit;
        assert!(validate_claim_transaction(&duplicate, &expected, &address, 170).is_err());
        psbt.unsigned_tx.output[0].script_pubkey = ScriptBuf::new();
        assert!(validate_claim_transaction(&psbt, &expected, &address, 170).is_err());
    }
}
