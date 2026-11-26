use crate::util::{ensure_boltz_url, HTTP_TIMEOUT};

use super::{
    btc_ln::BtcLnSwap,
    chain_swap::ChainSwap,
    error::BoltzError,
    lbtc_ln::LbtcLnSwap,
    secrets::{KeyPair, SwapMasterKey},
    swap_status::SwapStatus,
    types::{Chain, ChainSwapDirection, Network, PreImage, SwapType},
};
use boltz_client::util::secrets::Preimage as BoltzPreimage;
use boltz_client::{
    swaps::boltz::{
        BoltzApiClientV2, ChainSwapDetails, ClaimDetails, CreateReverseResponse,
        CreateSubmarineResponse, RefundDetails, SwapRestoreResponse, SwapRestoreType, SwapTree,
    },
    Bolt11Invoice, DisplayHex, PublicKey,
};
use std::str::FromStr;

fn swap_restore_type_to_swap_type(restore_type: SwapRestoreType) -> SwapType {
    match restore_type {
        SwapRestoreType::Reverse => SwapType::Reverse,
        SwapRestoreType::Submarine => SwapType::Submarine,
        SwapRestoreType::Chain => SwapType::Chain,
    }
}

struct LnRestoreDetails {
    tree: SwapTree,
    key_index: u64,
    lockup_address: String,
    server_public_key: String,
    timeout_block_height: u32,
    blinding_key: Option<String>,
    amount: Option<u64>,
    preimage_hash: Option<String>,
}

/// The client's side of a restored LN swap: boltz returns it under
/// `refund_details` for submarine swaps (the client refunds a submarine,
/// never claims it) and under `claim_details` for reverse swaps.
fn ln_restore_details(
    restore_response: &SwapRestoreResponse,
    swap_name: &str,
) -> Result<LnRestoreDetails, BoltzError> {
    match restore_response.swap_type {
        SwapRestoreType::Submarine => {
            let d = restore_response.refund_details.as_ref().ok_or_else(|| {
                BoltzError::new(
                    "Restore".to_string(),
                    format!(
                        "Refund details required for submarine swap {} ({})",
                        restore_response.id, swap_name
                    ),
                )
            })?;
            Ok(LnRestoreDetails {
                tree: d.tree.clone(),
                key_index: d.key_index as u64,
                lockup_address: d.lockup_address.clone(),
                server_public_key: d.server_public_key.clone(),
                timeout_block_height: d.timeout_block_height,
                blinding_key: d.blinding_key.clone(),
                amount: None,
                preimage_hash: None,
            })
        }
        SwapRestoreType::Reverse => {
            let d = restore_response.claim_details.as_ref().ok_or_else(|| {
                BoltzError::new(
                    "Restore".to_string(),
                    format!(
                        "Claim details required for reverse swap {} ({})",
                        restore_response.id, swap_name
                    ),
                )
            })?;
            Ok(LnRestoreDetails {
                tree: d.tree.clone(),
                key_index: d.key_index as u64,
                lockup_address: d.lockup_address.clone(),
                server_public_key: d.server_public_key.clone(),
                timeout_block_height: d.timeout_block_height,
                blinding_key: d.blinding_key.clone(),
                amount: d.amount,
                preimage_hash: Some(d.preimage_hash.clone()),
            })
        }
        SwapRestoreType::Chain => Err(BoltzError::new(
            "Restore".to_string(),
            format!("Chain swap type not supported for {}", swap_name),
        )),
    }
}

fn empty_preimage() -> PreImage {
    PreImage::new(String::new(), String::new(), String::new())
}

/// Sat amount of a BOLT11 invoice, when there is one and it parses.
fn invoice_amount_sats(invoice: &Option<String>) -> Option<u64> {
    invoice
        .as_ref()
        .and_then(|i| Bolt11Invoice::from_str(i).ok())
        .and_then(|i| i.amount_milli_satoshis())
        .map(|msat| msat / 1000)
}

/// Hash-only preimage and receive amount recovered from a submarine swap's
/// invoice. Boltz's refund_details carry neither, and the refund — the only
/// client-side action on a submarine swap — needs neither: both are
/// display/reconciliation data, so an absent or unparseable invoice (e.g.
/// BOLT12) degrades to empty values instead of making the swap unrestorable.
fn submarine_preimage_and_amount(invoice: &Option<String>) -> (PreImage, u64) {
    let preimage = invoice
        .as_ref()
        .and_then(|i| PreImage::from_invoice_str(i).ok())
        .unwrap_or_else(empty_preimage);
    (preimage, invoice_amount_sats(invoice).unwrap_or(0))
}

/// Rebuilds a reverse swap's preimage, which is derived from the claim key
/// at creation time; a mismatch with the hash boltz stored means this key
/// cannot claim the (legacy, pre-derived-preimage) swap.
fn verified_reverse_preimage(
    boltz_preimage: BoltzPreimage,
    expected_hash: &str,
    swap_id: &str,
) -> Result<PreImage, BoltzError> {
    if boltz_preimage.sha256.to_string() != expected_hash {
        return Err(BoltzError::new(
            "Restore".to_string(),
            format!(
                "Preimage hash mismatch for {}: expected {}, got {}",
                swap_id, expected_hash, boltz_preimage.sha256
            ),
        ));
    }
    Ok(PreImage::from(boltz_preimage))
}

fn validate_restored_hashlock(
    actual_hash: &str,
    preimage: &PreImage,
    swap_id: &str,
) -> Result<(), BoltzError> {
    if !preimage.hash160.is_empty() && actual_hash != preimage.hash160 {
        return Err(BoltzError::new(
            "Restore".to_string(),
            format!(
                "Hashlock mismatch for {}: expected {}, got {}",
                swap_id, preimage.hash160, actual_hash
            ),
        ));
    }
    Ok(())
}

async fn restore_swaps(
    swap_master_key: SwapMasterKey,
    boltz_url: String,
) -> Result<Vec<SwapRestoreResponse>, BoltzError> {
    let boltz_url = ensure_boltz_url(
        &boltz_url,
        swap_master_key.network != super::types::Network::Mainnet,
    )
    .map_err(|e| BoltzError::new("Network".to_string(), e))?;
    let boltz_client = BoltzApiClientV2::new(boltz_url, Some(HTTP_TIMEOUT));
    let xpub = swap_master_key.xpub.clone();
    // xpub is the swap-account key (m/44/0/0/0); tell boltz to derive
    // `xpub/{index}` directly ("m") instead of re-applying its default path.
    let restore_responses = boltz_client
        .post_swap_restore(&xpub, Some("m".to_string()), Some(100))
        .await
        .map_err(|e| BoltzError::new("Restore".to_string(), e.to_string()))?;

    Ok(restore_responses)
}

/// Lightweight view of a restorable swap, taken straight from the restore
/// response — enough to list swaps and show status without rebuilding the full
/// swap object (which is only needed to actually rescue one).
pub struct RestoredSwapSummary {
    pub id: String,
    pub kind: SwapType,
    /// Raw boltz status string (e.g. "transaction.claimed"); mapped app-side.
    pub status: String,
    pub created_at: u64,
    pub from: String,
    pub to: String,
    pub amount: u64,
    /// True when on-chain funds are locked and not yet claimed/refunded — i.e.
    /// the swap can still be rescued (claimed or refunded). False for swaps that
    /// never locked up (e.g. expired-unfunded) or are already resolved.
    pub recoverable: bool,
}

/// One restore POST returning a summary per swap (id, kind, status, amount).
pub async fn restore_swap_summaries(
    swap_master_key: SwapMasterKey,
    boltz_url: String,
) -> Result<Vec<RestoredSwapSummary>, BoltzError> {
    let boltz_url = ensure_boltz_url(
        &boltz_url,
        swap_master_key.network != super::types::Network::Mainnet,
    )
    .map_err(|e| BoltzError::new("Network".to_string(), e))?;
    let boltz_client = BoltzApiClientV2::new(boltz_url, Some(HTTP_TIMEOUT));
    let xpub = swap_master_key.xpub.clone();
    let responses = boltz_client
        .post_swap_restore(&xpub, Some("m".to_string()), Some(100))
        .await
        .map_err(|e| BoltzError::new("Restore".to_string(), e.to_string()))?;
    Ok(responses
        .into_iter()
        .map(|r| {
            // Submarine refund_details carry no amount; fall back to the
            // invoice so the UI can show one.
            let amount = r
                .claim_details
                .as_ref()
                .and_then(|d| d.amount)
                .or_else(|| invoice_amount_sats(&r.invoice))
                .unwrap_or(0);
            // Funds are on-chain if boltz recorded a lockup transaction for
            // either side; the swap is resolved once it's been claimed/refunded.
            let has_lockup = r
                .claim_details
                .as_ref()
                .map(|d| d.transaction.is_some())
                .unwrap_or(false)
                || r.refund_details
                    .as_ref()
                    .map(|d| d.transaction.is_some())
                    .unwrap_or(false);
            // Unknown statuses stay recoverable: erring towards offering a
            // rescue is safe (the refund/claim just finds the lockup spent),
            // hiding a rescuable swap is not.
            let resolved = SwapStatus::from_json_string(r.status.clone())
                .map(|s| s.is_resolved())
                .unwrap_or(false);
            RestoredSwapSummary {
                id: r.id,
                kind: swap_restore_type_to_swap_type(r.swap_type),
                status: r.status,
                created_at: r.created_at,
                from: r.from,
                to: r.to,
                amount,
                recoverable: has_lockup && !resolved,
            }
        })
        .collect())
}

/// Highest swap-key derivation index boltz has on record for this wallet's
/// swap xpub. Returns -1 when boltz knows of no swaps. Use it on seed recovery
/// to continue the swap index after the last one already used.
pub async fn restore_swap_index(
    swap_master_key: SwapMasterKey,
    boltz_url: String,
) -> Result<i64, BoltzError> {
    let boltz_url = ensure_boltz_url(
        &boltz_url,
        swap_master_key.network != super::types::Network::Mainnet,
    )
    .map_err(|e| BoltzError::new("Network".to_string(), e))?;
    let boltz_client = BoltzApiClientV2::new(boltz_url, Some(HTTP_TIMEOUT));
    let xpub = swap_master_key.xpub.clone();
    let resp = boltz_client
        .post_swap_restore_index(&xpub, Some("m".to_string()), Some(100))
        .await
        .map_err(|e| BoltzError::new("RestoreIndex".to_string(), e.to_string()))?;
    Ok(resp.index)
}

/// A swap the restore scan returned but could not rebuild into a usable
/// swap object (e.g. a legacy reverse swap whose preimage was not derived
/// from the swap key). Its funds, if any, are NOT covered by the returned
/// swaps — callers must surface these to the user rather than treat the
/// restore as complete.
pub struct SkippedRestoreSwap {
    pub id: String,
    pub error: String,
}

pub struct RestoredBtcLnSwaps {
    pub swaps: Vec<BtcLnSwap>,
    pub skipped: Vec<SkippedRestoreSwap>,
}

pub struct RestoredLbtcLnSwaps {
    pub swaps: Vec<LbtcLnSwap>,
    pub skipped: Vec<SkippedRestoreSwap>,
}

pub struct RestoredChainSwaps {
    pub swaps: Vec<ChainSwap>,
    pub skipped: Vec<SkippedRestoreSwap>,
}

/// Collects rebuilt swaps from a restore response batch. `rebuild` returns
/// `None` for swaps that are not this restorer's kind; one unrebuildable swap
/// does not abort the batch — it is reported in the skipped list instead.
fn collect_restored<T>(
    responses: Vec<SwapRestoreResponse>,
    mut rebuild: impl FnMut(SwapRestoreResponse) -> Option<Result<T, BoltzError>>,
) -> (Vec<T>, Vec<SkippedRestoreSwap>) {
    let mut swaps = Vec::new();
    let mut skipped = Vec::new();
    for response in responses {
        let id = response.id.clone();
        match rebuild(response) {
            Some(Ok(swap)) => swaps.push(swap),
            Some(Err(e)) => skipped.push(SkippedRestoreSwap {
                id,
                error: format!("{}: {}", e.kind, e.message),
            }),
            None => {}
        }
    }
    (swaps, skipped)
}

pub async fn restore_ln_btc_swaps(
    swap_master_key: SwapMasterKey,
    electrum_url: String,
    boltz_url: String,
) -> Result<RestoredBtcLnSwaps, BoltzError> {
    let restore_responses = restore_swaps(swap_master_key.clone(), boltz_url.clone()).await?;

    let (swaps, skipped) = collect_restored(restore_responses, |response| {
        let is_ln = matches!(
            &response.swap_type,
            SwapRestoreType::Submarine | SwapRestoreType::Reverse
        );
        if !is_ln || response.from != "BTC" || response.to != "BTC" {
            return None;
        }
        let invoice = response.invoice.clone();
        Some(restore_to_btc_ln_swap(
            response,
            swap_master_key.clone(),
            electrum_url.clone(),
            boltz_url.clone(),
            invoice,
        ))
    });
    Ok(RestoredBtcLnSwaps { swaps, skipped })
}

pub async fn restore_ln_lbtc_swaps(
    swap_master_key: SwapMasterKey,
    electrum_url: String,
    boltz_url: String,
) -> Result<RestoredLbtcLnSwaps, BoltzError> {
    let restore_responses = restore_swaps(swap_master_key.clone(), boltz_url.clone()).await?;

    let (swaps, skipped) = collect_restored(restore_responses, |response| {
        let is_ln = matches!(
            &response.swap_type,
            SwapRestoreType::Submarine | SwapRestoreType::Reverse
        );
        // L-BTC Lightning swaps: from="L-BTC" to="BTC" (submarine) or
        // from="BTC" to="L-BTC" (reverse).
        let is_lbtc = (response.from == "L-BTC" && response.to == "BTC")
            || (response.from == "BTC" && response.to == "L-BTC");
        if !is_ln || !is_lbtc {
            return None;
        }
        let invoice = response.invoice.clone();
        Some(restore_to_lbtc_ln_swap(
            response,
            swap_master_key.clone(),
            electrum_url.clone(),
            boltz_url.clone(),
            invoice,
        ))
    });
    Ok(RestoredLbtcLnSwaps { swaps, skipped })
}

pub async fn restore_chain_swaps(
    swap_master_key: SwapMasterKey,
    btc_electrum_url: String,
    lbtc_electrum_url: String,
    boltz_url: String,
) -> Result<RestoredChainSwaps, BoltzError> {
    let restore_responses = restore_swaps(swap_master_key.clone(), boltz_url.clone()).await?;

    let (swaps, skipped) = collect_restored(restore_responses, |response| {
        if !matches!(&response.swap_type, SwapRestoreType::Chain) {
            return None;
        }
        Some(restore_to_chain_swap(
            response,
            swap_master_key.clone(),
            btc_electrum_url.clone(),
            lbtc_electrum_url.clone(),
            boltz_url.clone(),
        ))
    });
    Ok(RestoredChainSwaps { swaps, skipped })
}

fn infer_network(from: &str, to: &str, network: Network) -> Result<Chain, BoltzError> {
    // The on-chain side of an LN swap is whichever leg is L-BTC.
    Ok(if from == "L-BTC" || to == "L-BTC" {
        network.liquid()
    } else {
        network.bitcoin()
    })
}

fn infer_chain_swap_direction(from: &str, to: &str) -> Result<ChainSwapDirection, BoltzError> {
    match (from, to) {
        ("BTC", "L-BTC") => Ok(ChainSwapDirection::BtcToLbtc),
        ("L-BTC", "BTC") => Ok(ChainSwapDirection::LbtcToBtc),
        _ => Err(BoltzError::new(
            "Direction".to_string(),
            format!("Cannot infer direction from from={}, to={}", from, to),
        )),
    }
}

fn claim_details_to_chain_swap_details(
    details: &ClaimDetails,
) -> Result<ChainSwapDetails, BoltzError> {
    let server_pubkey = PublicKey::from_str(&details.server_public_key)
        .map_err(|e| BoltzError::new("PublicKey".to_string(), e.to_string()))?;

    Ok(ChainSwapDetails {
        swap_tree: details.tree.clone(),
        lockup_address: details.lockup_address.clone(),
        server_public_key: server_pubkey,
        timeout_block_height: details.timeout_block_height,
        amount: details.amount.unwrap_or(0),
        blinding_key: details.blinding_key.clone(),
        refund_address: None,
        claim_address: None,
        bip21: None,
    })
}

fn refund_details_to_chain_swap_details(
    details: &RefundDetails,
) -> Result<ChainSwapDetails, BoltzError> {
    let server_pubkey = PublicKey::from_str(&details.server_public_key)
        .map_err(|e| BoltzError::new("PublicKey".to_string(), e.to_string()))?;

    Ok(ChainSwapDetails {
        swap_tree: details.tree.clone(),
        lockup_address: details.lockup_address.clone(),
        server_public_key: server_pubkey,
        timeout_block_height: details.timeout_block_height,
        amount: 0,
        blinding_key: details.blinding_key.clone(),
        refund_address: None,
        claim_address: None,
        bip21: None,
    })
}

fn restore_to_btc_ln_swap(
    restore_response: SwapRestoreResponse,
    swap_master_key: SwapMasterKey,
    electrum_url: String,
    boltz_url: String,
    invoice: Option<String>,
) -> Result<BtcLnSwap, BoltzError> {
    let network = infer_network(
        &restore_response.from,
        &restore_response.to,
        swap_master_key.network,
    )?;
    let swap_master_key_inner: boltz_client::util::secrets::SwapMasterKey =
        swap_master_key.try_into()?;

    let details = ln_restore_details(&restore_response, "BtcLnSwap")?;

    let key_index = details.key_index;
    let kps = swap_master_key_inner.derive_swapkey(key_index)?;
    let keys = KeyPair::from(kps);

    let server_public_key = PublicKey::from_str(&details.server_public_key)
        .map_err(|e| BoltzError::new("PublicKey".to_string(), e.to_string()))?;
    let our_pubkey = PublicKey {
        inner: kps.public_key(),
        compressed: true,
    };

    let swap_type = swap_restore_type_to_swap_type(restore_response.swap_type.clone());
    let (preimage, amount) = match restore_response.swap_type {
        SwapRestoreType::Submarine => submarine_preimage_and_amount(&invoice),
        SwapRestoreType::Reverse => {
            let preimage_hash = details.preimage_hash.clone().unwrap_or_default();
            let preimage = verified_reverse_preimage(
                BoltzPreimage::from_swap_key(&kps),
                &preimage_hash,
                &restore_response.id,
            )?;
            (preimage, details.amount.unwrap_or(0))
        }
        SwapRestoreType::Chain => {
            return Err(BoltzError::new(
                "Restore".to_string(),
                "Chain swap type not supported for BtcLnSwap".to_string(),
            ));
        }
    };

    let swap_script = match restore_response.swap_type {
        SwapRestoreType::Submarine => {
            let create_swap_response = CreateSubmarineResponse {
                id: restore_response.id.clone(),
                accept_zero_conf: false,
                address: details.lockup_address.clone(),
                bip21: String::new(),
                claim_public_key: server_public_key,
                expected_amount: amount,
                referral_id: None,
                swap_tree: details.tree.clone(),
                timeout_block_height: details.timeout_block_height as u64,
                blinding_key: None,
            };
            boltz_client::BtcSwapScript::submarine_from_swap_resp(
                &create_swap_response,
                kps.public_key().into(),
            )
        }
        SwapRestoreType::Reverse => {
            let create_reverse_response = CreateReverseResponse {
                id: restore_response.id.clone(),
                lockup_address: details.lockup_address.clone(),
                invoice: invoice.clone(),
                timeout_block_height: details.timeout_block_height,
                onchain_amount: amount,
                swap_tree: details.tree.clone(),
                refund_public_key: server_public_key,
                blinding_key: None,
            };
            boltz_client::BtcSwapScript::reverse_from_swap_resp(
                &create_reverse_response,
                our_pubkey,
            )
        }
        SwapRestoreType::Chain => {
            return Err(BoltzError::new(
                "Restore".to_string(),
                "Chain swap type not supported for BtcLnSwap".to_string(),
            ));
        }
    }
    .map_err(|e| BoltzError::new("SwapScript".to_string(), e.to_string()))?;
    validate_restored_hashlock(
        &swap_script.hashlock.to_string(),
        &preimage,
        &restore_response.id,
    )?;

    Ok(BtcLnSwap::new_with_expected_onchain_amount(
        restore_response.id,
        swap_type,
        network,
        keys,
        key_index,
        preimage,
        swap_script.into(),
        invoice.unwrap_or_default(),
        details.lockup_address.clone(),
        amount,
        electrum_url,
        boltz_url,
        None,
        (matches!(&restore_response.swap_type, SwapRestoreType::Reverse) && amount > 0)
            .then_some(amount),
    ))
}

fn restore_to_lbtc_ln_swap(
    restore_response: SwapRestoreResponse,
    swap_master_key: SwapMasterKey,
    electrum_url: String,
    boltz_url: String,
    invoice: Option<String>,
) -> Result<LbtcLnSwap, BoltzError> {
    let network = infer_network(
        &restore_response.from,
        &restore_response.to,
        swap_master_key.network,
    )?;
    let swap_master_key_inner: boltz_client::util::secrets::SwapMasterKey =
        swap_master_key.try_into()?;

    let details = ln_restore_details(&restore_response, "LbtcLnSwap")?;

    let key_index = details.key_index;
    let kps = swap_master_key_inner.derive_liquid_swapkey(key_index)?;
    let keys = KeyPair::from(kps);

    let server_public_key = PublicKey::from_str(&details.server_public_key)
        .map_err(|e| BoltzError::new("PublicKey".to_string(), e.to_string()))?;
    let our_pubkey = PublicKey {
        inner: kps.public_key(),
        compressed: true,
    };

    let swap_type = swap_restore_type_to_swap_type(restore_response.swap_type.clone());
    let (preimage, amount) = match restore_response.swap_type {
        SwapRestoreType::Submarine => submarine_preimage_and_amount(&invoice),
        SwapRestoreType::Reverse => {
            let preimage_hash = details.preimage_hash.clone().unwrap_or_default();
            let preimage = verified_reverse_preimage(
                BoltzPreimage::from_swap_key(&kps),
                &preimage_hash,
                &restore_response.id,
            )?;
            (preimage, details.amount.unwrap_or(0))
        }
        SwapRestoreType::Chain => {
            return Err(BoltzError::new(
                "Restore".to_string(),
                "Chain swap type not supported for LbtcLnSwap".to_string(),
            ));
        }
    };

    let swap_script = match restore_response.swap_type {
        SwapRestoreType::Submarine => {
            let create_swap_response = CreateSubmarineResponse {
                id: restore_response.id.clone(),
                accept_zero_conf: false,
                address: details.lockup_address.clone(),
                bip21: String::new(),
                claim_public_key: server_public_key,
                expected_amount: amount,
                referral_id: None,
                swap_tree: details.tree.clone(),
                timeout_block_height: details.timeout_block_height as u64,
                blinding_key: details.blinding_key.clone(),
            };
            boltz_client::LBtcSwapScript::submarine_from_swap_resp(
                &create_swap_response,
                kps.public_key().into(),
            )
        }
        SwapRestoreType::Reverse => {
            let create_reverse_response = CreateReverseResponse {
                id: restore_response.id.clone(),
                lockup_address: details.lockup_address.clone(),
                invoice: invoice.clone(),
                timeout_block_height: details.timeout_block_height,
                onchain_amount: amount,
                swap_tree: details.tree.clone(),
                refund_public_key: server_public_key,
                blinding_key: details.blinding_key.clone(),
            };
            boltz_client::LBtcSwapScript::reverse_from_swap_resp(
                &create_reverse_response,
                our_pubkey,
            )
        }
        SwapRestoreType::Chain => {
            return Err(BoltzError::new(
                "Restore".to_string(),
                "Chain swap type not supported for LbtcLnSwap".to_string(),
            ));
        }
    }
    .map_err(|e| BoltzError::new("SwapScript".to_string(), e.to_string()))?;
    validate_restored_hashlock(
        &swap_script.hashlock.to_string(),
        &preimage,
        &restore_response.id,
    )?;

    let blinding_key = details.blinding_key.clone().unwrap_or_default();

    Ok(LbtcLnSwap::new_with_expected_onchain_amount(
        restore_response.id,
        swap_type,
        network,
        keys,
        key_index,
        preimage,
        swap_script.into(),
        invoice.unwrap_or_default(),
        amount,
        details.lockup_address.clone(),
        blinding_key,
        electrum_url,
        boltz_url,
        None,
        (matches!(&restore_response.swap_type, SwapRestoreType::Reverse) && amount > 0)
            .then_some(amount),
    ))
}

fn restore_to_chain_swap(
    restore_response: SwapRestoreResponse,
    swap_master_key: SwapMasterKey,
    btc_electrum_url: String,
    lbtc_electrum_url: String,
    boltz_url: String,
) -> Result<ChainSwap, BoltzError> {
    let direction = infer_chain_swap_direction(&restore_response.from, &restore_response.to)?;
    let network = swap_master_key.network;
    let swap_master_key_inner: boltz_client::util::secrets::SwapMasterKey =
        swap_master_key.try_into()?;

    let refund_details = restore_response.refund_details.as_ref().ok_or_else(|| {
        BoltzError::new(
            "Restore".to_string(),
            "Refund details required for ChainSwap".to_string(),
        )
    })?;

    let claim_details = restore_response.claim_details.as_ref().ok_or_else(|| {
        BoltzError::new(
            "Restore".to_string(),
            "Claim details required for ChainSwap".to_string(),
        )
    })?;

    let refund_index = refund_details.key_index as u64;
    let claim_index = claim_details.key_index as u64;

    let (refund_kps, claim_kps) = match direction {
        ChainSwapDirection::BtcToLbtc => {
            let refund_kps = swap_master_key_inner.derive_swapkey(refund_index)?;
            let claim_kps = swap_master_key_inner.derive_liquid_swapkey(claim_index)?;
            (refund_kps, claim_kps)
        }
        ChainSwapDirection::LbtcToBtc => {
            let refund_kps = swap_master_key_inner.derive_liquid_swapkey(refund_index)?;
            let claim_kps = swap_master_key_inner.derive_swapkey(claim_index)?;
            (refund_kps, claim_kps)
        }
    };

    let refund_keys = KeyPair::from(refund_kps);
    let claim_keys = KeyPair::from(claim_kps);

    // For chain swaps, derive preimage from claim key and verify sha256 matches
    let boltz_preimage = BoltzPreimage::from_swap_key(&claim_kps);
    if boltz_preimage.sha256.to_string() != claim_details.preimage_hash {
        return Err(BoltzError::new(
            "Restore".to_string(),
            format!(
                "Preimage hash mismatch: expected {}, got {}",
                claim_details.preimage_hash,
                boltz_preimage.sha256.to_string()
            ),
        ));
    }
    let preimage = PreImage {
        value: boltz_preimage
            .bytes
            .map(|b| b.to_lower_hex_string())
            .unwrap_or_default(),
        sha256: boltz_preimage.sha256.to_string(),
        hash160: boltz_preimage.hash160.to_string(),
    };

    let refund_chain_details = refund_details_to_chain_swap_details(refund_details)?;
    let claim_chain_details = claim_details_to_chain_swap_details(claim_details)?;

    let refund_public_key = PublicKey {
        inner: refund_kps.public_key(),
        compressed: true,
    };
    let claim_public_key = PublicKey {
        inner: claim_kps.public_key(),
        compressed: true,
    };

    let (btc_script_str, lbtc_script_str) = match direction {
        ChainSwapDirection::BtcToLbtc => {
            let btc_script = boltz_client::BtcSwapScript::chain_from_swap_resp(
                boltz_client::boltz::Side::Lockup,
                refund_chain_details.clone(),
                refund_public_key,
            )
            .map_err(|e| BoltzError::new("SwapScript".to_string(), e.to_string()))?;

            let lbtc_script = boltz_client::LBtcSwapScript::chain_from_swap_resp(
                boltz_client::boltz::Side::Claim,
                claim_chain_details.clone(),
                claim_public_key,
            )
            .map_err(|e| BoltzError::new("SwapScript".to_string(), e.to_string()))?;
            validate_restored_hashlock(
                &btc_script.hashlock.to_string(),
                &preimage,
                &restore_response.id,
            )?;
            validate_restored_hashlock(
                &lbtc_script.hashlock.to_string(),
                &preimage,
                &restore_response.id,
            )?;

            (btc_script.into(), lbtc_script.into())
        }
        ChainSwapDirection::LbtcToBtc => {
            let lbtc_script = boltz_client::LBtcSwapScript::chain_from_swap_resp(
                boltz_client::boltz::Side::Lockup,
                refund_chain_details.clone(),
                refund_public_key,
            )
            .map_err(|e| BoltzError::new("SwapScript".to_string(), e.to_string()))?;

            let btc_script = boltz_client::BtcSwapScript::chain_from_swap_resp(
                boltz_client::boltz::Side::Claim,
                claim_chain_details.clone(),
                claim_public_key,
            )
            .map_err(|e| BoltzError::new("SwapScript".to_string(), e.to_string()))?;
            validate_restored_hashlock(
                &lbtc_script.hashlock.to_string(),
                &preimage,
                &restore_response.id,
            )?;
            validate_restored_hashlock(
                &btc_script.hashlock.to_string(),
                &preimage,
                &restore_response.id,
            )?;

            (btc_script.into(), lbtc_script.into())
        }
    };

    let blinding_key = claim_details.blinding_key.clone().unwrap_or_default();

    Ok(ChainSwap::new_with_expected_onchain_amount(
        restore_response.id,
        network,
        direction,
        refund_keys,
        refund_index,
        claim_keys,
        claim_index,
        preimage,
        btc_script_str,
        lbtc_script_str,
        refund_details.lockup_address.clone(),
        claim_details.amount.unwrap_or(0),
        btc_electrum_url,
        lbtc_electrum_url,
        boltz_url,
        None,
        blinding_key,
        claim_details.amount.filter(|amount| *amount > 0),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use boltz_client::bitcoin::hex::DisplayHex;

    // Fully synthetic fixture: the repo's public test invoice and keys derived
    // from the test-suite master key. Mirrors the shape of a real restore
    // response (boltzr/src/service/rescue.rs): a submarine swap carries
    // refundDetails and NO claimDetails; a reverse swap the opposite.
    const TEST_INVOICE: &str = "lntb1230n1pjmwkxwpp5etvpredwjpwvsrmrcs3l854tcwyz8tnfm453uyp3kcsrmnmu26xsdqqcqzzsxqyjw5qsp5jmejjyf0v6lyn3c5z6uxdslxtnu6t72perfp8ps6ldyen5as9juq9qyyssqtc8409xlyar4vmn70sszyzeu3k28jzlx0k2cjpg6pvh8mdglkn3ymxslmq8entcz56hwu3hx0d8mzjsvtkc3vu9da6j88exflp8urkqppw0vkq";
    const TEST_INVOICE_PAYMENT_HASH: &str =
        "cad811e5ae905cc80f63c423f3d2abc38823ae69dd691e1031b6203dcf7c568d";
    const TEST_INVOICE_SATS: u64 = 123;
    const SUBMARINE_SWAP_ID: &str = "subSwapTest1";
    const SUBMARINE_KEY_INDEX: u64 = 42;
    const REVERSE_KEY_INDEX: u64 = 7;
    const TIMEOUT_BLOCK_HEIGHT: u32 = 1_500_000;

    #[test]
    fn restore_network_comes_from_master_key() {
        assert!(matches!(
            infer_network("BTC", "L-BTC", Network::Testnet),
            Ok(Chain::LiquidTestnet)
        ));
        assert!(matches!(
            infer_network("BTC", "BTC", Network::Testnet),
            Ok(Chain::BitcoinTestnet)
        ));
        assert!(infer_network("BTC", "BTC", Network::Regtest).unwrap() == Chain::BitcoinRegtest);
        assert!(infer_network("L-BTC", "BTC", Network::Regtest).unwrap() == Chain::LiquidRegtest);
        assert!(infer_network("BTC", "L-BTC", Network::Regtest).unwrap() == Chain::LiquidRegtest);
    }

    fn test_master_key() -> SwapMasterKey {
        SwapMasterKey {
            xprv: "xprv9zRA4NuUPQSBywcrKbEapYaYPuJu2rwcGFceusCYtUM1Yx1z1b59TqnseHSk17eWgmo2mVeUWrHzy5uyXrwypZrJRRM7chrJJH1JyKNoE6L".to_string(),
            xpub: "xpub6DQWTtSNDmzVCRhKRcmbBgXGww9PSKfTdUYFiFcASoszRkM8Z8PQ1e7MVYN7zukkhFknC96KYGkTrfSERdojG6coHdGEMoc1g44DGTbCt4D".to_string(),
            mnemonic: "item bar canyon diary fantasy coffee unit program badge drum tent empower".to_string(),
            fingerprint: "d2e2529e".to_string(),
            network: super::super::types::Network::Testnet,
        }
    }

    struct Fixture {
        our_xonly: String,
        server_pubkey: String,
        server_xonly: String,
        hash160: String,
        lockup_address: String,
        /// Preimage hash a restorable reverse swap must carry: derived from
        /// the claim key, like the wallet derives it at creation.
        reverse_preimage_hash: String,
        reverse_hash160: String,
    }

    fn fixture() -> Fixture {
        let master: boltz_client::util::secrets::SwapMasterKey =
            test_master_key().try_into().unwrap();
        let our = master.derive_liquid_swapkey(SUBMARINE_KEY_INDEX).unwrap();
        let server = master
            .derive_liquid_swapkey(SUBMARINE_KEY_INDEX + 1)
            .unwrap();
        let reverse_keys = master.derive_liquid_swapkey(REVERSE_KEY_INDEX).unwrap();
        let payment_hash = Bolt11Invoice::from_str(TEST_INVOICE)
            .unwrap()
            .payment_hash()
            .to_string();
        let preimage = BoltzPreimage::from_sha256_str(&payment_hash).unwrap();
        // Any parseable confidential address works as the lockup address.
        let lockup_address = boltz_client::elements::Address::p2wpkh(
            &boltz_client::elements::bitcoin::PublicKey::from_slice(&our.public_key().serialize())
                .unwrap(),
            Some(server.public_key()),
            &boltz_client::elements::AddressParams::LIQUID,
        )
        .to_string();
        let reverse_preimage = BoltzPreimage::from_swap_key(&reverse_keys);
        Fixture {
            our_xonly: our.x_only_public_key().0.serialize().to_lower_hex_string(),
            server_pubkey: server.public_key().to_string(),
            server_xonly: server
                .x_only_public_key()
                .0
                .serialize()
                .to_lower_hex_string(),
            hash160: preimage.hash160.to_string(),
            lockup_address,
            reverse_preimage_hash: reverse_preimage.sha256.to_string(),
            reverse_hash160: reverse_preimage.hash160.to_string(),
        }
    }

    // Boltz's leaf scripts: claim = HASH160 <hash160> EQUALVERIFY <server> CHECKSIG,
    // refund = <ours> CHECKSIGVERIFY <locktime LE> CLTV.
    fn claim_leaf(f: &Fixture) -> String {
        format!("a914{}8820{}ac", f.hash160, f.server_xonly)
    }

    fn refund_leaf(f: &Fixture) -> String {
        let lt = TIMEOUT_BLOCK_HEIGHT.to_le_bytes();
        format!(
            "20{}ad03{:02x}{:02x}{:02x}b1",
            f.our_xonly, lt[0], lt[1], lt[2]
        )
    }

    fn submarine_restore_json(f: &Fixture) -> serde_json::Value {
        serde_json::json!({
            "id": SUBMARINE_SWAP_ID,
            "type": "submarine",
            "status": "invoice.failedToPay",
            "createdAt": 1785575496u64,
            "from": "L-BTC",
            "to": "BTC",
            "invoice": TEST_INVOICE,
            "refundDetails": {
                "type": "utxo",
                "tree": {
                    "claimLeaf": {"version": 196, "output": claim_leaf(f)},
                    "refundLeaf": {"version": 196, "output": refund_leaf(f)},
                },
                "keyIndex": SUBMARINE_KEY_INDEX,
                "lockupAddress": f.lockup_address,
                "serverPublicKey": f.server_pubkey,
                "timeoutBlockHeight": TIMEOUT_BLOCK_HEIGHT,
                "blindingKey": "1111111111111111111111111111111111111111111111111111111111111111",
            },
        })
    }

    fn reverse_restore_json(f: &Fixture, preimage_hash: &str) -> serde_json::Value {
        serde_json::json!({
            "id": "revSwapTest1",
            "type": "reverse",
            "status": "swap.expired",
            "createdAt": 1785575496u64,
            "from": "BTC",
            "to": "L-BTC",
            "invoice": TEST_INVOICE,
            "claimDetails": {
                "type": "utxo",
                "tree": {
                    "claimLeaf": {
                        "version": 196,
                        "output": format!("a914{}8820{}ac", f.reverse_hash160, f.server_xonly),
                    },
                    "refundLeaf": {"version": 196, "output": refund_leaf(f)},
                },
                "keyIndex": REVERSE_KEY_INDEX,
                "amount": 12345,
                "lockupAddress": f.lockup_address,
                "serverPublicKey": f.server_pubkey,
                "timeoutBlockHeight": TIMEOUT_BLOCK_HEIGHT,
                "blindingKey": "2222222222222222222222222222222222222222222222222222222222222222",
                "preimageHash": preimage_hash,
            },
        })
    }

    /// Serves one canned JSON response on a loopback socket, so the public
    /// restore functions can be tested through their real HTTP path.
    fn serve_once(body: String) -> std::net::SocketAddr {
        use std::io::{Read, Write};
        let listener = std::net::TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        std::thread::spawn(move || {
            if let Ok((mut stream, _)) = listener.accept() {
                let mut buf = [0u8; 8192];
                let _ = stream.read(&mut buf);
                let resp = format!(
                    "HTTP/1.1 200 OK\r\ncontent-type: application/json\r\ncontent-length: {}\r\nconnection: close\r\n\r\n{}",
                    body.len(),
                    body
                );
                let _ = stream.write_all(resp.as_bytes());
            }
        });
        addr
    }

    async fn restore_over_http(swaps_json: Vec<serde_json::Value>) -> RestoredLbtcLnSwaps {
        let addr = serve_once(serde_json::Value::Array(swaps_json).to_string());
        restore_ln_lbtc_swaps(
            test_master_key(),
            "les.bullbitcoin.com:995".to_string(),
            format!("http://{addr}/v2"),
        )
        .await
        .expect("restore must rebuild the batch")
    }

    #[tokio::test]
    async fn restores_submarine_and_reverse_over_http() {
        // The exact call the wallet makes to rescue L-BTC Lightning swaps.
        // Regression: pre-fix, every submarine failed with
        // BoltzError("Restore", "Claim details required for LbtcLnSwap")
        // because boltz returns a submarine's client side under refundDetails.
        let f = fixture();
        let restored = restore_over_http(vec![
            reverse_restore_json(&f, &f.reverse_preimage_hash),
            submarine_restore_json(&f),
        ])
        .await;

        assert!(restored.skipped.is_empty());
        let swaps = &restored.swaps;
        assert_eq!(swaps.len(), 2);
        let reverse = &swaps[0];
        assert_eq!(reverse.id, "revSwapTest1");
        assert_eq!(reverse.key_index, REVERSE_KEY_INDEX);
        assert_eq!(reverse.out_amount, 12345);
        assert_eq!(reverse.expected_onchain_amount, Some(12345));

        let submarine = &swaps[1];
        assert_eq!(submarine.id, SUBMARINE_SWAP_ID);
        assert_eq!(submarine.key_index, SUBMARINE_KEY_INDEX);
        assert_eq!(submarine.script_address, f.lockup_address);
        // Preimage hash and amount are recovered from the invoice
        // (refundDetails carries neither).
        assert_eq!(submarine.preimage.sha256, TEST_INVOICE_PAYMENT_HASH);
        assert_eq!(submarine.out_amount, TEST_INVOICE_SATS);
        assert_eq!(submarine.expected_onchain_amount, None);
    }

    #[tokio::test]
    async fn unrebuildable_swap_is_skipped_and_reported() {
        // A legacy reverse swap whose preimage hash cannot match its
        // key-derived preimage doesn't abort the batch, and the skip is
        // reported with the swap's id so the caller can surface it.
        let f = fixture();
        let legacy_hash = "deadbeef00000000000000000000000000000000000000000000000000000000";
        let restored = restore_over_http(vec![
            reverse_restore_json(&f, legacy_hash),
            submarine_restore_json(&f),
        ])
        .await;

        assert_eq!(restored.swaps.len(), 1);
        assert_eq!(restored.swaps[0].id, SUBMARINE_SWAP_ID);
        assert_eq!(restored.skipped.len(), 1);
        assert_eq!(restored.skipped[0].id, "revSwapTest1");
        assert!(restored.skipped[0].error.contains("Preimage hash mismatch"));
    }

    #[tokio::test]
    async fn restored_swap_with_mismatched_script_hashlock_is_skipped() {
        let f = fixture();
        let mut reverse = reverse_restore_json(&f, &f.reverse_preimage_hash);
        reverse["claimDetails"]["tree"]["claimLeaf"]["output"] =
            serde_json::Value::String(claim_leaf(&f));
        let restored = restore_over_http(vec![reverse]).await;

        assert!(restored.swaps.is_empty());
        assert_eq!(restored.skipped.len(), 1);
        assert!(restored.skipped[0].error.contains("Hashlock mismatch"));
    }

    #[tokio::test]
    async fn submarine_without_invoice_still_restores() {
        // The refund — the only client action on a submarine swap — needs
        // neither preimage nor amount, so a missing (or unparseable, e.g.
        // BOLT12) invoice must not make the swap unrestorable.
        let f = fixture();
        let mut sub = submarine_restore_json(&f);
        sub.as_object_mut().unwrap().remove("invoice");
        let restored = restore_over_http(vec![sub]).await;

        assert!(restored.skipped.is_empty());
        assert_eq!(restored.swaps.len(), 1);
        let submarine = &restored.swaps[0];
        assert_eq!(submarine.id, SUBMARINE_SWAP_ID);
        assert_eq!(submarine.script_address, f.lockup_address);
        assert_eq!(submarine.out_amount, 0);
        assert_eq!(submarine.expected_onchain_amount, None);
        assert!(submarine.preimage.sha256.is_empty());
    }
    #[test]
    fn liquid_regtest_rescue_preserves_network_and_local_http() {
        let mut key = test_master_key();
        key.network = Network::Regtest;
        let mut f = fixture();
        let mut address = boltz_client::ElementsAddress::from_str(&f.lockup_address).unwrap();
        address.params = &boltz_client::elements::AddressParams::ELEMENTS;
        f.lockup_address = address.to_string();
        for response in [
            submarine_restore_json(&f),
            reverse_restore_json(&f, &f.reverse_preimage_hash),
        ] {
            let response: SwapRestoreResponse = serde_json::from_value(response).unwrap();
            let swap = restore_to_lbtc_ln_swap(
                response,
                key.clone(),
                "liquid.example:18202".into(),
                "http://boltz.example:18200/custom/v2".into(),
                None,
            )
            .unwrap();
            assert!(swap.network == Chain::LiquidRegtest);
            assert!(swap.boltz_url == "http://boltz.example:18200/custom/v2");
            let encoded = swap.to_json().unwrap();
            assert!(LbtcLnSwap::from_json(&encoded).unwrap().network == Chain::LiquidRegtest);
        }
    }
}
