use std::{collections::BTreeSet, str::FromStr};

use bip138::{
    backend::{Active, Backend, Descriptor},
    EncryptedBackup, ToPayload,
};
use bip138_ll::{self as ll, crypto::RustBitcoin, Crypto, Padding};
use dart_bip138::api::*;
use serde_json::{json, Value};

const DESCRIPTOR: &str = "wpkh([d34db33f/84h/1h/0h]tpubDC5FSnBiZDMmhiuCmWAYsLwgLYrrT9rAqvTySfuCCrgsWz8wxMXUS9Tb9iVMvcRbvFcAHGkMD5Kx8koh4GquNGNTfohfk7pgjhaPCdXpoba/0/*)";

fn vectors(name: &str) -> Vec<Value> {
    serde_json::from_str(
        &std::fs::read_to_string(format!(
            "{}/tests/vectors/{name}.json",
            env!("CARGO_MANIFEST_DIR")
        ))
        .unwrap(),
    )
    .unwrap()
}
fn bytes(v: &Value) -> Vec<u8> {
    hex::decode(v.as_str().unwrap()).unwrap()
}
fn array<const N: usize>(v: &Value) -> [u8; N] {
    bytes(v).try_into().unwrap()
}
fn keys(v: &Value) -> Vec<[u8; 32]> {
    v.as_array()
        .unwrap()
        .iter()
        .map(|k| bytes(k)[1..].try_into().unwrap())
        .collect()
}
fn paths(v: &Value) -> Vec<ll::DerivationPath> {
    v.as_array()
        .unwrap()
        .iter()
        .map(|p| {
            Active::to_ll_path(
                &bip138::backend::DerivationPath::from_str(p.as_str().unwrap()).unwrap(),
            )
        })
        .collect()
}
fn item(number: u16, bytes: Vec<u8>) -> Bip138Item {
    Bip138Item {
        content_type: Bip138ContentType::Bip { number },
        bytes,
    }
}
fn public_descriptor(key: &[u8; 32]) -> String {
    use bip138::miniscript::bitcoin::{
        bip32::{ChainCode, ChildNumber, Fingerprint, Xpub},
        secp256k1::PublicKey,
        NetworkKind,
    };
    let mut compressed = vec![2];
    compressed.extend_from_slice(key);
    let xpub = Xpub {
        network: NetworkKind::Main,
        depth: 0,
        parent_fingerprint: Fingerprint::default(),
        child_number: ChildNumber::from_normal_idx(0).unwrap(),
        public_key: PublicKey::from_slice(&compressed).unwrap(),
        chain_code: ChainCode::from([0u8; 32]),
    };
    format!("wpkh({xpub})")
}

#[test]
fn official_content_payload_and_crypto_vectors() {
    for v in vectors("content_type") {
        assert_eq!(
            ll::parse_content(&bytes(&v["content"])).is_ok(),
            v["valid"].as_bool().unwrap(),
            "{}",
            v["description"]
        );
    }
    for v in vectors("payload") {
        let result = ll::decode_plaintext(&bytes(&v["payload"]));
        assert_eq!(result.is_ok(), v["valid"].as_bool().unwrap());
        if let Ok(items) = result {
            assert_eq!(items.len(), v["items"].as_array().unwrap().len());
        }
    }
    for v in vectors("chacha20poly1305_encryption") {
        let secret = array(&v["secret"]);
        let nonce = array(&v["nonce"]);
        let plaintext = bytes(&v["plaintext"]);
        let encrypted = ll::encrypt_with_nonce(&RustBitcoin, secret, plaintext.clone(), nonce);
        if v["ciphertext"].is_null() {
            assert!(encrypted.is_err());
            continue;
        }
        let ciphertext = bytes(&v["ciphertext"]);
        assert_eq!(encrypted.unwrap().1, ciphertext);
        assert_eq!(
            RustBitcoin
                .aead_encrypt(&secret, &nonce, &plaintext)
                .unwrap(),
            ciphertext
        );
        assert_eq!(
            RustBitcoin
                .aead_decrypt(&secret, &nonce, &ciphertext)
                .unwrap(),
            plaintext
        );
    }
    for v in vectors("encryption_secret") {
        let ks = keys(&v["keys"]);
        let secret = ll::decryption_secret(&RustBitcoin, &ks);
        assert_eq!(secret, array::<32>(&v["decryption_secret"]));
        let actual = ll::individual_secrets(&RustBitcoin, &secret, &ks)
            .into_iter()
            .collect::<BTreeSet<_>>();
        let expected = v["individual_secrets"]
            .as_array()
            .unwrap()
            .iter()
            .map(array::<32>)
            .collect::<BTreeSet<_>>();
        assert_eq!(actual, expected);
    }
}

#[test]
fn official_path_and_individual_secret_vectors() {
    for v in vectors("derivation_path") {
        let result = ll::encode_derivation_paths(paths(&v["paths"]));
        if v.get("expected").is_some_and(Value::is_null) {
            assert!(result.is_err());
            continue;
        }
        let encoded = result.unwrap();
        if let Some(expected) = v.get("expected") {
            assert_eq!(encoded, bytes(expected));
        }
        let (_, decoded) = ll::parse_derivation_paths(&encoded).unwrap();
        assert_eq!(
            decoded,
            paths(&v["paths"])
                .into_iter()
                .collect::<BTreeSet<_>>()
                .into_iter()
                .collect::<Vec<_>>()
        );
    }
    for v in vectors("individual_secrets") {
        let secrets = v["secrets"]
            .as_array()
            .unwrap()
            .iter()
            .map(array::<32>)
            .collect::<Vec<_>>();
        let result = ll::encode_individual_secrets(&secrets);
        if v.get("expected").is_some_and(Value::is_null) {
            assert!(result.is_err());
            continue;
        }
        let encoded = result.unwrap();
        if let Some(expected) = v.get("expected") {
            assert_eq!(encoded, bytes(expected));
        }
        assert_eq!(
            ll::parse_individual_secrets(&encoded).unwrap().1,
            secrets
                .into_iter()
                .collect::<BTreeSet<_>>()
                .into_iter()
                .collect::<Vec<_>>()
        );
    }
}

#[test]
fn official_encrypted_vectors_exact_bytes_and_binding_decryption() {
    for v in vectors("encrypted_backup") {
        let ks = keys(&v["keys"]);
        let mut owned = vec![(
            ll::parse_content(&bytes(&v["content"])).unwrap().1,
            v["plaintext"].as_str().unwrap().as_bytes().to_vec(),
        )];
        if let Some(extra) = v.get("extra") {
            for i in extra.as_array().unwrap() {
                owned.push((
                    ll::parse_content(&bytes(&i["content"])).unwrap().1,
                    i["plaintext"].as_str().unwrap().as_bytes().to_vec(),
                ));
            }
        }
        let refs = owned
            .iter()
            .map(|(t, b)| (t.clone(), b.as_slice()))
            .collect::<Vec<_>>();
        let decoys = v["decoy_individual_secrets"]
            .as_array()
            .unwrap()
            .iter()
            .map(array::<32>)
            .collect::<Vec<_>>();
        let result = ll::encrypt_chacha20_poly1305_v1_items_with_decoys(
            &RustBitcoin,
            paths(&v["derivation_paths"]),
            false,
            &refs,
            ks.clone(),
            Padding::None,
            array(&v["nonce"]),
            &decoys,
        );
        if v["valid"] == false {
            assert!(result.is_err());
            continue;
        }
        let expected = bytes(&v["expected"]);
        assert_eq!(result.unwrap(), expected, "{}", v["description"]);
        let candidate = public_descriptor(&ks[0]);
        let recovered = bip138_decrypt(expected.clone(), vec![candidate.clone()])
            .unwrap()
            .unwrap();
        assert_eq!(
            recovered
                .iter()
                .map(|i| i.bytes.clone())
                .collect::<Vec<_>>(),
            owned.iter().map(|(_, b)| b.clone()).collect::<Vec<_>>()
        );
        // Exercise every truncation of every official envelope through the binding.
        for end in 0..expected.len() {
            assert!(
                bip138_decrypt(expected[..end].to_vec(), vec![candidate.clone()]).is_err(),
                "truncation {end}"
            );
        }
        if let Some(trailing) = v.get("trailing") {
            let mut extended = expected;
            extended.extend(bytes(trailing));
            assert_eq!(
                bip138_decrypt(extended, vec![candidate]).unwrap().unwrap(),
                recovered
            );
        }
    }
}

#[test]
fn official_recipient_keys_exclusions_and_empty_set() {
    for v in vectors("recipient_keys") {
        let values = v["descriptors"]
            .as_array()
            .unwrap()
            .iter()
            .map(|d| d.as_str().unwrap().to_owned())
            .collect::<Vec<_>>();
        // Miniscript 12 does not implement MuSig descriptor syntax.
        if values.iter().any(|d| d.contains("musig(")) {
            continue;
        }
        let ds = values
            .iter()
            .map(|d| Descriptor::from_str(d).unwrap())
            .collect::<Vec<_>>();
        let refs = ds.iter().map(|d| d as &dyn ToPayload).collect::<Vec<_>>();
        let source = EncryptedBackup::new().set_payloads(&refs).unwrap();
        let items = values
            .iter()
            .map(|d| item(380, d.as_bytes().to_vec()))
            .collect();
        if v["expected_keys"].is_null() {
            assert_eq!(
                bip138_encrypt(values, items, false),
                Err(Bip138Error::NoEligibleKeys)
            );
        } else {
            let actual = source
                .get_keys()
                .iter()
                .map(|k| hex::encode(Active::xonly(k)))
                .collect::<BTreeSet<_>>();
            let expected = v["expected_keys"]
                .as_array()
                .unwrap()
                .iter()
                .map(|k| k.as_str().unwrap().to_owned())
                .collect();
            assert_eq!(actual, expected);
            assert!(bip138_encrypt(values, items, false).is_ok());
        }
    }
    let nums = format!(
        "tr(50929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0,pk({}))",
        DESCRIPTOR.trim_start_matches("wpkh(").trim_end_matches(')')
    );
    assert!(bip138_excluded_keys(vec![nums])
        .unwrap()
        .contains(&Bip138ExcludedKey::Nums));
}

#[test]
fn embedded_bip139_descriptors_are_the_only_recipient_source() {
    let document = json!({"version":"BIP139-1","network":"regtest","accounts":[{"type":"multi_bip380","descriptor":[DESCRIPTOR]}]});
    let items = vec![
        item(139, serde_json::to_vec(&document).unwrap()),
        Bip138Item {
            content_type: Bip138ContentType::Vendor {
                tag: b"bull".to_vec(),
            },
            bytes: b"{\"v\":1}".to_vec(),
        },
    ];
    for padded in [false, true] {
        let encrypted = bip138_encrypt(vec![DESCRIPTOR.into()], items.clone(), padded).unwrap();
        assert_eq!(
            bip138_decrypt(encrypted, vec![DESCRIPTOR.into()]).unwrap(),
            Some(items.clone())
        );
    }
    let unrelated = DESCRIPTOR.replace("/0/*", "/1/*");
    assert_eq!(
        bip138_encrypt(vec![unrelated], items.clone(), true),
        Err(Bip138Error::DescriptorMismatch)
    );
    assert_eq!(
        bip138_encrypt(
            vec![DESCRIPTOR.into()],
            vec![item(329, b"{}".to_vec())],
            true
        ),
        Err(Bip138Error::DescriptorMismatch)
    );
    assert!(bip138_encrypt(vec!["wpkh(xprv-invalid)".into()], items, true).is_err());
}

#[test]
fn malformed_input_and_authenticated_malformed_plaintext_return_errors() {
    for malformed in [
        vec![],
        b"garbage".to_vec(),
        b"BIP138\x01\xff\xff".to_vec(),
        b"BIP138\x01\x00\xff".to_vec(),
        vec![0; 4 * 1024 * 1024 + 1],
    ] {
        assert!(bip138_decrypt(malformed, vec![DESCRIPTOR.into()]).is_err());
    }
    let ks = keys(&vectors("encrypted_backup")[0]["keys"]);
    let candidate = public_descriptor(&ks[0]);
    let secret = ll::decryption_secret(&RustBitcoin, &ks);
    let secrets =
        ll::encode_individual_secrets(&ll::individual_secrets(&RustBitcoin, &secret, &ks)).unwrap();
    // Authenticated malicious holders must still not reach a panic via lengths.
    for plaintext in [
        vec![],
        vec![0],
        vec![1],
        vec![3, 0, 255, 255, 255, 255, 255, 255, 255, 255, 255],
        vec![2, 255, 255, 255, 255, 255, 255, 255, 255, 255],
        vec![3, 0, 1, 255],
    ] {
        let ciphertext = RustBitcoin
            .aead_encrypt(&secret, &[1; 12], &plaintext)
            .unwrap();
        let payload = ll::encode_encrypted_payload([1; 12], &ciphertext).unwrap();
        let envelope = ll::encode_v1(1, vec![0], secrets.clone(), 1, payload);
        assert_eq!(
            bip138_decrypt(envelope, vec![candidate.clone()]),
            Err(Bip138Error::Malformed)
        );
    }
    let mut huge_length = ll::encode_v1(1, vec![0], secrets, 1, vec![1; 12]);
    huge_length.extend([255; 9]);
    assert!(bip138_decrypt(huge_length, vec![candidate]).is_err());
}

#[test]
fn size_limits_and_wrong_key_are_distinct() {
    let items = vec![item(380, DESCRIPTOR.as_bytes().to_vec())];
    let encrypted = bip138_encrypt(vec![DESCRIPTOR.into()], items.clone(), false).unwrap();
    let other = public_descriptor(&keys(&vectors("encrypted_backup")[0]["keys"])[0]);
    assert_eq!(bip138_decrypt(encrypted, vec![other]).unwrap(), None);
    let mut near_cap = items.clone();
    near_cap.extend((0..2).map(|_| Bip138Item {
        content_type: Bip138ContentType::Text,
        bytes: vec![b'a'; 2 * 1024 * 1024 - 10000],
    }));
    assert_eq!(
        bip138_encrypt(vec![DESCRIPTOR.into()], near_cap, true),
        Err(Bip138Error::TooLarge)
    );
    for (t, limit) in [
        (Bip138ContentType::Text, 2 * 1024 * 1024),
        (
            Bip138ContentType::Vendor {
                tag: b"bull".to_vec(),
            },
            512 * 1024,
        ),
        (Bip138ContentType::Bip { number: 329 }, 1024 * 1024),
    ] {
        let mut oversized = items.clone();
        oversized.push(Bip138Item {
            content_type: t,
            bytes: vec![b'a'; limit + 1],
        });
        assert_eq!(
            bip138_encrypt(vec![DESCRIPTOR.into()], oversized, false),
            Err(Bip138Error::TooLarge)
        );
    }
}

#[test]
fn valid_private_descriptors_are_rejected_without_echoing_them() {
    use bip138::miniscript::bitcoin::{bip32::Xpriv, Network};
    use ll::Rng;
    // Generate ephemeral test material, never store or log a private-key fixture.
    let mut seed = [0u8; 32];
    ll::crypto::OsRandom.fill_bytes(&mut seed);
    let private = Xpriv::new_master(Network::Bitcoin, &seed).unwrap();
    let descriptor = format!("wpkh({private}/0/*)");
    let error = bip138_encrypt(
        vec![descriptor.clone()],
        vec![item(380, descriptor.into_bytes())],
        false,
    )
    .unwrap_err();
    assert_eq!(error, Bip138Error::InvalidDescriptor);
    assert_eq!(error.to_string(), "Invalid public descriptor");
}

#[test]
fn authenticated_oversized_items_are_rejected_by_reader() {
    let key = keys(&vectors("encrypted_backup")[0]["keys"])[0];
    for (content, size) in [
        (ll::Content::Proprietary(b"bull".to_vec()), 512 * 1024 + 1),
        (ll::Content::Bip139, 2 * 1024 * 1024 + 1),
    ] {
        let data = vec![b'a'; size];
        let envelope = ll::encrypt_chacha20_poly1305_v1_items(
            &RustBitcoin,
            &mut ll::crypto::OsRandom,
            vec![],
            false,
            &[(content, data.as_slice())],
            vec![key],
            Padding::None,
        )
        .unwrap();
        assert_eq!(
            bip138_decrypt(envelope, vec![public_descriptor(&key)]),
            Err(Bip138Error::TooLarge)
        );
    }
}
