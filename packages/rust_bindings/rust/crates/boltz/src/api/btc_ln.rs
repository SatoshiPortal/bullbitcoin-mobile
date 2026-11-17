use super::{
    error::BoltzError,
    fees::TxFee,
    secrets::{KeyPair, SwapMasterKey},
    types::{BtcSwapScriptStr, Chain, ElectrumSettings, Network, PreImage, SwapType},
};
use crate::util::{
    ensure_boltz_url, ensure_http_prefix, force_https, get_electrum_configs, strip_protocol_prefix,
    HTTP_TIMEOUT,
};
use boltz_client::util::secrets::{Preimage, SwapMasterKey as BoltzSwapMasterKey};
use std::str::FromStr;

use boltz_client::{
    bitcoin::{
        consensus::{encode::serialize, Decodable},
        Transaction, Txid,
    },
    boltz::Cooperative,
    network::{electrum::ElectrumBitcoinClient, BitcoinClient, Chain as AllChains},
    swaps::{boltz::BoltzApiClientV2, magic_routing, SwapScript},
    BtcSwapScript, BtcSwapTx, DisplayHex, Keypair, PublicKey,
};
use serde::{Deserialize, Serialize};
use serde_json::Value;

// / Bitcoin-Lightning Swap Class
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BtcLnSwap {
    pub id: String,
    pub kind: SwapType,
    pub network: Chain,
    pub keys: KeyPair,
    pub key_index: u64,
    pub preimage: PreImage,
    pub swap_script: BtcSwapScriptStr,
    pub invoice: String,
    pub script_address: String,
    // pub out_address: Option<String>,
    pub out_amount: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub expected_onchain_amount: Option<u64>,
    pub electrum_url: String,
    pub boltz_url: String,
    pub referral_id: Option<String>,
}
impl BtcLnSwap {
    /// Convert instance to a JSON string.
    pub fn to_json(&self) -> Result<String, BoltzError> {
        match serde_json::to_string(self) {
            Ok(result) => Ok(result),
            Err(e) => Err(BoltzError::new("JSON".to_string(), e.to_string())),
        }
    }
    /// Parse from a JSON string.
    pub fn from_json(json_str: &str) -> Result<Self, BoltzError> {
        match serde_json::from_str(json_str) {
            Ok(result) => Ok(result),
            Err(e) => Err(BoltzError::new("JSON".to_string(), e.to_string())),
        }
    }
    /// Manually create the class. Primarily used when recovering a swap.
    pub fn new(
        id: String,
        kind: SwapType,
        network: Chain,
        keys: KeyPair,
        key_index: u64,
        preimage: PreImage,
        swap_script: BtcSwapScriptStr,
        invoice: String,
        script_address: String,
        out_amount: u64,
        electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
    ) -> BtcLnSwap {
        Self::new_with_expected_onchain_amount(
            id,
            kind,
            network,
            keys,
            key_index,
            preimage,
            swap_script,
            invoice,
            script_address,
            out_amount,
            electrum_url,
            boltz_url,
            referral_id,
            None,
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub(crate) fn new_with_expected_onchain_amount(
        id: String,
        kind: SwapType,
        network: Chain,
        keys: KeyPair,
        key_index: u64,
        preimage: PreImage,
        swap_script: BtcSwapScriptStr,
        invoice: String,
        script_address: String,
        out_amount: u64,
        electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
        expected_onchain_amount: Option<u64>,
    ) -> BtcLnSwap {
        BtcLnSwap {
            id,
            kind,
            network,
            keys,
            key_index,
            preimage,
            swap_script,
            invoice,
            electrum_url: strip_protocol_prefix(&electrum_url),
            boltz_url: match ensure_boltz_url(
                &boltz_url,
                Network::from(network) != Network::Mainnet,
            ) {
                Ok(url) => url,
                Err(_) => force_https(&boltz_url),
            },
            script_address,
            out_amount,
            expected_onchain_amount,
            referral_id: Some(referral_id.unwrap_or_default()),
        }
    }
    /// Used to create the class when starting a submarine swap to pay a lightning invoice with Bitcoin.
    /// Note: The swap_master_key should be a SwapMasterKey for the swap network.
    /// The client is expected to manage (increment) the use of index to ensure keys are not reused.
    pub async fn new_submarine(
        swap_master_key: SwapMasterKey,
        index: u64,
        invoice: String,
        network: Chain,
        electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
    ) -> Result<BtcLnSwap, BoltzError> {
        let swap_type = SwapType::Submarine;
        let electrum_url = strip_protocol_prefix(&electrum_url);
        if network != swap_master_key.network.bitcoin() {
            return Err(BoltzError::new(
                "Network".to_string(),
                "Swap master key network does not match the swap chain".to_string(),
            ));
        }
        let swap_xkey_inner: BoltzSwapMasterKey = swap_master_key.try_into()?;
        let refund_kps = swap_xkey_inner.derive_swapkey(index)?;
        let refund_keypair = KeyPair::from(refund_kps);
        let preimage: PreImage = match PreImage::from_invoice_str(&invoice) {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        let boltz_url = ensure_boltz_url(&boltz_url, Network::from(network) != Network::Mainnet)
            .map_err(|e| BoltzError::new("Network".to_string(), e))?;
        let boltz_client = BoltzApiClientV2::new(boltz_url.clone(), Some(HTTP_TIMEOUT));
        let create_swap_req = boltz_client::swaps::boltz::CreateSubmarineRequest {
            from: "BTC".to_string(),
            to: "BTC".to_string(),
            invoice: invoice.to_string(),
            referral_id: referral_id.clone(),
            refund_public_key: refund_kps.public_key().into(),
            pair_hash: None,
            webhook: None,
        };
        let refund_pubkey = PublicKey {
            compressed: true,
            inner: refund_kps.public_key(),
        };
        let create_swap_response = boltz_client.post_swap_req(&create_swap_req).await?;
        create_swap_response.validate(&invoice, &refund_pubkey, network.into())?;
        let swap_script = BtcSwapScript::submarine_from_swap_resp(
            &create_swap_response,
            refund_kps.public_key().into(),
        )?;
        let all_chains: AllChains = network.into();
        let bitcoin_chain = match all_chains {
            AllChains::Bitcoin(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Bitcoin chain but got Liquid chain".to_string(),
                ))
            }
        };

        let script_address = swap_script.to_address(bitcoin_chain.into())?.to_string();

        Ok(BtcLnSwap::new_with_expected_onchain_amount(
            create_swap_response.id,
            swap_type,
            network,
            refund_keypair,
            index,
            preimage.into(),
            swap_script.into(),
            invoice,
            script_address,
            create_swap_response.expected_amount,
            strip_protocol_prefix(&electrum_url),
            boltz_url.clone(),
            referral_id,
            None,
        ))
    }
    /// After boltz completes a submarine swap, call this function to close the swap cooperatively using Musig.
    /// If this function is not called within ~1 hour, the swap will be closed via the script path.
    /// The benefit of a cooperative close is that the onchain footprint is smaller and makes the transaction look like a single sig tx, while the script path spend is clearly a swap tx.
    /// Delegates to boltz-rust's validated flow, which verifies the server's
    /// preimage against the invoice payment hash before partial-signing —
    /// never sign a spend of the lockup without proof the invoice was paid.
    pub async fn coop_close_submarine(&self) -> Result<(), BoltzError> {
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let swap_script: BtcSwapScript = self.swap_script.clone().try_into()?;
        let ckp: Keypair = self.keys.clone().try_into()?;
        SwapScript::from_bitcoin(swap_script)
            .submarine_cooperative_claim(&self.id, &ckp, &self.invoice, &boltz_client)
            .await?;
        Ok(())
    }
    /// Retrieves the preimage for a completed submarine swap.
    pub async fn get_completed_submarine_preimage(&self) -> Result<String, BoltzError> {
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let response = boltz_client
            .get_submarine_claim_tx_details(&self.id)
            .await?;
        let swap_script: BtcSwapScript = self.swap_script.clone().try_into()?;
        let preimage = Preimage::from_str(&response.preimage)?;
        if preimage.sha256.to_string() != self.preimage.sha256
            || preimage.hash160 != swap_script.hashlock
        {
            return Err(BoltzError::new(
                "Protocol".to_string(),
                "Completed submarine preimage mismatch".to_string(),
            ));
        }
        Ok(response.preimage)
    }
    /// Used to create the class when starting a reverse swap to receive Bitcoin via Lightning.
    /// Note: The swap_master_key should be a SwapMasterKey for the swap network.
    /// The client is expected to manage (increment) the use of index to ensure keys are not reused.
    pub async fn new_reverse(
        swap_master_key: SwapMasterKey,
        index: u64,
        out_amount: u64,
        out_address: Option<String>,
        network: Chain,
        electrum_url: String,
        boltz_url: String,
        description: Option<String>,
        referral_id: Option<String>,
    ) -> Result<BtcLnSwap, BoltzError> {
        let swap_type = SwapType::Reverse;
        if network != swap_master_key.network.bitcoin() {
            return Err(BoltzError::new(
                "Network".to_string(),
                "Swap master key network does not match the swap chain".to_string(),
            ));
        }
        let swap_xkey_inner: BoltzSwapMasterKey = swap_master_key.try_into()?;
        let claim_kps = swap_xkey_inner.derive_swapkey(index)?;
        let claim_keypair = KeyPair::from(claim_kps);
        let preimage: Preimage = Preimage::from_swap_key(&claim_kps);
        let ckp: Keypair = claim_keypair.clone().try_into()?;
        let claim_public_key = PublicKey {
            compressed: true,
            inner: claim_kps.public_key(),
        };
        let boltz_url = ensure_boltz_url(&boltz_url, Network::from(network) != Network::Mainnet)
            .map_err(|e| BoltzError::new("Network".to_string(), e))?;
        let boltz_client = BoltzApiClientV2::new(boltz_url.clone(), Some(HTTP_TIMEOUT));
        let create_reverse_req = if out_address.is_some() {
            let address = out_address.unwrap();
            boltz_client::swaps::boltz::CreateReverseRequest {
                invoice_amount: Some(out_amount as u64),
                from: "BTC".to_string(),
                to: "BTC".to_string(),
                preimage_hash: Some(preimage.sha256),
                claim_public_key,
                referral_id: referral_id.clone(),
                address: Some(address.clone()),
                address_signature: Some(magic_routing::sign_address(&address, &ckp)?.to_string()),
                webhook: None,
                description: description,
                description_hash: None,
                invoice: None,
            }
        } else {
            boltz_client::swaps::boltz::CreateReverseRequest {
                invoice_amount: Some(out_amount),
                from: "BTC".to_string(),
                to: "BTC".to_string(),
                preimage_hash: Some(preimage.sha256),
                claim_public_key,
                referral_id: referral_id.clone(),
                address: None,
                address_signature: None,
                description: None,
                description_hash: None,
                webhook: None,
                invoice: None,
            }
        };
        let all_chains: AllChains = network.into();
        let bitcoin_chain = match all_chains {
            AllChains::Bitcoin(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Bitcoin chain but got Liquid chain".to_string(),
                ))
            }
        };
        let create_swap_response = boltz_client.post_reverse_req(create_reverse_req).await?;
        let preimage_boltz: Preimage = preimage.clone().into();
        create_swap_response.validate(&preimage_boltz, &claim_public_key, all_chains.into())?;
        let swap_script =
            BtcSwapScript::reverse_from_swap_resp(&create_swap_response, claim_public_key)?;
        let script_address = swap_script.to_address(bitcoin_chain)?.to_string();
        Ok(BtcLnSwap::new_with_expected_onchain_amount(
            create_swap_response.id,
            swap_type,
            network.into(),
            claim_keypair,
            index,
            preimage.into(),
            swap_script.into(),
            create_swap_response.invoice.unwrap_or_default(),
            script_address,
            out_amount,
            strip_protocol_prefix(&electrum_url),
            boltz_url.clone(),
            referral_id,
            (create_swap_response.onchain_amount > 0)
                .then_some(create_swap_response.onchain_amount),
        ))
    }
    /// Used to claim a reverse swap.
    pub async fn claim(
        &self,
        out_address: String,
        miner_fee: TxFee,
        try_cooperate: bool,
        electrum_settings: Option<ElectrumSettings>,
    ) -> Result<String, BoltzError> {
        if self.kind == SwapType::Submarine {
            return Err(BoltzError {
                kind: "Input".to_string(),
                message: "Submarine swaps are not claimable".to_string(),
            });
        } else {
            ()
        }
        let id: String = self.id.clone();
        let all_chains: AllChains = self.network.into();
        let bitcoin_chain = match all_chains {
            AllChains::Bitcoin(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Bitcoin chain but got Liquid chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config = ElectrumBitcoinClient::new(
            bitcoin_chain,
            &electrum_url,
            tls,
            validate_domain,
            timeout,
        )?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let swap_script: BtcSwapScript = self.swap_script.clone().try_into()?;
        let script_balance = match swap_script.get_balance(&network_config).await {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        if script_balance.0 > 0 || script_balance.1 > 0 {
            let tx = match BtcSwapTx::new_claim(
                swap_script,
                out_address,
                &network_config,
                &boltz_client,
                self.id.clone(),
            )
            .await
            {
                Ok(result) => result,
                Err(e) => return Err(e.into()),
            };
            if let Some(expected_amount) = self.expected_onchain_amount {
                tx.validate_lockup_amount(expected_amount)?;
            }
            let ckp: Keypair = self.keys.clone().try_into()?;
            let preimage: Preimage = self.preimage.clone().try_into()?;
            let signed: Transaction = match tx
                .sign_claim(
                    &ckp,
                    &preimage,
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
        } else {
            return Err(BoltzError {
                kind: "Script".to_string(),
                message: "Script is not funded yet!".to_string(),
            });
        }
    }
    /// Used to refund a failed submarine swap.
    pub async fn refund(
        &self,
        out_address: String,
        miner_fee: TxFee,
        try_cooperate: bool,
        electrum_settings: Option<ElectrumSettings>,
    ) -> Result<String, BoltzError> {
        if self.kind == SwapType::Reverse {
            return Err(BoltzError {
                kind: "Input".to_string(),
                message: "Reverse swaps are not refundable".to_string(),
            });
        } else {
            ()
        }
        let all_chains: AllChains = self.network.into();
        let bitcoin_chain = match all_chains {
            AllChains::Bitcoin(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Bitcoin chain but got Liquid chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config = ElectrumBitcoinClient::new(
            bitcoin_chain,
            &electrum_url,
            tls,
            validate_domain,
            timeout,
        )?;
        let swap_script: BtcSwapScript = self.swap_script.clone().try_into()?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let id: String = self.id.clone();
        let script_balance = match swap_script.get_balance(&network_config).await {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        if script_balance.0 > 0 || script_balance.1 > 0 {
            let tx = match BtcSwapTx::new_refund(
                swap_script.clone(),
                &out_address,
                &network_config,
                &boltz_client,
                self.id.clone(),
            )
            .await
            {
                Ok(result) => result,
                Err(e) => return Err(e.into()),
            };
            let ckp: Keypair = self.keys.clone().try_into()?;
            let signed = match tx
                .sign_refund(
                    &ckp,
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
        } else {
            return Err(BoltzError {
                kind: "Script".to_string(),
                message: "Script is not funded yet!".to_string(),
            });
        }
    }
    /// Broadcast using your own electrum server that was used to create the swap
    pub async fn broadcast_local(
        &self,
        signed_hex: String,
        electrum_settings: Option<ElectrumSettings>,
    ) -> Result<String, BoltzError> {
        let signed_bytes = hex::decode(&signed_hex)
            .map_err(|e| BoltzError::new("HexDecode".to_string(), e.to_string()))?;
        let all_chains: AllChains = self.network.into();
        let bitcoin_chain = match all_chains {
            AllChains::Bitcoin(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Bitcoin chain but got Liquid chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config = ElectrumBitcoinClient::new(
            bitcoin_chain,
            &electrum_url,
            tls,
            validate_domain,
            timeout,
        )?;
        let transaction = Transaction::consensus_decode(&mut &signed_bytes[..])
            .map_err(|e| BoltzError::new("Bitcoin".to_string(), e.to_string()))?;

        let txid: Txid = match network_config.broadcast_tx(&transaction).await {
            Ok(r) => r,
            Err(e) => return Err(BoltzError::new("Electrum".to_string(), format!("{:?}", e))),
        };
        Ok(txid.to_string())
    }
    /// Broadcast using boltz's electrum server
    pub async fn broadcast_boltz(&self, signed_hex: String) -> Result<String, BoltzError> {
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let txid = match boltz_client
            .broadcast_tx(self.network.into(), &signed_hex)
            .await
        {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        Ok(extract_id(txid)?)
    }
    /// Get the size of the claim transaction. Can be used to estimate the absolute miner fees required, given a fee rate.
    pub async fn claim_tx_size(
        &self,
        is_cooperative: bool,
        electrum_settings: Option<ElectrumSettings>,
    ) -> Result<usize, BoltzError> {
        if self.kind == SwapType::Submarine {
            return Err(BoltzError {
                kind: "Input".to_string(),
                message: "Submarine swaps are not claimable".to_string(),
            });
        } else {
            ()
        }
        let all_chains: AllChains = self.network.into();
        let bitcoin_chain = match all_chains {
            AllChains::Bitcoin(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Bitcoin chain but got Liquid chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config = ElectrumBitcoinClient::new(
            bitcoin_chain,
            &electrum_url,
            tls,
            validate_domain,
            timeout,
        )?;
        // okay to use script address, we are just chekcing size
        let swap_script: BtcSwapScript = self.swap_script.clone().try_into()?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));

        let tx = match BtcSwapTx::new_claim(
            swap_script.clone(),
            self.script_address.clone(),
            &network_config,
            &boltz_client,
            self.id.clone(),
        )
        .await
        {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        let ckp: Keypair = self.keys.clone().try_into()?;
        let size = match tx.size(&ckp, is_cooperative) {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        Ok(size)
    }
    /// Get the size of the refund transaction. Can be used to estimate the absolute miner fees required, given a fee rate.
    pub async fn refund_tx_size(
        &self,
        is_cooperative: bool,
        electrum_settings: Option<ElectrumSettings>,
    ) -> Result<usize, BoltzError> {
        if self.kind == SwapType::Reverse {
            return Err(BoltzError {
                kind: "Input".to_string(),
                message: "Reverse swaps are not refundable".to_string(),
            });
        } else {
            ()
        }
        let all_chains: AllChains = self.network.into();
        let bitcoin_chain = match all_chains {
            AllChains::Bitcoin(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Bitcoin chain but got Liquid chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config = ElectrumBitcoinClient::new(
            bitcoin_chain,
            &electrum_url,
            tls,
            validate_domain,
            timeout,
        )?;
        // okay to use script address, we are just chekcing size
        let swap_script: BtcSwapScript = self.swap_script.clone().try_into()?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));

        let tx = match BtcSwapTx::new_refund(
            swap_script.clone(),
            &self.script_address,
            &network_config,
            &boltz_client,
            self.id.clone(),
        )
        .await
        {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        let ckp: Keypair = self.keys.clone().try_into()?;
        let size = match tx.size(&ckp, is_cooperative) {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        Ok(size)
    }
    /// Get the preimage of the lightning invoice for a submarine swap
    pub async fn get_preimage(&self) -> Result<String, BoltzError> {
        if self.kind == SwapType::Reverse {
            return Err(BoltzError {
                kind: "Input".to_string(),
                message: "Cannot get preimage of reverse swap".to_string(),
            });
        }
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let response = boltz_client.get_submarine_preimage(&self.id).await?;
        let preimage = response.preimage.clone();
        Ok(preimage)
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
