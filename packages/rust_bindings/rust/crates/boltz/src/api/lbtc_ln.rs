use crate::util::{
    ensure_boltz_url, ensure_http_prefix, force_https, get_electrum_configs, strip_protocol_prefix,
    HTTP_TIMEOUT,
};
use std::str::FromStr;

use super::{
    error::BoltzError,
    fees::TxFee,
    secrets::{KeyPair, SwapMasterKey},
    types::{Chain, ElectrumSettings, LBtcSwapScriptStr, Network, PreImage, SwapType},
};
use boltz_client::util::secrets::{Preimage, SwapMasterKey as BoltzSwapMasterKey};
use boltz_client::{
    boltz::Cooperative,
    elements::{encode::Decodable, hashes::hex::DisplayHex, Transaction},
    network::{electrum::ElectrumLiquidClient, Chain as AllChains, LiquidClient},
    swaps::{boltz::BoltzApiClientV2, magic_routing, SwapScript},
    Keypair, LBtcSwapScript, LBtcSwapTx, PublicKey, Serialize,
};
use serde_json::Value;

/// Liquid-Lightning Swap Class
#[derive(Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub struct LbtcLnSwap {
    pub id: String,
    pub kind: SwapType,
    pub network: Chain,
    pub keys: KeyPair,
    pub key_index: u64,
    pub preimage: PreImage,
    pub swap_script: LBtcSwapScriptStr,
    pub invoice: String,
    pub out_amount: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub expected_onchain_amount: Option<u64>,
    pub script_address: String,
    pub blinding_key: String,
    pub electrum_url: String,
    pub boltz_url: String,
    pub referral_id: Option<String>,
}

impl LbtcLnSwap {
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
        swap_script: LBtcSwapScriptStr,
        invoice: String,
        out_amount: u64,
        out_address: String,
        blinding_key: String,
        electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
    ) -> LbtcLnSwap {
        Self::new_with_expected_onchain_amount(
            id,
            kind,
            network,
            keys,
            key_index,
            preimage,
            swap_script,
            invoice,
            out_amount,
            out_address,
            blinding_key,
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
        swap_script: LBtcSwapScriptStr,
        invoice: String,
        out_amount: u64,
        out_address: String,
        blinding_key: String,
        electrum_url: String,
        boltz_url: String,
        referral_id: Option<String>,
        expected_onchain_amount: Option<u64>,
    ) -> LbtcLnSwap {
        LbtcLnSwap {
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
            out_amount,
            expected_onchain_amount,
            blinding_key,
            script_address: out_address,
            referral_id: Some(referral_id.unwrap_or_default()),
        }
    }
    /// Used to create the class when starting a submarine swap to pay a lightning invoice with Liquid.
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
        // pair_hash: String,
    ) -> Result<LbtcLnSwap, BoltzError> {
        let swap_type = SwapType::Submarine;
        if network != swap_master_key.network.liquid() {
            return Err(BoltzError::new(
                "Network".to_string(),
                "Swap master key network does not match the swap chain".to_string(),
            ));
        }
        let swap_xkey_inner: BoltzSwapMasterKey = swap_master_key.try_into()?;
        let refund_kps = swap_xkey_inner.derive_liquid_swapkey(index)?;
        let refund_keypair = KeyPair::from(refund_kps);
        let preimage: PreImage = match PreImage::from_invoice_str(&invoice) {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        let boltz_url = ensure_boltz_url(&boltz_url, Network::from(network) != Network::Mainnet)
            .map_err(|e| BoltzError::new("Network".to_string(), e))?;
        let boltz_client = BoltzApiClientV2::new(boltz_url.clone(), Some(HTTP_TIMEOUT));
        let create_swap_req = boltz_client::swaps::boltz::CreateSubmarineRequest {
            from: "L-BTC".to_string(),
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
        let response = boltz_client.post_swap_req(&create_swap_req).await?;
        response.validate(&invoice, &refund_pubkey, network.into())?;
        let swap_script =
            LBtcSwapScript::submarine_from_swap_resp(&response, refund_kps.public_key().into())?;
        let all_chains: AllChains = network.into();
        let liquid_chain = match all_chains {
            AllChains::Liquid(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Liquid chain but got Bitcoin chain".to_string(),
                ))
            }
        };
        let script_address = swap_script.to_address(liquid_chain)?.to_string();
        Ok(LbtcLnSwap::new_with_expected_onchain_amount(
            response.id,
            swap_type,
            network,
            refund_keypair,
            index,
            preimage.into(),
            swap_script.clone().into(),
            invoice,
            response.expected_amount,
            script_address,
            swap_script.blinding_key.display_secret().to_string(),
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
        let swap_script: LBtcSwapScript = self.swap_script.clone().try_into()?;
        let ckp: Keypair = self.keys.clone().try_into()?;
        SwapScript::from_liquid(swap_script)
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
        let swap_script: LBtcSwapScript = self.swap_script.clone().try_into()?;
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

    /// Used to create the class when starting a reverse swap to receive Liquid via Lightning.
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
        // pair_hash: String,
    ) -> Result<LbtcLnSwap, BoltzError> {
        let swap_type = SwapType::Reverse;
        if network != swap_master_key.network.liquid() {
            return Err(BoltzError::new(
                "Network".to_string(),
                "Swap master key network does not match the swap chain".to_string(),
            ));
        }
        let swap_xkey_inner: BoltzSwapMasterKey = swap_master_key.try_into()?;
        let claim_kps = swap_xkey_inner.derive_liquid_swapkey(index)?;
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
                invoice_amount: Some(out_amount),
                from: "BTC".to_string(),
                to: "L-BTC".to_string(),
                preimage_hash: Some(preimage.sha256),
                claim_public_key,
                referral_id: referral_id.clone(),
                address: Some(address.clone()),
                address_signature: Some(magic_routing::sign_address(&address, &ckp)?.to_string()),
                description: description,
                description_hash: None,
                webhook: None,
                invoice: None,
            }
        } else {
            boltz_client::swaps::boltz::CreateReverseRequest {
                invoice_amount: Some(out_amount),
                from: "BTC".to_string(),
                to: "L-BTC".to_string(),
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
        let liquid_chain = match all_chains {
            AllChains::Liquid(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Liquid chain but got Bitcoin chain".to_string(),
                ))
            }
        };
        let response = boltz_client.post_reverse_req(create_reverse_req).await?;
        let invoice = response.invoice.clone().unwrap_or_default();
        let preimage_boltz: Preimage = preimage.clone().into();
        response.validate(&preimage_boltz, &claim_public_key, network.into())?;
        let swap_script = LBtcSwapScript::reverse_from_swap_resp(&response, claim_public_key)?;
        let script_address = swap_script.to_address(liquid_chain)?.to_string();
        Ok(LbtcLnSwap::new_with_expected_onchain_amount(
            response.id,
            swap_type,
            network,
            claim_keypair,
            index,
            preimage.into(),
            swap_script.clone().into(),
            invoice,
            out_amount,
            script_address,
            swap_script.blinding_key.display_secret().to_string(),
            strip_protocol_prefix(&electrum_url),
            boltz_url.clone(),
            referral_id,
            (response.onchain_amount > 0).then_some(response.onchain_amount),
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
        let all_chains: AllChains = self.network.into();
        let liquid_chain = match all_chains {
            AllChains::Liquid(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Liquid chain but got Bitcoin chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config =
            ElectrumLiquidClient::new(liquid_chain, &electrum_url, tls, validate_domain, timeout)?;
        let id: String = self.id.clone();
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let swap_script: LBtcSwapScript = self.swap_script.clone().try_into()?;
        let tx = match LBtcSwapTx::new_claim(
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
            tx.validate_lockup_amount(liquid_chain, expected_amount)?;
        }
        let ckp: Keypair = self.keys.clone().try_into()?;
        let preimage: Preimage = self.preimage.clone().try_into()?;
        let signed = match tx
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
                true,
            )
            .await
        {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };

        Ok(signed.serialize().to_lower_hex_string())
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
        let liquid_chain = match all_chains {
            AllChains::Liquid(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Liquid chain but got Bitcoin chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config =
            ElectrumLiquidClient::new(liquid_chain, &electrum_url, tls, validate_domain, timeout)?;
        let swap_script: LBtcSwapScript = self.swap_script.clone().try_into()?;
        let boltz_client =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));
        let id = self.id.clone();
        let tx = match LBtcSwapTx::new_refund(
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
                true,
            )
            .await
        {
            Ok(result) => result,
            Err(e) => return Err(e.into()),
        };
        Ok(signed.serialize().to_lower_hex_string())
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
        let liquid_chain = match all_chains {
            AllChains::Liquid(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Liquid chain but got Bitcoin chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config =
            ElectrumLiquidClient::new(liquid_chain, &electrum_url, tls, validate_domain, timeout)?;
        let transaction = Transaction::consensus_decode(&mut &signed_bytes[..])
            .map_err(|e| BoltzError::new("Bitcoin".to_string(), e.to_string()))?;
        let txid = match network_config.broadcast_tx(&transaction).await {
            Ok(r) => r,
            Err(e) => return Err(BoltzError::new("Electrum".to_string(), format!("{:?}", e))),
        };
        Ok(txid.to_string())
    }
    /// Broadcast using boltz's electrum server
    pub async fn broadcast_boltz(&self, signed_hex: String) -> Result<String, BoltzError> {
        let boltz_client: BoltzApiClientV2 =
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
        let liquid_chain = match all_chains {
            AllChains::Liquid(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Liquid chain but got Bitcoin chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config =
            ElectrumLiquidClient::new(liquid_chain, &electrum_url, tls, validate_domain, timeout)?;
        let swap_script: LBtcSwapScript = self.swap_script.clone().try_into()?;
        let boltz_client: BoltzApiClientV2 =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));

        let tx = match LBtcSwapTx::new_claim(
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

        let size = match tx.size(&ckp, is_cooperative, true) {
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
        let liquid_chain = match all_chains {
            AllChains::Liquid(inner_chain) => inner_chain,
            _ => {
                return Err(BoltzError::new(
                    "ChainType".to_string(),
                    "Expected Liquid chain but got Bitcoin chain".to_string(),
                ))
            }
        };
        let (electrum_url, tls, validate_domain, timeout) =
            get_electrum_configs(electrum_settings, &self.electrum_url);
        let network_config =
            ElectrumLiquidClient::new(liquid_chain, &electrum_url, tls, validate_domain, timeout)?;
        let swap_script: LBtcSwapScript = self.swap_script.clone().try_into()?;
        let boltz_client: BoltzApiClientV2 =
            BoltzApiClientV2::new(ensure_http_prefix(&self.boltz_url), Some(HTTP_TIMEOUT));

        let tx = match LBtcSwapTx::new_refund(
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

        let size = match tx.size(&ckp, is_cooperative, true) {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_v2_reverse() {
        // ...existing code...
    }

    #[test]
    fn test_lbtc_ln_swap_from_json() {
        let json_str: &str = r#"{"id":"U36attpPqMUo","kind":"Submarine","network":"Liquid","keys":{"secret_key":"5207026dc10ed9e698a210fa33eda0593cc33e02ef9179627c87717b11db70ed","public_key":"037f4e416e89dbe06dbdd73e9e7046f38c5ed807e5dc6d6659fa97bc42bca0d542"},"key_index":12,"preimage":{"value":"","sha256":"b2e3a7b04d8da12d66d7675e8b49cd9eb0aacb678906ae6041c841afdad18afa","hash160":"afb3f5c2b0a81fa6b5fddaa59f860aee631673f9"},"swap_script":{"swap_type":"Submarine","funding_addrs":"lq1pqv6t4czgftrm2tf8u5z977ysdxjucpepfjhfkj0gr74cex03fn6umma9lf64zdk6vv2jnznjztq68uf48wv3fmuheee665j3a3t5f0d75mfvuuypmtjy","hashlock":"afb3f5c2b0a81fa6b5fddaa59f860aee631673f9","receiver_pubkey":"02b4a11c513f485248cd0f631c582a17cc368b971d6fffa697702b8142a5b7975b","locktime":3343910,"sender_pubkey":"037f4e416e89dbe06dbdd73e9e7046f38c5ed807e5dc6d6659fa97bc42bca0d542","blinding_key":"091ed0fb1420d4e92535b3e627fae4ed14ce164ccab0efe17a5938a816dcb58c","side":null},"invoice":"lnbc10u1pnle5gcpp5kt360vzd3ksj6ekhva0gkjwdn6c24jm83yr2uczpepq6lkk33taqhp5pk24lyjep93uz92uxpc7c3d8s58q5g0xr66fpja5xg7zrq47sf2qcqzzsxqyz5vqsp5wc4yxlh83cnm0zc4w64lren8hmn59jq7jmc9m2m6wcsveumpxvvq9qxpqysgqw58qkad47xdmnca3c4elk9eex9smhk36x768u7zrld5kmwzmaf29ad45503fhkdacc8dnnf00ph6qzwuprwsf7uud83safs5adux8scpv9kkjf","out_amount":1020,"script_address":"lq1pqv6t4czgftrm2tf8u5z977ysdxjucpepfjhfkj0gr74cex03fn6umma9lf64zdk6vv2jnznjztq68uf48wv3fmuheee665j3a3t5f0d75mfvuuypmtjy","blinding_key":"091ed0fb1420d4e92535b3e627fae4ed14ce164ccab0efe17a5938a816dcb58c","electrum_url":"les.bullbitcoin.com:995","boltz_url":"https://api.boltz.exchange/v2","referral_id":""}"#;
        let swap = LbtcLnSwap::from_json(json_str).unwrap();
        assert_eq!(swap.id, "U36attpPqMUo");
        assert_eq!(swap.expected_onchain_amount, None);

        let mut swap_with_amount = swap;
        swap_with_amount.expected_onchain_amount = Some(1_000);
        let serialized = swap_with_amount.to_json().unwrap();
        assert_eq!(
            LbtcLnSwap::from_json(&serialized)
                .unwrap()
                .expected_onchain_amount,
            Some(1_000)
        );
    }
}
