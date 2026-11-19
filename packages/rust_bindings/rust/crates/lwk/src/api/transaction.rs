use std::str::FromStr;

use lwk_wollet::elements::{
    pset::{serialize::Deserialize, PartiallySignedTransaction}, 
    Transaction as ElementsTransaction,
};
use flutter_rust_bridge::frb;

use super::error::LwkError;
use super::types::SizeAndFees;

/// Extract the Transaction Bytes from a PartiallySignedTransaction
pub fn extract_tx_bytes(pset: String) -> anyhow::Result<Vec<u8>, LwkError> {
    let pset = PartiallySignedTransaction::from_str(&pset)?;
    let tx = pset.extract_tx()?;
    let tx_bytes = lwk_wollet::elements::encode::serialize(&tx);
    Ok(tx_bytes)
}

pub fn get_size_and_absolute_fees(pset: String) -> anyhow::Result<SizeAndFees, LwkError> {
    Ok(SizeAndFees::try_from(pset)?)
}

#[derive(Clone, Debug)]
pub struct TxInput {
    pub txid: String,
    pub vout: u32,
    pub script_sig: String,
    pub sequence: u32,
    pub witness: Vec<String>,
    pub is_pegin: bool,
}

#[derive(Clone, Debug)]
pub struct TxOutput {
    pub script_pubkey: String,
    pub asset: Option<String>,
    pub value: Option<u64>,
    pub nonce: Option<String>,
}

#[derive(Clone, Debug)]
pub struct PsetInput {
    pub witness_utxo_script: Option<String>,
    pub witness_utxo_amount: Option<u64>,
    pub witness_utxo_asset: Option<String>,
}

#[derive(Clone, Debug)]
pub struct PsetOutput {
    pub script_pubkey: String,
    pub amount: Option<u64>,
    pub asset: Option<String>,
    pub blinding_key: Option<String>,
}

#[frb(opaque)]
pub struct PartiallySignedElementsTransaction {
    inner: PartiallySignedTransaction,
}

impl PartiallySignedElementsTransaction {
    #[frb(sync)]
    pub fn from_string(pset_string: String) -> anyhow::Result<PartiallySignedElementsTransaction, LwkError> {
        let pset = PartiallySignedTransaction::from_str(&pset_string)
            .map_err(|e| LwkError { msg: e.to_string() })?;
        
        Ok(PartiallySignedElementsTransaction { inner: pset })
    }

    #[frb(sync)]
    pub fn to_string(&self) -> String {
        self.inner.to_string()
    }

    #[frb(sync)]
    pub fn extract_tx(&self) -> anyhow::Result<LiquidTransaction, LwkError> {
        let tx = self.inner.clone()
            .extract_tx()
            .map_err(|e| LwkError { msg: e.to_string() })?;
        
        Ok(LiquidTransaction { inner: tx })
    }

    #[frb(sync)]
    pub fn input_count(&self) -> usize {
        self.inner.inputs().len()
    }

    #[frb(sync)]
    pub fn output_count(&self) -> usize {
        self.inner.outputs().len()
    }

    #[frb(sync)]
    pub fn get_input_utxo_amount(&self, index: usize) -> Option<u64> {
        self.inner.inputs().get(index).and_then(|input| {
            input.witness_utxo.as_ref().and_then(|utxo| {
                if let lwk_wollet::elements::confidential::Value::Explicit(value) = utxo.value {
                    Some(value)
                } else {
                    None
                }
            })
        })
    }

    #[frb(sync)]
    pub fn get_input_utxo_asset(&self, index: usize) -> Option<String> {
        self.inner.inputs().get(index).and_then(|input| {
            input.witness_utxo.as_ref().and_then(|utxo| {
                if let lwk_wollet::elements::confidential::Asset::Explicit(asset) = utxo.asset {
                    Some(asset.to_string())
                } else {
                    None
                }
            })
        })
    }

    #[frb(sync)]
    pub fn get_input_utxo_script(&self, index: usize) -> Option<String> {
        self.inner.inputs().get(index).and_then(|input| {
            input.witness_utxo.as_ref().map(|utxo| {
                hex::encode(utxo.script_pubkey.as_bytes())
            })
        })
    }

    #[frb(sync)]
    pub fn get_output_amount(&self, index: usize) -> Option<u64> {
        self.inner.outputs().get(index).and_then(|output| {
            output.amount
        })
    }

    #[frb(sync)]
    pub fn get_output_asset(&self, index: usize) -> Option<String> {
        self.inner.outputs().get(index).and_then(|output| {
            output.asset.map(|asset| asset.to_string())
        })
    }

    #[frb(sync)]
    pub fn get_output_script(&self, index: usize) -> Option<String> {
        self.inner.outputs().get(index).map(|output| {
            hex::encode(output.script_pubkey.as_bytes())
        })
    }

    #[frb(sync)]
    pub fn get_output_blinding_key(&self, index: usize) -> Option<String> {
        self.inner.outputs().get(index).and_then(|output| {
            output.blinding_key.as_ref().map(|key| {
                key.to_string()
            })
        })
    }

    #[frb(sync)]
    pub fn lock_time(&self) -> Option<u32> {
        self.inner.global.tx_data.fallback_locktime.map(|lt| lt.to_consensus_u32())
    }

    #[frb(sync)]
    pub fn get_input(&self, index: usize) -> Option<PsetInput> {
        self.inner.inputs().get(index).map(|input| {
            PsetInput {
                witness_utxo_script: input.witness_utxo.as_ref().map(|utxo| {
                    hex::encode(utxo.script_pubkey.as_bytes())
                }),
                witness_utxo_amount: input.witness_utxo.as_ref().and_then(|utxo| {
                    if let lwk_wollet::elements::confidential::Value::Explicit(value) = utxo.value {
                        Some(value)
                    } else {
                        None
                    }
                }),
                witness_utxo_asset: input.witness_utxo.as_ref().and_then(|utxo| {
                    if let lwk_wollet::elements::confidential::Asset::Explicit(asset) = utxo.asset {
                        Some(asset.to_string())
                    } else {
                        None
                    }
                }),
            }
        })
    }

    #[frb(sync)]
    pub fn get_inputs(&self) -> Vec<PsetInput> {
        self.inner.inputs().iter().map(|input| {
            PsetInput {
                witness_utxo_script: input.witness_utxo.as_ref().map(|utxo| {
                    hex::encode(utxo.script_pubkey.as_bytes())
                }),
                witness_utxo_amount: input.witness_utxo.as_ref().and_then(|utxo| {
                    if let lwk_wollet::elements::confidential::Value::Explicit(value) = utxo.value {
                        Some(value)
                    } else {
                        None
                    }
                }),
                witness_utxo_asset: input.witness_utxo.as_ref().and_then(|utxo| {
                    if let lwk_wollet::elements::confidential::Asset::Explicit(asset) = utxo.asset {
                        Some(asset.to_string())
                    } else {
                        None
                    }
                }),
            }
        }).collect()
    }

    #[frb(sync)]
    pub fn get_output(&self, index: usize) -> Option<PsetOutput> {
        self.inner.outputs().get(index).map(|output| {
            PsetOutput {
                script_pubkey: hex::encode(output.script_pubkey.as_bytes()),
                amount: output.amount,
                asset: output.asset.map(|asset| asset.to_string()),
                blinding_key: output.blinding_key.as_ref().map(|key| key.to_string()),
            }
        })
    }

    #[frb(sync)]
    pub fn get_outputs(&self) -> Vec<PsetOutput> {
        self.inner.outputs().iter().map(|output| {
            PsetOutput {
                script_pubkey: hex::encode(output.script_pubkey.as_bytes()),
                amount: output.amount,
                asset: output.asset.map(|asset| asset.to_string()),
                blinding_key: output.blinding_key.as_ref().map(|key| key.to_string()),
            }
        }).collect()
    }
}

#[frb(opaque)]
pub struct LiquidTransaction {
    inner: ElementsTransaction,
}

impl LiquidTransaction {
    #[frb(sync)]
    pub fn from_pset(pset_string: String) -> anyhow::Result<LiquidTransaction, LwkError> {
        let pset = PartiallySignedTransaction::from_str(&pset_string)
            .map_err(|e| LwkError { msg: e.to_string() })?;
        let tx = pset
            .extract_tx()
            .map_err(|e| LwkError { msg: e.to_string() })?;
        
        Ok(LiquidTransaction { inner: tx })
    }

    #[frb(sync)]
    pub fn from_bytes(tx_bytes: Vec<u8>) -> anyhow::Result<LiquidTransaction, LwkError> {
        let tx = ElementsTransaction::deserialize(&tx_bytes)
            .map_err(|e| LwkError { msg: e.to_string() })?;
        
        Ok(LiquidTransaction { inner: tx })
    }

    #[frb(sync)]
    pub fn txid(&self) -> String {
        self.inner.txid().to_string()
    }

    #[frb(sync)]
    pub fn vsize(&self) -> usize {
        self.inner.discount_vsize()
    }

    #[frb(sync)]
    pub fn weight(&self) -> usize {
        self.inner.discount_weight()
    }

    #[frb(sync)]
    pub fn fee(&self) -> u64 {
        self.inner.all_fees().values().sum()
    }

    #[frb(sync)]
    pub fn to_bytes(&self) -> Vec<u8> {
        lwk_wollet::elements::encode::serialize(&self.inner)
    }

    #[frb(sync)]
    pub fn version(&self) -> u32 {
        self.inner.version
    }

    #[frb(sync)]
    pub fn lock_time(&self) -> u32 {
        self.inner.lock_time.to_consensus_u32()
    }

    #[frb(sync)]
    pub fn input_count(&self) -> usize {
        self.inner.input.len()
    }

    #[frb(sync)]
    pub fn output_count(&self) -> usize {
        self.inner.output.len()
    }

    #[frb(sync)]
    pub fn get_output_script_pubkey(&self, index: usize) -> Option<String> {
        self.inner.output.get(index).map(|out| hex::encode(out.script_pubkey.as_bytes()))
    }

    #[frb(sync)]
    pub fn get_output_asset(&self, index: usize) -> Option<String> {
        self.inner.output.get(index).and_then(|out| {
            if let lwk_wollet::elements::confidential::Asset::Explicit(asset) = out.asset {
                Some(asset.to_string())
            } else {
                None
            }
        })
    }

    #[frb(sync)]
    pub fn get_output_value(&self, index: usize) -> Option<u64> {
        self.inner.output.get(index).and_then(|out| {
            if let lwk_wollet::elements::confidential::Value::Explicit(value) = out.value {
                Some(value)
            } else {
                None
            }
        })
    }

    #[frb(sync)]
    pub fn get_output_nonce(&self, index: usize) -> Option<String> {
        self.inner.output.get(index).and_then(|out| {
            if let lwk_wollet::elements::confidential::Nonce::Confidential(pk) = out.nonce {
                Some(pk.to_string())
            } else {
                None
            }
        })
    }

    #[frb(sync)]
    pub fn is_coinbase(&self) -> bool {
        self.inner.is_coinbase()
    }

    #[frb(sync)]
    pub fn get_input(&self, index: usize) -> Option<TxInput> {
        self.inner.input.get(index).map(|input| {
            TxInput {
                txid: input.previous_output.txid.to_string(),
                vout: input.previous_output.vout,
                script_sig: hex::encode(input.script_sig.as_bytes()),
                sequence: input.sequence.0,
                witness: input.witness.script_witness.iter().map(|w| hex::encode(w)).collect(),
                is_pegin: input.is_pegin,
            }
        })
    }

    #[frb(sync)]
    pub fn get_inputs(&self) -> Vec<TxInput> {
        self.inner.input.iter().map(|input| {
            TxInput {
                txid: input.previous_output.txid.to_string(),
                vout: input.previous_output.vout,
                script_sig: hex::encode(input.script_sig.as_bytes()),
                sequence: input.sequence.0,
                witness: input.witness.script_witness.iter().map(|w| hex::encode(w)).collect(),
                is_pegin: input.is_pegin,
            }
        }).collect()
    }

    #[frb(sync)]
    pub fn get_output(&self, index: usize) -> Option<TxOutput> {
        self.inner.output.get(index).map(|out| {
            TxOutput {
                script_pubkey: hex::encode(out.script_pubkey.as_bytes()),
                asset: if let lwk_wollet::elements::confidential::Asset::Explicit(asset) = out.asset {
                    Some(asset.to_string())
                } else {
                    None
                },
                value: if let lwk_wollet::elements::confidential::Value::Explicit(value) = out.value {
                    Some(value)
                } else {
                    None
                },
                nonce: if let lwk_wollet::elements::confidential::Nonce::Confidential(pk) = out.nonce {
                    Some(pk.to_string())
                } else {
                    None
                },
            }
        })
    }

    #[frb(sync)]
    pub fn get_outputs(&self) -> Vec<TxOutput> {
        self.inner.output.iter().map(|out| {
            TxOutput {
                script_pubkey: hex::encode(out.script_pubkey.as_bytes()),
                asset: if let lwk_wollet::elements::confidential::Asset::Explicit(asset) = out.asset {
                    Some(asset.to_string())
                } else {
                    None
                },
                value: if let lwk_wollet::elements::confidential::Value::Explicit(value) = out.value {
                    Some(value)
                } else {
                    None
                },
                nonce: if let lwk_wollet::elements::confidential::Nonce::Confidential(pk) = out.nonce {
                    Some(pk.to_string())
                } else {
                    None
                },
            }
        }).collect()
    }
}


#[cfg(test)]
mod tests {
    use super::*;
    use lwk_wollet::elements::{AssetId, LockTime, Script, TxIn, TxOut};

    const P2WPKH_SCRIPT: &str = "0014b4620e4b3d559352bdf1f313898fd040c2851850";

    #[test]
    fn scripts_and_witnesses_are_lowercase_hex() {
        let script = Script::from(hex::decode(P2WPKH_SCRIPT).unwrap());
        let mut input = TxIn::default();
        input.script_sig = script.clone();
        input.witness.script_witness = vec![vec![0xab, 0xcd]].into();
        let mut output = TxOut::new_fee(1, AssetId::default());
        output.script_pubkey = script;
        let tx = LiquidTransaction {
            inner: ElementsTransaction {
                version: 2,
                lock_time: LockTime::ZERO,
                input: vec![input],
                output: vec![output],
            },
        };

        assert_eq!(tx.get_output_script_pubkey(0).unwrap(), P2WPKH_SCRIPT);
        assert_eq!(tx.get_output(0).unwrap().script_pubkey, P2WPKH_SCRIPT);
        assert_eq!(tx.get_outputs()[0].script_pubkey, P2WPKH_SCRIPT);
        assert_eq!(tx.get_input(0).unwrap().script_sig, P2WPKH_SCRIPT);
        assert_eq!(tx.get_inputs()[0].script_sig, P2WPKH_SCRIPT);
        assert_eq!(tx.get_input(0).unwrap().witness, vec!["abcd".to_string()]);
    }
}
