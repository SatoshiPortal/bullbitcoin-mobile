use bitcoin::consensus::deserialize;
use bitcoin::secp256k1::{Secp256k1, Verification};
use bitcoin::sighash::Prevouts;
use bitcoin::{Amount, EcdsaSighashType, Script, ScriptBuf, Transaction, TxOut};
use miniscript::interpreter::{Interpreter, KeySigPair, SatisfiedConstraint};

/// Prevout data for one input of the transaction under verification.
///
/// The caller resolves each input's previous output from its own wallet
/// data; only inputs whose prevouts the caller owns can (and need) be
/// verified.
pub struct TxInputToVerify {
    pub input_index: u32,
    pub prevout_script_pubkey: Vec<u8>,
    pub prevout_value_sat: u64,
}

pub enum TxSignatureVerification {
    /// Every requested input carries a satisfaction whose ECDSA
    /// signature(s) verify over this exact transaction with SIGHASH_ALL,
    /// under a key bound to the prevout script. Such a transaction's
    /// outputs are authenticated by the prevout owner's keys.
    Valid,
    /// At least one requested input failed: signature invalid for this
    /// transaction, key or redeem script not matching the prevout script,
    /// a sighash flag other than SIGHASH_ALL, a non-ECDSA satisfaction,
    /// or no signature at all. An unconfirmed wallet transaction in this
    /// state did not originate from the prevout owner's keys and was
    /// served by the Electrum server (GHSA-6jp4-8v48-cc5v).
    InvalidSignatures { invalid_input_indexes: Vec<u32> },
    /// The transaction bytes or the request could not be processed.
    /// Says nothing about signature validity.
    Malformed { message: String },
}

/// Verifies the input signatures a transaction carries, against the
/// prevouts supplied by the caller. Supports the script types a signature
/// can be checked for without a full script interpreter context: p2pkh,
/// p2wpkh, p2sh-p2wpkh, p2wsh and p2sh miniscript-representable scripts.
/// Taproot inputs are reported as invalid (Prevouts::One is insufficient
/// for the taproot sighash).
pub fn verify_tx_input_signatures(
    tx_bytes: Vec<u8>,
    inputs: Vec<TxInputToVerify>,
) -> TxSignatureVerification {
    let tx: Transaction = match deserialize(&tx_bytes) {
        Ok(tx) => tx,
        Err(e) => {
            return TxSignatureVerification::Malformed {
                message: format!("transaction deserialization failed: {e}"),
            };
        }
    };
    if inputs.is_empty() {
        return TxSignatureVerification::Malformed {
            message: "no inputs requested for verification".to_string(),
        };
    }
    let secp = Secp256k1::verification_only();
    let mut invalid_input_indexes = Vec::new();
    for input in &inputs {
        let index = input.input_index as usize;
        if index >= tx.input.len() {
            return TxSignatureVerification::Malformed {
                message: format!(
                    "input index {} out of bounds for transaction with {} inputs",
                    input.input_index,
                    tx.input.len()
                ),
            };
        }
        let script_pubkey = ScriptBuf::from(input.prevout_script_pubkey.clone());
        if !input_carries_valid_sighash_all_signature(
            &secp,
            &tx,
            index,
            &script_pubkey,
            input.prevout_value_sat,
        ) {
            invalid_input_indexes.push(input.input_index);
        }
    }
    if invalid_input_indexes.is_empty() {
        TxSignatureVerification::Valid
    } else {
        TxSignatureVerification::InvalidSignatures {
            invalid_input_indexes,
        }
    }
}

fn input_carries_valid_sighash_all_signature<C: Verification>(
    secp: &Secp256k1<C>,
    tx: &Transaction,
    index: usize,
    script_pubkey: &Script,
    prevout_value_sat: u64,
) -> bool {
    let txin = &tx.input[index];
    let interpreter = match Interpreter::from_txdata(
        &script_pubkey.to_owned(),
        &txin.script_sig,
        &txin.witness,
        txin.sequence,
        tx.lock_time,
    ) {
        Ok(interpreter) => interpreter,
        Err(_) => return false,
    };
    let prevout = TxOut {
        value: Amount::from_sat(prevout_value_sat),
        script_pubkey: script_pubkey.to_owned(),
    };
    let prevouts = Prevouts::One(index, prevout);
    let mut verified_signatures = 0usize;
    for constraint in interpreter.iter(secp, tx, index, &prevouts) {
        let satisfied = match constraint {
            Ok(satisfied) => satisfied,
            Err(_) => return false,
        };
        match satisfied {
            SatisfiedConstraint::PublicKey { key_sig }
            | SatisfiedConstraint::PublicKeyHash { key_sig, .. } => match key_sig {
                KeySigPair::Ecdsa(_, signature)
                    if signature.sighash_type == EcdsaSighashType::All =>
                {
                    verified_signatures += 1;
                }
                _ => return false,
            },
            _ => {}
        }
    }
    verified_signatures > 0
}

#[cfg(test)]
mod tests {
    use super::*;
    use bitcoin::absolute::LockTime;
    use bitcoin::consensus::serialize;
    use bitcoin::hashes::Hash;
    use bitcoin::secp256k1::{Message, SecretKey};
    use bitcoin::script::PushBytesBuf;
    use bitcoin::sighash::SighashCache;
    use bitcoin::transaction::Version;
    use bitcoin::{
        OutPoint, PublicKey, Sequence, TxIn, Txid, Witness,
    };

    const PREVOUT_SAT: u64 = 100_000;

    fn keypair(seed: u8) -> (SecretKey, PublicKey) {
        let secp = Secp256k1::new();
        let sk = SecretKey::from_slice(&[seed; 32]).unwrap();
        let pk = PublicKey::new(sk.public_key(&secp));
        (sk, pk)
    }

    fn unsigned_tx(recipient_spk: ScriptBuf) -> Transaction {
        Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input: vec![TxIn {
                previous_output: OutPoint {
                    txid: Txid::all_zeros(),
                    vout: 0,
                },
                script_sig: ScriptBuf::new(),
                sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
                witness: Witness::new(),
            }],
            output: vec![TxOut {
                value: Amount::from_sat(90_000),
                script_pubkey: recipient_spk,
            }],
        }
    }

    fn recipient_spk(seed: u8) -> ScriptBuf {
        let (_, pk) = keypair(seed);
        ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap())
    }

    fn sign_p2wpkh(
        tx: &mut Transaction,
        sk: &SecretKey,
        pk: &PublicKey,
        script_code_spk: &Script,
        sighash_type: EcdsaSighashType,
    ) {
        let secp = Secp256k1::new();
        let sighash = SighashCache::new(&*tx)
            .p2wpkh_signature_hash(
                0,
                script_code_spk,
                Amount::from_sat(PREVOUT_SAT),
                sighash_type,
            )
            .unwrap();
        let signature = bitcoin::ecdsa::Signature {
            signature: secp.sign_ecdsa(
                &Message::from_digest(sighash.to_byte_array()),
                sk,
            ),
            sighash_type,
        };
        tx.input[0].witness = Witness::p2wpkh(&signature, &pk.inner);
    }

    fn verify(tx: &Transaction, spk: &Script) -> TxSignatureVerification {
        verify_tx_input_signatures(
            serialize(tx),
            vec![TxInputToVerify {
                input_index: 0,
                prevout_script_pubkey: spk.to_bytes(),
                prevout_value_sat: PREVOUT_SAT,
            }],
        )
    }

    fn assert_valid(result: &TxSignatureVerification) {
        assert!(matches!(result, TxSignatureVerification::Valid));
    }

    fn assert_invalid(result: &TxSignatureVerification) {
        assert!(matches!(
            result,
            TxSignatureVerification::InvalidSignatures { invalid_input_indexes }
                if invalid_input_indexes == &[0]
        ));
    }

    #[test]
    fn p2wpkh_valid_signature_passes() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let mut tx = unsigned_tx(recipient_spk(9));
        sign_p2wpkh(&mut tx, &sk, &pk, &spk, EcdsaSighashType::All);
        assert_valid(&verify(&tx, &spk));
    }

    #[test]
    fn p2wpkh_swapped_output_fails() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let mut tx = unsigned_tx(recipient_spk(9));
        sign_p2wpkh(&mut tx, &sk, &pk, &spk, EcdsaSighashType::All);
        tx.output[0].script_pubkey = recipient_spk(13);
        assert_invalid(&verify(&tx, &spk));
    }

    #[test]
    fn p2wpkh_attacker_key_fails_script_binding() {
        let (_, pk) = keypair(1);
        let (attacker_sk, attacker_pk) = keypair(2);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let mut tx = unsigned_tx(recipient_spk(9));
        sign_p2wpkh(&mut tx, &attacker_sk, &attacker_pk, &spk, EcdsaSighashType::All);
        assert_invalid(&verify(&tx, &spk));
    }

    #[test]
    fn p2wpkh_sighash_none_fails() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let mut tx = unsigned_tx(recipient_spk(9));
        sign_p2wpkh(&mut tx, &sk, &pk, &spk, EcdsaSighashType::None);
        assert_invalid(&verify(&tx, &spk));
    }

    #[test]
    fn p2wpkh_empty_witness_fails() {
        let (_, pk) = keypair(1);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let tx = unsigned_tx(recipient_spk(9));
        assert_invalid(&verify(&tx, &spk));
    }

    #[test]
    fn p2sh_p2wpkh_valid_signature_passes() {
        let (sk, pk) = keypair(1);
        let redeem_script = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let spk = ScriptBuf::new_p2sh(&redeem_script.script_hash());
        let mut tx = unsigned_tx(recipient_spk(9));
        tx.input[0].script_sig = ScriptBuf::builder()
            .push_slice(PushBytesBuf::try_from(redeem_script.to_bytes()).unwrap())
            .into_script();
        sign_p2wpkh(&mut tx, &sk, &pk, &redeem_script, EcdsaSighashType::All);
        assert_valid(&verify(&tx, &spk));
    }

    #[test]
    fn p2sh_p2wpkh_swapped_output_fails() {
        let (sk, pk) = keypair(1);
        let redeem_script = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let spk = ScriptBuf::new_p2sh(&redeem_script.script_hash());
        let mut tx = unsigned_tx(recipient_spk(9));
        tx.input[0].script_sig = ScriptBuf::builder()
            .push_slice(PushBytesBuf::try_from(redeem_script.to_bytes()).unwrap())
            .into_script();
        sign_p2wpkh(&mut tx, &sk, &pk, &redeem_script, EcdsaSighashType::All);
        tx.output[0].script_pubkey = recipient_spk(13);
        assert_invalid(&verify(&tx, &spk));
    }

    #[test]
    fn p2pkh_valid_signature_passes() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2pkh(&pk.pubkey_hash());
        let mut tx = unsigned_tx(recipient_spk(9));
        let secp = Secp256k1::new();
        let sighash = SighashCache::new(&tx)
            .legacy_signature_hash(0, &spk, EcdsaSighashType::All.to_u32())
            .unwrap();
        let signature = bitcoin::ecdsa::Signature {
            signature: secp.sign_ecdsa(
                &Message::from_digest(sighash.to_byte_array()),
                &sk,
            ),
            sighash_type: EcdsaSighashType::All,
        };
        tx.input[0].script_sig = ScriptBuf::builder()
            .push_slice(PushBytesBuf::try_from(signature.to_vec()).unwrap())
            .push_key(&pk)
            .into_script();
        assert_valid(&verify(&tx, &spk));
    }

    #[test]
    fn p2pkh_swapped_output_fails() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2pkh(&pk.pubkey_hash());
        let mut tx = unsigned_tx(recipient_spk(9));
        let secp = Secp256k1::new();
        let sighash = SighashCache::new(&tx)
            .legacy_signature_hash(0, &spk, EcdsaSighashType::All.to_u32())
            .unwrap();
        let signature = bitcoin::ecdsa::Signature {
            signature: secp.sign_ecdsa(
                &Message::from_digest(sighash.to_byte_array()),
                &sk,
            ),
            sighash_type: EcdsaSighashType::All,
        };
        tx.input[0].script_sig = ScriptBuf::builder()
            .push_slice(PushBytesBuf::try_from(signature.to_vec()).unwrap())
            .push_key(&pk)
            .into_script();
        tx.output[0].script_pubkey = recipient_spk(13);
        assert_invalid(&verify(&tx, &spk));
    }

    #[test]
    fn malformed_bytes_reported_as_malformed() {
        let result = verify_tx_input_signatures(
            vec![0xde, 0xad, 0xbe, 0xef],
            vec![TxInputToVerify {
                input_index: 0,
                prevout_script_pubkey: vec![],
                prevout_value_sat: 0,
            }],
        );
        assert!(matches!(result, TxSignatureVerification::Malformed { .. }));
    }

    #[test]
    fn out_of_bounds_index_reported_as_malformed() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let mut tx = unsigned_tx(recipient_spk(9));
        sign_p2wpkh(&mut tx, &sk, &pk, &spk, EcdsaSighashType::All);
        let result = verify_tx_input_signatures(
            serialize(&tx),
            vec![TxInputToVerify {
                input_index: 5,
                prevout_script_pubkey: spk.to_bytes(),
                prevout_value_sat: PREVOUT_SAT,
            }],
        );
        assert!(matches!(result, TxSignatureVerification::Malformed { .. }));
    }

    #[test]
    fn empty_input_list_reported_as_malformed() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let mut tx = unsigned_tx(recipient_spk(9));
        sign_p2wpkh(&mut tx, &sk, &pk, &spk, EcdsaSighashType::All);
        let result = verify_tx_input_signatures(serialize(&tx), vec![]);
        assert!(matches!(result, TxSignatureVerification::Malformed { .. }));
    }

    #[test]
    fn multi_input_reports_only_forged_index() {
        let (sk, pk) = keypair(1);
        let spk = ScriptBuf::new_p2wpkh(&pk.wpubkey_hash().unwrap());
        let mut tx = unsigned_tx(recipient_spk(9));
        tx.input.push(TxIn {
            previous_output: OutPoint {
                txid: Txid::all_zeros(),
                vout: 1,
            },
            script_sig: ScriptBuf::new(),
            sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
            witness: Witness::new(),
        });
        let secp = Secp256k1::new();
        let sighash = SighashCache::new(&tx)
            .p2wpkh_signature_hash(
                0,
                &spk,
                Amount::from_sat(PREVOUT_SAT),
                EcdsaSighashType::All,
            )
            .unwrap();
        let signature = bitcoin::ecdsa::Signature {
            signature: secp.sign_ecdsa(
                &Message::from_digest(sighash.to_byte_array()),
                &sk,
            ),
            sighash_type: EcdsaSighashType::All,
        };
        tx.input[0].witness = Witness::p2wpkh(&signature, &pk.inner);
        let result = verify_tx_input_signatures(
            serialize(&tx),
            vec![
                TxInputToVerify {
                    input_index: 0,
                    prevout_script_pubkey: spk.to_bytes(),
                    prevout_value_sat: PREVOUT_SAT,
                },
                TxInputToVerify {
                    input_index: 1,
                    prevout_script_pubkey: spk.to_bytes(),
                    prevout_value_sat: PREVOUT_SAT,
                },
            ],
        );
        assert!(matches!(
            result,
            TxSignatureVerification::InvalidSignatures { invalid_input_indexes }
                if invalid_input_indexes == vec![1]
        ));
    }
}
