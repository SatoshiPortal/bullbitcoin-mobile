use crate::util::{
    bitcoin_tip_height, ensure_boltz_url, ensure_http_prefix, force_https, get_electrum_configs,
    liquid_tip_height, strip_protocol_prefix, HTTP_TIMEOUT,
};

use super::{
    error::BoltzError,
    fees::TxFee,
    secrets::{KeyPair, SwapMasterKey},
    types::{
        BtcSwapScriptStr, Chain, ChainSwapDirection, ElectrumSettings, LBtcSwapScriptStr, Network,
        PreImage, SwapTxKind,
    },
};
use boltz_client::util::secrets::{Preimage, SwapMasterKey as BoltzSwapMasterKey};

use boltz_client::{
    bitcoin::{
        consensus::{serialize, Decodable},
        hex::DisplayHex,
        Transaction as BitcoinTransaction, Txid,
    },
    boltz::{ChainSwapDetails, Cooperative, Side},
    elements::Transaction as LiquidTransaction,
    error::Error,
    network::{
        electrum::{ElectrumBitcoinClient, ElectrumLiquidClient},
        BitcoinChain, BitcoinClient, Chain as AllChains, LiquidChain, LiquidClient,
    },
    swaps::{boltz::BoltzApiClientV2, SwapScriptCommon},
    BtcSwapScript, BtcSwapTx, Keypair, LBtcSwapScript, LBtcSwapTx, PublicKey, Serialize,
};
use serde_json::Value;

/// Bitcoin-Liquid Swap Class
#[derive(Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct ChainSwap {
    pub id: String,
    #[serde(flatten, with = "stored_network")]
    pub network: Network,
    pub direction: ChainSwapDirection,
    pub refund_keys: KeyPair,
    pub refund_index: u64,
    pub claim_keys: KeyPair,
    pub claim_index: u64,
    pub preimage: PreImage,
    pub btc_script_str: BtcSwapScriptStr,
    pub lbtc_script_str: LBtcSwapScriptStr,
    pub script_address: String,
    pub out_amount: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub expected_onchain_amount: Option<u64>,
    pub btc_electrum_url: String,
    pub lbtc_electrum_url: String,
    pub boltz_url: String,
    pub referral_id: Option<String>,
    pub blinding_key: String,
}
/// Tip height of `chain` as the user's own Electrum server for it sees it.
async fn chain_tip_height(
    chain: AllChains,
    btc_electrum_settings: Option<ElectrumSettings>,
    btc_electrum_url: &str,
    lbtc_electrum_settings: Option<ElectrumSettings>,
    lbtc_electrum_url: &str,
) -> Result<u32, BoltzError> {
    match chain {
        AllChains::Bitcoin(chain) => {
            bitcoin_tip_height(chain, btc_electrum_settings, btc_electrum_url).await
        }
        AllChains::Liquid(chain) => {
            liquid_tip_height(chain, lbtc_electrum_settings, lbtc_electrum_url).await
        }
    }
}

impl ChainSwap {
    /// Convert instance to a JSON string.
    pub async fn to_json(&self) -> Result<String, BoltzError> {
        match serde_json::to_string(self) {
            Ok(result) => Ok(result),
            Err(e) => Err(BoltzError::new("JSON".to_string(), e.to_string())),
        }
    }
    /// Parse from a JSON string.
    pub async fn from_json(json_str: &str) -> Result<Self, BoltzError> {
        match serde_json::from_str(json_str) {
            Ok(result) => Ok(result),
            Err(e) => Err(BoltzError::new("JSON".to_string(), e.to_string())),
        }
    }
    /// Manually create the class. Primarily used when recovering a swap.
    pub fn new(
        id: String,
        network: Network,
        direction: ChainSwapDirection,
        refund_keys: KeyPair,
        refund_index: u64,
        claim_keys: KeyPair,
        claim_index: u64,
        preimage: PreImage,
        btc_script_str: BtcSwapScriptStr,
        lbtc_script_str: LBtcSwapScriptStr,
        script_address: String,
        out_amount: u64,
        btc_electrum_url: String,
        lbtc_electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
        blinding_key: String,
    ) -> ChainSwap {
        Self::new_with_expected_onchain_amount(
            id,
            network,
            direction,
            refund_keys,
            refund_index,
            claim_keys,
            claim_index,
            preimage,
            btc_script_str,
            lbtc_script_str,
            script_address,
            out_amount,
            btc_electrum_url,
            lbtc_electrum_url,
            boltz_url,
            referral_id,
            blinding_key,
            None,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new_with_expected_onchain_amount(
        id: String,
        network: Network,
        direction: ChainSwapDirection,
        refund_keys: KeyPair,
        refund_index: u64,
        claim_keys: KeyPair,
        claim_index: u64,
        preimage: PreImage,
        btc_script_str: BtcSwapScriptStr,
        lbtc_script_str: LBtcSwapScriptStr,
        script_address: String,
        out_amount: u64,
        btc_electrum_url: String,
        lbtc_electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
        blinding_key: String,
        expected_onchain_amount: Option<u64>,
    ) -> ChainSwap {
        ChainSwap {
            id,
            direction,
            network,
            refund_keys,
            refund_index,
            claim_keys,
            claim_index,
            preimage,
            btc_script_str,
            lbtc_script_str,
            btc_electrum_url: strip_protocol_prefix(&btc_electrum_url),
            lbtc_electrum_url: strip_protocol_prefix(&lbtc_electrum_url),
            boltz_url: match ensure_boltz_url(&boltz_url, network != Network::Mainnet) {
                Ok(url) => url,
                Err(_) => force_https(&boltz_url),
            },
            script_address,
            out_amount,
            expected_onchain_amount,
            referral_id: Some(referral_id.unwrap_or_default()),
            blinding_key,
        }
    }
    /// Used to create the class when starting a chain swap between Bitcoin and Liquid.
    /// Note: The swap_master_key should be a SwapMasterKey. The refund key uses the given index, and the claim key uses index + 1.
    /// The client is expected to manage (increment) the use of index to ensure keys are not reused.
    pub async fn new_swap(
        direction: ChainSwapDirection,
        swap_master_key: SwapMasterKey,
        index: u64,
        amount: u64,
        network: Network,
        btc_electrum_url: String,
        lbtc_electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
        btc_electrum_settings: Option<ElectrumSettings>,
        lbtc_electrum_settings: Option<ElectrumSettings>,
    ) -> Result<ChainSwap, BoltzError> {
        if network != swap_master_key.network {
            return Err(BoltzError::new(
                "Network".to_string(),
                "Swap master key network does not match the swap network".to_string(),
            ));
        }
        let (refund_network, claim_network): (AllChains, AllChains) = match direction {
            ChainSwapDirection::BtcToLbtc => (network.bitcoin().into(), network.liquid().into()),
            ChainSwapDirection::LbtcToBtc => (network.liquid().into(), network.bitcoin().into()),
        };

        let swap_xkey_inner: BoltzSwapMasterKey = swap_master_key.try_into()?;

        let (refund_kps, claim_kps) = match direction {
            ChainSwapDirection::BtcToLbtc => {
                let refund_kps = swap_xkey_inner.derive_swapkey(index)?;
                let claim_kps = swap_xkey_inner.derive_liquid_swapkey(index + 1)?;
                (refund_kps, claim_kps)
            }
            ChainSwapDirection::LbtcToBtc => {
                let refund_kps = swap_xkey_inner.derive_liquid_swapkey(index)?;
                let claim_kps = swap_xkey_inner.derive_swapkey(index + 1)?;
                (refund_kps, claim_kps)
            }
        };

        let refund_keypair = KeyPair::from(refund_kps);
        let refund_public_key = PublicKey {
            inner: refund_kps.public_key(),
            compressed: true,
        };

        let claim_keypair = KeyPair::from(claim_kps);
        let claim_public_key = PublicKey {
            compressed: true,
            inner: claim_kps.public_key(),
        };
        let preimage: Preimage = Preimage::from_swap_key(&claim_kps);
        let boltz_url = ensure_boltz_url(&boltz_url, network != Network::Mainnet)
            .map_err(|e| BoltzError::new("Network".to_string(), e))?;
        let boltz_client = BoltzApiClientV2::new(boltz_url.clone(), Some(HTTP_TIMEOUT));
        match direction {
            ChainSwapDirection::BtcToLbtc => {
                let create_swap_req = boltz_client::swaps::boltz::CreateChainRequest {
                    from: "BTC".to_string(),
                    to: "L-BTC".to_string(),
                    preimage_hash: preimage.sha256,
                    claim_public_key: Some(claim_public_key),
                    refund_public_key: Some(refund_public_key),
                    referral_id: referral_id.clone(),
                    user_lock_amount: Some(amount),
                    server_lock_amount: None,
                    pair_hash: None,
                    webhook: None, // Add address signature here.
                };
                let create_chain_response = boltz_client.post_chain_req(create_swap_req).await?;
                create_chain_response.validate(
                    &claim_public_key,
                    &refund_public_key,
                    refund_network,
                    claim_network,
                    &preimage.sha256,
                )?;
                let tip_of = |chain| {
                    chain_tip_height(
                        chain,
                        btc_electrum_settings.clone(),
                        &btc_electrum_url,
                        lbtc_electrum_settings.clone(),
                        &lbtc_electrum_url,
                    )
                };
                create_chain_response.validate_timeouts(
                    refund_network,
                    tip_of(refund_network).await?,
                    claim_network,
                    tip_of(claim_network).await?,
                )?;
                let lockup_details: ChainSwapDetails = create_chain_response.clone().lockup_details;
                let lockup_script = BtcSwapScript::chain_from_swap_resp(
                    Side::Lockup,
                    lockup_details.clone(),
                    refund_public_key,
                )?;
                let bitcoin_chain = match refund_network.clone() {
                    AllChains::Bitcoin(inner_chain) => inner_chain,
                    _ => {
                        return Err(BoltzError::new(
                            "ChainType".to_string(),
                            "Expected Bitcoin chain but got Liquid chain".to_string(),
                        ))
                    }
                };

                let lockup_address = lockup_script.clone().to_address(bitcoin_chain)?;
                if lockup_address.clone().to_string()
                    != lockup_details.clone().lockup_address.to_string()
                {
                    return Err(Error::Address("Lockup Address Mismatch".to_owned()).into());
                }
                let claim_details: ChainSwapDetails = create_chain_response.claim_details;
                let expected_onchain_amount =
                    (claim_details.amount > 0).then_some(claim_details.amount);
                let claim_script = LBtcSwapScript::chain_from_swap_resp(
                    Side::Claim,
                    claim_details.clone(),
                    claim_public_key,
                )?;
                Ok(ChainSwap::new_with_expected_onchain_amount(
                    create_chain_response.id,
                    network,
                    direction,
                    refund_keypair,
                    index,
                    claim_keypair,
                    index + 1,
                    preimage.into(),
                    lockup_script.into(),
                    claim_script.clone().into(),
                    lockup_address.to_string(),
                    create_chain_response.lockup_details.amount as u64,
                    strip_protocol_prefix(&btc_electrum_url),
                    strip_protocol_prefix(&lbtc_electrum_url),
                    boltz_url.clone(),
                    referral_id,
                    claim_script.blinding_key.display_secret().to_string(),
                    expected_onchain_amount,
                ))
            }
            ChainSwapDirection::LbtcToBtc => {
                let create_swap_req = boltz_client::swaps::boltz::CreateChainRequest {
                    from: "L-BTC".to_string(),
                    to: "BTC".to_string(),
                    preimage_hash: preimage.sha256,
                    claim_public_key: Some(claim_public_key),
                    refund_public_key: Some(refund_public_key),
                    referral_id: referral_id.clone(),
                    user_lock_amount: Some(amount),
                    server_lock_amount: None,
                    pair_hash: None, // Add address signature here.
                    webhook: None,
                };
                let create_chain_response = boltz_client.post_chain_req(create_swap_req).await?;
                create_chain_response.validate(
                    &claim_public_key,
                    &refund_public_key,
                    refund_network,
                    claim_network,
                    &preimage.sha256,
                )?;
                let tip_of = |chain| {
                    chain_tip_height(
                        chain,
                        btc_electrum_settings.clone(),
                        &btc_electrum_url,
                        lbtc_electrum_settings.clone(),
                        &lbtc_electrum_url,
                    )
                };
                create_chain_response.validate_timeouts(
                    refund_network,
                    tip_of(refund_network).await?,
                    claim_network,
                    tip_of(claim_network).await?,
                )?;
                let lockup_details: ChainSwapDetails = create_chain_response.clone().lockup_details;
                let lockup_script = LBtcSwapScript::chain_from_swap_resp(
                    Side::Lockup,
                    lockup_details.clone(),
                    refund_public_key,
                )?;

                let liquid_chain = match refund_network {
                    AllChains::Liquid(inner_chain) => inner_chain,
                    _ => {
                        return Err(BoltzError::new(
                            "ChainType".to_string(),
                            "Expected Liquid chain but got Bitcoin chain".to_string(),
                        ))
                    }
                };

                let lockup_address = lockup_script.clone().to_address(liquid_chain)?;
                if lockup_address.clone().to_string()
                    != lockup_details.clone().lockup_address.to_string()
                {
                    return Err(Error::Address("Lockup Address Mismatch".to_owned()).into());
                }
                let claim_details: ChainSwapDetails = create_chain_response.claim_details;
                let expected_onchain_amount =
                    (claim_details.amount > 0).then_some(claim_details.amount);
                let claim_script = BtcSwapScript::chain_from_swap_resp(
                    Side::Claim,
                    claim_details.clone(),
                    claim_public_key,
                )?;
                Ok(ChainSwap::new_with_expected_onchain_amount(
                    create_chain_response.id,
                    network,
                    direction,
                    refund_keypair,
                    index,
                    claim_keypair,
                    index + 1,
                    preimage.into(),
                    claim_script.into(),
                    lockup_script.clone().into(),
                    lockup_address.to_string(),
                    create_chain_response.lockup_details.amount as u64,
                    strip_protocol_prefix(&btc_electrum_url),
                    strip_protocol_prefix(&lbtc_electrum_url),
                    boltz_url.clone(),
                    referral_id,
                    lockup_script.blinding_key.display_secret().to_string(),
                    expected_onchain_amount,
                ))
            }
        }
    }
    /// Get the transaction id of the server's lockup transaction
    pub async fn get_server_lockup(&self) -> Result<String, BoltzError> {
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let txs = boltz_client.get_chain_txs(&self.id.clone()).await?;
        if txs.server_lock.is_none() {
            Err(BoltzError::new(
                "Not Found".to_string(),
                "No Server Lockup Tx Detected.".to_string(),
            ))
        } else {
            Ok(txs.server_lock.unwrap().transaction.id)
        }
    }
    /// Get the transaction id of the user's lockup transaction
    pub async fn get_user_lockup(&self) -> Result<String, BoltzError> {
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let txs = boltz_client.get_chain_txs(&self.id.clone()).await?;
        if txs.user_lock.is_none() {
            Err(BoltzError::new(
                "Not Found".to_string(),
                "No User Lockup Tx Detected.".to_string(),
            ))
        } else {
            Ok(txs.user_lock.unwrap().transaction.id)
        }
    }
    /// Claim a successful swap
    pub async fn claim(
        &self,
        out_address: String,
        miner_fee: TxFee,
        try_cooperate: bool,
        btc_electrum_settings: Option<ElectrumSettings>,
        lbtc_electrum_settings: Option<ElectrumSettings>,
    ) -> Result<String, BoltzError> {
        let btc_chain: BitcoinChain = self.network.bitcoin().into();
        let lbtc_chain: LiquidChain = self.network.liquid().into();
        let id: String = self.id.clone();

        let (btc_url, btc_tls, btc_validate_domain, btc_timeout) =
            get_electrum_configs(btc_electrum_settings, &self.btc_electrum_url);

        let (lbtc_url, lbtc_tls, lbtc_validate_domain, lbtc_timeout) =
            get_electrum_configs(lbtc_electrum_settings, &self.lbtc_electrum_url);

        let btc_network_config = ElectrumBitcoinClient::new(
            btc_chain,
            &btc_url,
            btc_tls,
            btc_validate_domain,
            btc_timeout,
        )?;

        let lbtc_network_config = ElectrumLiquidClient::new(
            lbtc_chain,
            &lbtc_url,
            lbtc_tls,
            lbtc_validate_domain,
            lbtc_timeout,
        )?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));

        match self.direction {
            ChainSwapDirection::BtcToLbtc => {
                let lbtc_claim_script: LBtcSwapScript = self.lbtc_script_str.clone().try_into()?;
                let claim_tx: LBtcSwapTx = LBtcSwapTx::new_claim(
                    lbtc_claim_script.clone(),
                    out_address.clone(),
                    &lbtc_network_config,
                    &boltz_client,
                    id.clone(),
                )
                .await?;
                if let Some(expected_amount) = self.expected_onchain_amount {
                    claim_tx.validate_lockup_amount(lbtc_chain, expected_amount)?;
                }
                let ckp: Keypair = self.claim_keys.clone().try_into()?;
                let preimage: Preimage = self.preimage.clone().try_into()?;
                if try_cooperate {
                    let btc_lockup_script: BtcSwapScript =
                        self.btc_script_str.clone().try_into()?;
                    let claim_tx_response = boltz_client.get_chain_claim_tx_details(&id).await?;
                    let rkp: Keypair = self.refund_keys.clone().try_into()?;
                    let claim_tx_response_opt = claim_tx_response.ok_or(BoltzError::new(
                        "Not Found".to_string(),
                        "No Claim Tx Details Detected.".to_string(),
                    ))?;
                    if claim_tx_response_opt.public_key != btc_lockup_script.receiver_pubkey {
                        return Err(BoltzError::new(
                            "Protocol".to_string(),
                            "Cooperative counterparty public key mismatch".to_string(),
                        ));
                    }
                    let pub_nonce = claim_tx_response_opt.pub_nonce;
                    let transaction_hash = claim_tx_response_opt.transaction_hash;
                    let (partial_sig, pub_nonce) =
                        btc_lockup_script.partial_sign(&rkp, &pub_nonce, &transaction_hash)?;
                    let signed = match claim_tx
                        .sign_claim(
                            &ckp,
                            &preimage,
                            miner_fee.into(),
                            Some(Cooperative {
                                boltz_api: &boltz_client,
                                swap_id: id,
                                signature: Some((partial_sig, pub_nonce)),
                            }),
                            false,
                        )
                        .await
                    {
                        Ok(result) => result,
                        Err(e) => return Err(e.into()),
                    };
                    Ok(signed.serialize().to_lower_hex_string())
                } else {
                    let signed = match claim_tx
                        .sign_claim(&ckp, &preimage, miner_fee.into(), None, true)
                        .await
                    {
                        Ok(result) => result,
                        Err(e) => return Err(e.into()),
                    };
                    Ok(signed.serialize().to_lower_hex_string())
                }
            }
            ChainSwapDirection::LbtcToBtc => {
                let btc_claim_script: BtcSwapScript = self.btc_script_str.clone().try_into()?;
                let claim_tx = BtcSwapTx::new_claim_confirmed(
                    btc_claim_script.clone(),
                    out_address.clone(),
                    &btc_network_config,
                )
                .await?;
                if let Some(expected_amount) = self.expected_onchain_amount {
                    claim_tx.validate_lockup_amount(expected_amount)?;
                }
                let ckp: Keypair = self.claim_keys.clone().try_into()?;
                let preimage: Preimage = self.preimage.clone().try_into()?;

                if try_cooperate {
                    let lbtc_lockup_script: LBtcSwapScript =
                        self.lbtc_script_str.clone().try_into()?;

                    let claim_tx_response = boltz_client.get_chain_claim_tx_details(&id).await?;
                    let rkp: Keypair = self.refund_keys.clone().try_into()?;
                    let claim_tx_response_opt = claim_tx_response.ok_or(BoltzError::new(
                        "Not Found".to_string(),
                        "No Claim Tx Details Detected.".to_string(),
                    ))?;
                    if claim_tx_response_opt.public_key != lbtc_lockup_script.receiver_pubkey {
                        return Err(BoltzError::new(
                            "Protocol".to_string(),
                            "Cooperative counterparty public key mismatch".to_string(),
                        ));
                    }
                    let transaction_hash = claim_tx_response_opt.transaction_hash;
                    let pub_nonce = claim_tx_response_opt.pub_nonce;
                    let (partial_sig, pub_nonce) =
                        lbtc_lockup_script.partial_sign(&rkp, &pub_nonce, &transaction_hash)?;
                    let signed = match claim_tx
                        .sign_claim(
                            &ckp,
                            &preimage,
                            miner_fee.into(),
                            Some(Cooperative {
                                boltz_api: &boltz_client,
                                swap_id: id,
                                signature: Some((partial_sig, pub_nonce)),
                            }),
                        )
                        .await
                    {
                        Ok(result) => result,
                        Err(e) => return Err(e.into()),
                    };
                    let serialized_tx: Vec<u8> = serialize(&signed);
                    Ok(serialized_tx.to_lower_hex_string())
                } else {
                    let signed = match claim_tx
                        .sign_claim(&ckp, &preimage, miner_fee.into(), None)
                        .await
                    {
                        Ok(result) => result,
                        Err(e) => return Err(e.into()),
                    };
                    let serialized_tx: Vec<u8> = serialize(&signed);
                    Ok(serialized_tx.to_lower_hex_string())
                }
            }
        }
    }

    /// Get the size of a claim tx
    pub async fn claim_tx_size(
        &self,
        out_address: String,
        try_cooperate: bool,
        btc_electrum_settings: Option<ElectrumSettings>,
        lbtc_electrum_settings: Option<ElectrumSettings>,
    ) -> Result<usize, BoltzError> {
        let btc_chain: BitcoinChain = self.network.bitcoin().into();
        let lbtc_chain: LiquidChain = self.network.liquid().into();
        let id: String = self.id.clone();

        let (btc_url, btc_tls, btc_validate_domain, btc_timeout) =
            get_electrum_configs(btc_electrum_settings, &self.btc_electrum_url);

        let (lbtc_url, lbtc_tls, lbtc_validate_domain, lbtc_timeout) =
            get_electrum_configs(lbtc_electrum_settings, &self.lbtc_electrum_url);

        let btc_network_config = ElectrumBitcoinClient::new(
            btc_chain,
            &btc_url,
            btc_tls,
            btc_validate_domain,
            btc_timeout,
        )?;

        let lbtc_network_config = ElectrumLiquidClient::new(
            lbtc_chain,
            &lbtc_url,
            lbtc_tls,
            lbtc_validate_domain,
            lbtc_timeout,
        )?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));

        match self.direction {
            ChainSwapDirection::BtcToLbtc => {
                let lbtc_claim_script: LBtcSwapScript = self.lbtc_script_str.clone().try_into()?;
                let claim_tx: LBtcSwapTx = LBtcSwapTx::new_claim(
                    lbtc_claim_script.clone(),
                    out_address.clone(),
                    &lbtc_network_config,
                    &boltz_client,
                    id.clone(),
                )
                .await?;
                let ckp: Keypair = self.claim_keys.clone().try_into()?;

                let size = match claim_tx.size(&ckp, try_cooperate, true) {
                    Ok(result) => result,
                    Err(e) => return Err(e.into()),
                };
                Ok(size)
            }
            ChainSwapDirection::LbtcToBtc => {
                let btc_claim_script: BtcSwapScript = self.btc_script_str.clone().try_into()?;

                let claim_tx = BtcSwapTx::new_claim(
                    btc_claim_script.clone(),
                    out_address.clone(),
                    &btc_network_config,
                    &boltz_client,
                    id.clone(),
                )
                .await?;
                let ckp: Keypair = self.claim_keys.clone().try_into()?;
                let size = match claim_tx.size(&ckp, try_cooperate) {
                    Ok(result) => result,
                    Err(e) => return Err(e.into()),
                };
                Ok(size)
            }
        }
    }

    /// Refund a failed swap
    pub async fn refund(
        &self,
        refund_address: String,
        miner_fee: TxFee,
        try_cooperate: bool,
        btc_electrum_settings: Option<ElectrumSettings>,
        lbtc_electrum_settings: Option<ElectrumSettings>,
    ) -> Result<String, BoltzError> {
        let btc_chain: BitcoinChain = self.network.bitcoin().into();
        let lbtc_chain: LiquidChain = self.network.liquid().into();
        let id: String = self.id.clone();

        let (btc_url, btc_tls, btc_validate_domain, btc_timeout) =
            get_electrum_configs(btc_electrum_settings, &self.btc_electrum_url);

        let (lbtc_url, lbtc_tls, lbtc_validate_domain, lbtc_timeout) =
            get_electrum_configs(lbtc_electrum_settings, &self.lbtc_electrum_url);

        let btc_network_config = ElectrumBitcoinClient::new(
            btc_chain,
            &btc_url,
            btc_tls,
            btc_validate_domain,
            btc_timeout,
        )?;

        let lbtc_network_config = ElectrumLiquidClient::new(
            lbtc_chain,
            &lbtc_url,
            lbtc_tls,
            lbtc_validate_domain,
            lbtc_timeout,
        )?;

        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        match self.direction {
            ChainSwapDirection::BtcToLbtc => {
                let btc_lockup_script: BtcSwapScript = self.btc_script_str.clone().try_into()?;
                let refund_tx = BtcSwapTx::new_refund(
                    btc_lockup_script.clone(),
                    &refund_address,
                    &btc_network_config,
                    &boltz_client,
                    self.id.clone(),
                )
                .await?;
                let rkp: Keypair = self.refund_keys.clone().try_into()?;
                let signed = match refund_tx
                    .sign_refund(
                        &rkp,
                        miner_fee.into(),
                        if try_cooperate {
                            Some(Cooperative {
                                boltz_api: &boltz_client,
                                swap_id: id,
                                signature: None,
                            })
                        } else {
                            None
                        },
                    )
                    .await
                {
                    Ok(result) => result,
                    Err(e) => return Err(e.into()),
                };
                let serialized_tx: Vec<u8> = serialize(&signed);
                Ok(serialized_tx.to_lower_hex_string())
            }
            ChainSwapDirection::LbtcToBtc => {
                let lbtc_lockup_script: LBtcSwapScript = self.lbtc_script_str.clone().try_into()?;
                let refund_tx = LBtcSwapTx::new_refund(
                    lbtc_lockup_script.clone(),
                    &refund_address,
                    &lbtc_network_config,
                    &boltz_client,
                    id.clone(),
                )
                .await?;
                let rkp: Keypair = self.refund_keys.clone().try_into()?;
                let signed = match refund_tx
                    .sign_refund(
                        &rkp,
                        miner_fee.into(),
                        if try_cooperate {
                            Some(Cooperative {
                                boltz_api: &boltz_client,
                                swap_id: id,
                                signature: None,
                            })
                        } else {
                            None
                        },
                        false,
                    )
                    .await
                {
                    Ok(result) => result,
                    Err(e) => return Err(e.into()),
                };
                Ok(signed.serialize().to_lower_hex_string())
            }
        }
    }
    /// Get the size of a refund tx
    pub async fn refund_tx_size(
        &self,
        refund_address: String,
        try_cooperate: bool,
        btc_electrum_settings: Option<ElectrumSettings>,
        lbtc_electrum_settings: Option<ElectrumSettings>,
    ) -> Result<usize, BoltzError> {
        let btc_chain: BitcoinChain = self.network.bitcoin().into();
        let lbtc_chain: LiquidChain = self.network.liquid().into();
        let id: String = self.id.clone();

        let (btc_url, btc_tls, btc_validate_domain, btc_timeout) =
            get_electrum_configs(btc_electrum_settings, &self.btc_electrum_url);

        let (lbtc_url, lbtc_tls, lbtc_validate_domain, lbtc_timeout) =
            get_electrum_configs(lbtc_electrum_settings, &self.lbtc_electrum_url);

        let btc_network_config = ElectrumBitcoinClient::new(
            btc_chain,
            &btc_url,
            btc_tls,
            btc_validate_domain,
            btc_timeout,
        )?;

        let lbtc_network_config = ElectrumLiquidClient::new(
            lbtc_chain,
            &lbtc_url,
            lbtc_tls,
            lbtc_validate_domain,
            lbtc_timeout,
        )?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));

        match self.direction {
            ChainSwapDirection::BtcToLbtc => {
                let btc_lockup_script: BtcSwapScript = self.btc_script_str.clone().try_into()?;
                let refund_tx = BtcSwapTx::new_refund(
                    btc_lockup_script.clone(),
                    &refund_address,
                    &btc_network_config,
                    &boltz_client,
                    self.id.clone(),
                )
                .await?;
                let rkp: Keypair = self.refund_keys.clone().try_into()?;

                let size = match refund_tx.size(&rkp, try_cooperate) {
                    Ok(result) => result,
                    Err(e) => return Err(e.into()),
                };
                Ok(size)
            }
            ChainSwapDirection::LbtcToBtc => {
                let lbtc_lockup_script: LBtcSwapScript = self.lbtc_script_str.clone().try_into()?;

                let refund_tx = LBtcSwapTx::new_refund(
                    lbtc_lockup_script.clone(),
                    &refund_address,
                    &lbtc_network_config,
                    &boltz_client,
                    id.clone(),
                )
                .await?;
                let rkp: Keypair = self.refund_keys.clone().try_into()?;
                let size = match refund_tx.size(&rkp, try_cooperate, true) {
                    Ok(result) => result,
                    Err(e) => return Err(e.into()),
                };
                Ok(size)
            }
        }
    }

    /// Get the network of the swap given a SwapTxKind
    fn get_network(&self, kind: SwapTxKind) -> (Chain, String) {
        match (self.direction, kind) {
            (ChainSwapDirection::BtcToLbtc, SwapTxKind::Refund)
            | (ChainSwapDirection::LbtcToBtc, SwapTxKind::Claim) => {
                (self.network.bitcoin(), self.btc_electrum_url.clone())
            }
            _ => (self.network.liquid(), self.lbtc_electrum_url.clone()),
        }
    }
    /// Broadcast a signed transaction via your own electrum server used when the swap was created.
    pub async fn broadcast_local(
        &self,
        signed_hex: String,
        kind: SwapTxKind,
        electrum_settings: Option<ElectrumSettings>,
    ) -> Result<String, BoltzError> {
        let signed_bytes = hex::decode(&signed_hex)
            .map_err(|e| BoltzError::new("HexDecode".to_string(), e.to_string()))?;
        let (network, default_electrum_url) = self.get_network(kind);

        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &default_electrum_url);

        match network {
            Chain::Bitcoin | Chain::BitcoinTestnet | Chain::BitcoinRegtest => {
                let network_config = ElectrumBitcoinClient::new(
                    network.into(),
                    &electrum_url,
                    tls,
                    validate_domain,
                    timeout,
                )?;

                let transaction = BitcoinTransaction::consensus_decode(&mut &signed_bytes[..])
                    .map_err(|e| BoltzError::new("Bitcoin".to_string(), e.to_string()))?;

                let txid: Txid = match network_config.broadcast_tx(&transaction).await {
                    Ok(r) => r,
                    Err(e) => {
                        return Err(BoltzError::new("Electrum".to_string(), format!("{:?}", e)))
                    }
                };
                Ok(txid.to_string())
            }
            Chain::Liquid | Chain::LiquidTestnet | Chain::LiquidRegtest => {
                let network_config = ElectrumLiquidClient::new(
                    network.into(),
                    &electrum_url,
                    tls,
                    validate_domain,
                    timeout,
                )?;
                let transaction = <LiquidTransaction as boltz_client::elements::encode::Decodable>::consensus_decode(&mut &signed_bytes[..])
                    .map_err(|e| BoltzError::new("Bitcoin".to_string(), e.to_string()))?;
                let txid = match network_config.broadcast_tx(&transaction).await {
                    Ok(r) => r,
                    Err(e) => {
                        return Err(BoltzError::new("Electrum".to_string(), format!("{:?}", e)))
                    }
                };
                Ok(txid.to_string())
            }
        }
    }
    /// Broadcast a signed transaction using boltz's electrum server
    pub async fn broadcast_boltz(
        &self,
        signed_hex: String,
        kind: SwapTxKind,
    ) -> Result<String, BoltzError> {
        let (network, _) = self.get_network(kind);
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let txid = match boltz_client.broadcast_tx(network.into(), &signed_hex).await {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        Ok(extract_id(txid)?)
    }
}
/// Helper method used to extract the txid from a JSON response
fn extract_id(response: Value) -> Result<String, BoltzError> {
    // Attempt to access the `id` field directly
    match response.get("id") {
        Some(id_value) if id_value.is_string() => Ok(id_value.as_str().unwrap().to_string()),
        _ => Err(BoltzError::new(
            "BoltzApi".to_string(),
            "TxId not found in boltz response".to_string(),
        )),
    }
}

// ChainSwap's production JSON is consumed by older application versions.
// Keep its boolean wire format, and make regtest unreadable by those readers.
mod stored_network {
    use super::Network;
    use serde::{ser::SerializeMap, Deserialize, Deserializer, Serializer};

    pub(super) fn serialize<S: Serializer>(
        network: &Network,
        serializer: S,
    ) -> Result<S::Ok, S::Error> {
        let mut map = serializer.serialize_map(Some(1))?;
        match network {
            Network::Mainnet => map.serialize_entry("is_testnet", &false)?,
            Network::Testnet => map.serialize_entry("is_testnet", &true)?,
            Network::Regtest => map.serialize_entry("network", network)?,
        }
        map.end()
    }

    fn present<'de, T: Deserialize<'de>, D: Deserializer<'de>>(
        deserializer: D,
    ) -> Result<Option<T>, D::Error> {
        T::deserialize(deserializer).map(Some)
    }

    pub(super) fn deserialize<'de, D: Deserializer<'de>>(
        deserializer: D,
    ) -> Result<Network, D::Error> {
        #[derive(Deserialize)]
        struct Stored {
            #[serde(default, deserialize_with = "present")]
            is_testnet: Option<bool>,
            #[serde(default, deserialize_with = "present")]
            network: Option<Network>,
        }
        let stored = Stored::deserialize(deserializer)?;
        match (stored.is_testnet, stored.network) {
            (Some(false), None) => Ok(Network::Mainnet),
            (Some(true), None) => Ok(Network::Testnet),
            (None, Some(Network::Regtest)) => Ok(Network::Regtest),
            _ => Err(serde::de::Error::custom(
                "Missing or conflicting swap network",
            )),
        }
    }
}
