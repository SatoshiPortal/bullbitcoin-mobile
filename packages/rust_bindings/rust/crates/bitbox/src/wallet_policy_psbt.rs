use std::collections::HashSet;

use anyhow::{bail, Result};
use bitcoin::bip32::{ChildNumber, DerivationPath, KeySource};
use bitcoin::psbt::Psbt;
use bitcoin::secp256k1::{PublicKey, Secp256k1, XOnlyPublicKey};
use bitcoin::sighash::{EcdsaSighashType, TapSighashType};
use bitcoin::taproot::TapLeafHash;

use crate::wallet_policy::WalletPolicyDeviceKey;

pub(crate) fn filter_psbt_for_device_keys<'a>(
    psbt: &Psbt,
    device_keys: &'a [WalletPolicyDeviceKey],
) -> Result<Option<(Psbt, &'a WalletPolicyDeviceKey)>> {
    let mut filtered = psbt.clone();
    let mut needs_signature = false;
    let mut signing_device_key = None;

    for input in &mut filtered.inputs {
        let matching_public_keys = input
            .bip32_derivation
            .iter()
            .filter_map(|(public_key, source)| {
                device_keys
                    .iter()
                    .find(|key| key.matches_public_key(public_key, source))
                    .map(|device_key| (*public_key, device_key))
            })
            .collect::<Vec<_>>();
        let internal_key = input.tap_internal_key;
        let selected_leaf_hashes = input
            .tap_scripts
            .values()
            .map(|(script, version)| TapLeafHash::from_script(script, *version))
            .collect::<HashSet<_>>();
        input
            .tap_key_origins
            .retain(|xonly, (leaf_hashes, source)| {
                if !device_keys
                    .iter()
                    .any(|key| key.root_fingerprint == source.0)
                {
                    return true;
                }
                if !device_keys
                    .iter()
                    .any(|key| key.matches_xonly_public_key(xonly, source))
                {
                    return false;
                }
                if internal_key == Some(*xonly) && leaf_hashes.is_empty() {
                    return true;
                }
                leaf_hashes.retain(|hash| selected_leaf_hashes.contains(hash));
                !leaf_hashes.is_empty()
            });
        let matching_taproot_keys = input
            .tap_key_origins
            .iter()
            .filter_map(|(xonly, origin @ (_, source))| {
                device_keys
                    .iter()
                    .find(|key| key.matches_xonly_public_key(xonly, source))
                    .map(|device_key| (xonly, origin, device_key))
            })
            .collect::<Vec<_>>();
        if matching_public_keys.is_empty() && matching_taproot_keys.is_empty() {
            return Ok(None);
        }
        if !matching_public_keys.is_empty() && !matching_taproot_keys.is_empty() {
            bail!("a PSBT input cannot mix SegWit and Taproot origins for one BitBox key");
        }
        let selected_public_key = matching_public_keys
            .iter()
            .find(|(key, _)| {
                !input
                    .partial_sigs
                    .contains_key(&bitcoin::PublicKey::new(*key))
            })
            .or(matching_public_keys.first())
            .copied();
        let selected_taproot_key = matching_taproot_keys
            .iter()
            .find(|(xonly, (leaf_hashes, _), _)| {
                if internal_key == Some(**xonly) && leaf_hashes.is_empty() {
                    input.tap_key_sig.is_none()
                } else {
                    leaf_hashes
                        .iter()
                        .any(|hash| !input.tap_script_sigs.contains_key(&(**xonly, *hash)))
                }
            })
            .or(matching_taproot_keys.first())
            .map(|(xonly, _, device_key)| (**xonly, *device_key));
        let public_key_needs_signature = selected_public_key.is_some_and(|(key, _)| {
            !input
                .partial_sigs
                .contains_key(&bitcoin::PublicKey::new(key))
        });
        let taproot_key_needs_signature = selected_taproot_key.is_some_and(|(xonly, _)| {
            let (leaf_hashes, _) = input.tap_key_origins.get(&xonly).unwrap();
            if internal_key == Some(xonly) && leaf_hashes.is_empty() {
                input.tap_key_sig.is_none()
            } else {
                leaf_hashes
                    .iter()
                    .any(|hash| !input.tap_script_sigs.contains_key(&(xonly, *hash)))
            }
        });
        if public_key_needs_signature || taproot_key_needs_signature {
            signing_device_key.get_or_insert(
                selected_public_key
                    .map(|(_, device_key)| device_key)
                    .or_else(|| selected_taproot_key.map(|(_, device_key)| device_key))
                    .unwrap(),
            );
            needs_signature = true;
        }
        input.bip32_derivation.retain(|public_key, source| {
            !device_keys
                .iter()
                .any(|key| key.root_fingerprint == source.0)
                || selected_public_key.is_some_and(|(selected, _)| selected == *public_key)
        });
        input.tap_key_origins.retain(|xonly, (_, source)| {
            !device_keys
                .iter()
                .any(|key| key.root_fingerprint == source.0)
                || selected_taproot_key.is_some_and(|(selected, _)| selected == *xonly)
        });
    }
    if !needs_signature {
        return Ok(None);
    }

    for output in &mut filtered.outputs {
        output.bip32_derivation.retain(|public_key, source| {
            !device_keys
                .iter()
                .any(|key| key.root_fingerprint == source.0)
                || device_keys
                    .iter()
                    .any(|key| key.matches_public_key(public_key, source))
        });
        let internal_key = output.tap_internal_key;
        output
            .tap_key_origins
            .retain(|xonly, (leaf_hashes, source)| {
                if !device_keys
                    .iter()
                    .any(|key| key.root_fingerprint == source.0)
                {
                    return true;
                }
                if !device_keys
                    .iter()
                    .any(|key| key.matches_xonly_public_key(xonly, source))
                {
                    return false;
                }
                if internal_key != Some(*xonly) && leaf_hashes.len() > 1 {
                    leaf_hashes.truncate(1);
                }
                true
            });
    }
    Ok(Some((filtered, signing_device_key.unwrap())))
}

pub(crate) fn validate_supported_sighashes(psbt: &Psbt) -> Result<()> {
    for (input_index, input) in psbt.inputs.iter().enumerate() {
        let Some(sighash_type) = input.sighash_type else {
            continue;
        };
        let utxo = psbt.spend_utxo(input_index)?;
        let is_supported = if utxo.script_pubkey.is_p2tr() {
            sighash_type.taproot_hash_ty() == Ok(TapSighashType::Default)
        } else {
            sighash_type.ecdsa_hash_ty() == Ok(EcdsaSighashType::All)
        };
        if !is_supported {
            bail!("BitBox does not support the requested sighash type");
        }
    }
    Ok(())
}

pub(crate) fn restore_existing_signatures(signed: &mut Psbt, existing: &Psbt) {
    for (signed_input, existing_input) in signed.inputs.iter_mut().zip(&existing.inputs) {
        signed_input
            .partial_sigs
            .extend(existing_input.partial_sigs.clone());
        if existing_input.tap_key_sig.is_some() {
            signed_input.tap_key_sig = existing_input.tap_key_sig;
        }
        signed_input
            .tap_script_sigs
            .extend(existing_input.tap_script_sigs.clone());
    }
}

pub(crate) fn merge_signatures(target: &mut Psbt, signed: Psbt) -> Result<bool> {
    if target.unsigned_tx != signed.unsigned_tx || target.inputs.len() != signed.inputs.len() {
        bail!("BitBox returned signatures for a different transaction");
    }

    let mut merged = false;
    for (target_input, signed_input) in target.inputs.iter_mut().zip(signed.inputs) {
        for (public_key, signature) in signed_input.partial_sigs {
            if let Some(existing) = target_input.partial_sigs.get(&public_key) {
                if existing != &signature {
                    bail!("BitBox returned a conflicting signature");
                }
            } else {
                target_input.partial_sigs.insert(public_key, signature);
                merged = true;
            }
        }
        if let Some(signature) = signed_input.tap_key_sig {
            if let Some(existing) = &target_input.tap_key_sig {
                if existing != &signature {
                    bail!("BitBox returned a conflicting Taproot key-path signature");
                }
            } else {
                target_input.tap_key_sig = Some(signature);
                merged = true;
            }
        }
        for (key, signature) in signed_input.tap_script_sigs {
            if let Some(existing) = target_input.tap_script_sigs.get(&key) {
                if existing != &signature {
                    bail!("BitBox returned a conflicting Taproot script-path signature");
                }
            } else {
                target_input.tap_script_sigs.insert(key, signature);
                merged = true;
            }
        }
    }
    Ok(merged)
}

impl WalletPolicyDeviceKey {
    fn matches_public_key(&self, public_key: &PublicKey, source: &KeySource) -> bool {
        if source.0 != self.root_fingerprint {
            return false;
        }
        let Some(relative_path) = self.relative_path(&source.1) else {
            return false;
        };
        self.xpub
            .derive_pub(&Secp256k1::verification_only(), &relative_path)
            .is_ok_and(|derived| derived.public_key == *public_key)
    }

    fn matches_xonly_public_key(&self, public_key: &XOnlyPublicKey, source: &KeySource) -> bool {
        if source.0 != self.root_fingerprint {
            return false;
        }
        let Some(relative_path) = self.relative_path(&source.1) else {
            return false;
        };
        self.xpub
            .derive_pub(&Secp256k1::verification_only(), &relative_path)
            .is_ok_and(|derived| derived.public_key.x_only_public_key().0 == *public_key)
    }

    fn relative_path(&self, full_path: &DerivationPath) -> Option<DerivationPath> {
        let account_path = self.account_keypath.as_ref();
        let full_path = full_path.as_ref();
        if !full_path.starts_with(account_path) {
            return None;
        }
        let relative = &full_path[account_path.len()..];
        match relative {
            [ChildNumber::Normal { index: branch }, ChildNumber::Normal { .. }]
                if self.derivation_branches.contains(branch) =>
            {
                Some(relative.to_vec().into())
            }
            _ => None,
        }
    }
}

#[cfg(test)]
mod tests {
    use std::collections::BTreeMap;

    use bitcoin::absolute::LockTime;
    use bitcoin::bip32::{Xpriv, Xpub};
    use bitcoin::hashes::Hash;
    use bitcoin::secp256k1::Parity;
    use bitcoin::taproot::{ControlBlock, LeafVersion, TaprootMerkleBranch};
    use bitcoin::transaction::Version;
    use bitcoin::{Amount, Network, OutPoint, ScriptBuf, Sequence, Transaction, TxIn, TxOut, Txid};

    use super::*;

    #[test]
    fn filters_disjoint_account_roles_used_by_different_inputs() {
        let secp = Secp256k1::new();
        let master = Xpriv::new_master(Network::Testnet, &[1; 32]).unwrap();
        let fingerprint = master.fingerprint(&secp);
        let first = policy_key(
            &master,
            fingerprint,
            "m/48'/1'/0'/3'".parse().unwrap(),
            [0, 1],
            &secp,
        );
        let first = WalletPolicyDeviceKey {
            derivation_branches: vec![0, 1, 2, 3],
            ..first
        };
        let mut psbt = Psbt::from_unsigned_tx(test_transaction_with_inputs(3)).unwrap();
        psbt.inputs[0].bip32_derivation = BTreeMap::from([derived_origin(&first, 0, 0, &secp)]);
        psbt.inputs[1].bip32_derivation = BTreeMap::from([derived_origin(&first, 2, 0, &secp)]);
        psbt.inputs[2].bip32_derivation = BTreeMap::from([derived_origin(&first, 3, 0, &secp)]);

        let (filtered, _) = filter_psbt_for_device_keys(&psbt, &[first])
            .unwrap()
            .unwrap();

        assert_eq!(filtered.inputs[0].bip32_derivation.len(), 1);
        assert_eq!(filtered.inputs[1].bip32_derivation.len(), 1);
        assert_eq!(filtered.inputs[2].bip32_derivation.len(), 1);
    }

    #[test]
    fn filters_taproot_origins_to_the_selected_account_role() {
        let secp = Secp256k1::new();
        let master = Xpriv::new_master(Network::Testnet, &[1; 32]).unwrap();
        let fingerprint = master.fingerprint(&secp);
        let device_key = policy_key(
            &master,
            fingerprint,
            "m/86'/1'/0'".parse().unwrap(),
            [0, 1],
            &secp,
        );
        let device_key = WalletPolicyDeviceKey {
            derivation_branches: vec![0, 1, 2, 3],
            ..device_key
        };
        let (first_xonly, first_source) = derived_xonly_origin(&device_key, 0, 0, &secp);
        let (second_xonly, second_source) = derived_xonly_origin(&device_key, 2, 0, &secp);
        let ((internal_key, internal_source), (leaf_key, leaf_source)) =
            if first_xonly < second_xonly {
                ((first_xonly, first_source), (second_xonly, second_source))
            } else {
                ((second_xonly, second_source), (first_xonly, first_source))
            };
        let leaf_script = ScriptBuf::from_bytes(vec![0x51]);
        let leaf_hash = TapLeafHash::from_script(&leaf_script, LeafVersion::TapScript);
        let mut psbt = Psbt::from_unsigned_tx(test_transaction()).unwrap();
        psbt.inputs[0].tap_internal_key = Some(internal_key);
        psbt.inputs[0].tap_scripts.insert(
            ControlBlock {
                leaf_version: LeafVersion::TapScript,
                output_key_parity: Parity::Even,
                internal_key,
                merkle_branch: TaprootMerkleBranch::decode(&[]).unwrap(),
            },
            (leaf_script, LeafVersion::TapScript),
        );
        psbt.inputs[0].tap_key_origins = BTreeMap::from([
            (internal_key, (vec![], internal_source)),
            (leaf_key, (vec![leaf_hash], leaf_source)),
        ]);

        let (filtered, _) = filter_psbt_for_device_keys(&psbt, &[device_key])
            .unwrap()
            .unwrap();

        assert_eq!(filtered.inputs[0].tap_key_origins.len(), 1);
        assert!(filtered.inputs[0]
            .tap_key_origins
            .contains_key(&internal_key));
    }

    #[test]
    fn rejects_sighashes_the_bitbox_cannot_produce() {
        let mut segwit = Psbt::from_unsigned_tx(test_transaction()).unwrap();
        segwit.inputs[0].witness_utxo = Some(test_utxo(ScriptBuf::from_bytes(
            [vec![0x00, 0x14], vec![0; 20]].concat(),
        )));
        segwit.inputs[0].sighash_type = Some(EcdsaSighashType::Single.into());
        let mut taproot = Psbt::from_unsigned_tx(test_transaction()).unwrap();
        taproot.inputs[0].witness_utxo = Some(test_utxo(ScriptBuf::from_bytes(
            [vec![0x51, 0x20], vec![0; 32]].concat(),
        )));
        taproot.inputs[0].sighash_type = Some(TapSighashType::All.into());

        assert!(validate_supported_sighashes(&segwit).is_err());
        assert!(validate_supported_sighashes(&taproot).is_err());
    }

    #[test]
    fn preserves_existing_signatures_when_merging_new_ones() {
        let secp = Secp256k1::new();
        let master = Xpriv::new_master(Network::Testnet, &[1; 32]).unwrap();
        let fingerprint = master.fingerprint(&secp);
        let device_key = policy_key(
            &master,
            fingerprint,
            "m/48'/1'/0'/3'".parse().unwrap(),
            [0, 1],
            &secp,
        );
        let first_public_key = bitcoin::PublicKey::new(derived_origin(&device_key, 0, 0, &secp).0);
        let second_public_key = bitcoin::PublicKey::new(derived_origin(&device_key, 0, 1, &secp).0);
        let existing_signature = test_signature(1, &secp);
        let replacement_signature = test_signature(2, &secp);
        let new_signature = test_signature(3, &secp);
        let mut target = Psbt::from_unsigned_tx(test_transaction_with_inputs(2)).unwrap();
        target.inputs[0]
            .partial_sigs
            .insert(first_public_key, existing_signature);
        let mut signed = target.clone();
        signed.inputs[0]
            .partial_sigs
            .insert(first_public_key, replacement_signature);
        signed.inputs[1]
            .partial_sigs
            .insert(second_public_key, new_signature);

        restore_existing_signatures(&mut signed, &target);
        let merged = merge_signatures(&mut target, signed).unwrap();

        assert!(merged);
        assert_eq!(
            target.inputs[0].partial_sigs[&first_public_key],
            existing_signature
        );
        assert_eq!(
            target.inputs[1].partial_sigs[&second_public_key],
            new_signature
        );
    }

    fn policy_key(
        master: &Xpriv,
        fingerprint: bitcoin::bip32::Fingerprint,
        account_keypath: DerivationPath,
        derivation_branches: [u32; 2],
        secp: &Secp256k1<bitcoin::secp256k1::All>,
    ) -> WalletPolicyDeviceKey {
        let account = master.derive_priv(secp, &account_keypath).unwrap();
        WalletPolicyDeviceKey {
            root_fingerprint: fingerprint,
            account_keypath,
            xpub: Xpub::from_priv(secp, &account),
            derivation_branches: derivation_branches.to_vec(),
        }
    }

    fn derived_origin(
        key: &WalletPolicyDeviceKey,
        branch: u32,
        index: u32,
        secp: &Secp256k1<bitcoin::secp256k1::All>,
    ) -> (PublicKey, KeySource) {
        let relative = DerivationPath::from(vec![
            ChildNumber::Normal { index: branch },
            ChildNumber::Normal { index },
        ]);
        let public_key = key.xpub.derive_pub(secp, &relative).unwrap().public_key;
        let full_path = key
            .account_keypath
            .into_iter()
            .cloned()
            .chain(relative.into_iter().cloned())
            .collect();
        (public_key, (key.root_fingerprint, full_path))
    }

    fn derived_xonly_origin(
        key: &WalletPolicyDeviceKey,
        branch: u32,
        index: u32,
        secp: &Secp256k1<bitcoin::secp256k1::All>,
    ) -> (XOnlyPublicKey, KeySource) {
        let (public_key, source) = derived_origin(key, branch, index, secp);
        (public_key.x_only_public_key().0, source)
    }

    fn test_signature(
        value: u8,
        secp: &Secp256k1<bitcoin::secp256k1::All>,
    ) -> bitcoin::ecdsa::Signature {
        let secret_key = bitcoin::secp256k1::SecretKey::from_slice(&[value; 32]).unwrap();
        let message = bitcoin::secp256k1::Message::from_digest([value; 32]);
        bitcoin::ecdsa::Signature::sighash_all(secp.sign_ecdsa(&message, &secret_key))
    }

    fn test_transaction() -> Transaction {
        test_transaction_with_inputs(1)
    }

    fn test_transaction_with_inputs(input_count: u32) -> Transaction {
        Transaction {
            version: Version::TWO,
            lock_time: LockTime::ZERO,
            input: (0..input_count)
                .map(|index| TxIn {
                    previous_output: OutPoint::new(Txid::all_zeros(), index),
                    script_sig: ScriptBuf::new(),
                    sequence: Sequence::ENABLE_RBF_NO_LOCKTIME,
                    witness: bitcoin::Witness::new(),
                })
                .collect(),
            output: vec![TxOut {
                value: Amount::from_sat(1_000),
                script_pubkey: ScriptBuf::new(),
            }],
        }
    }

    fn test_utxo(script_pubkey: ScriptBuf) -> TxOut {
        TxOut {
            value: Amount::from_sat(1_000),
            script_pubkey,
        }
    }
}
