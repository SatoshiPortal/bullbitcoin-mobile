use std::{collections::BTreeSet, str::FromStr};

use bip138::{
    backend::{Active, Backend, Descriptor},
    descriptor::dpk_to_root_pk,
    EncryptedBackup, ToPayload,
};
use bip138_ll::{self as ll, crypto::RustBitcoin, Content, Crypto, Padding};

const MAX_ENVELOPE: usize = 4 * 1024 * 1024;
const MAX_ITEM: usize = 2 * 1024 * 1024;
const MAX_VENDOR: usize = 512 * 1024;

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Bip138ContentType {
    Bip { number: u16 },
    Vendor { tag: Vec<u8> },
    Text,
}

#[flutter_rust_bridge::frb(non_opaque)]
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Bip138Item {
    pub content_type: Bip138ContentType,
    pub bytes: Vec<u8>,
}

/// Safe categories only: foreign errors never cross the bridge.
#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
pub enum Bip138Error {
    #[error("BIP138 input exceeds the size limit")]
    TooLarge,
    #[error("Invalid public descriptor")]
    InvalidDescriptor,
    #[error("No eligible BIP138 recipient keys")]
    NoEligibleKeys,
    #[error("Payload descriptors do not match the recipient descriptors")]
    DescriptorMismatch,
    #[error("Malformed BIP138 input")]
    Malformed,
    #[error("Unsupported BIP138 content or encryption")]
    Unsupported,
    #[error("BIP138 encryption failed")]
    Encryption,
}

/// Diagnostics deliberately omit the excluded key expression.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Bip138ExcludedKey {
    DisallowedExpression,
    Nums,
    ExposedRoot,
}

fn descriptors(values: &[String]) -> Result<Vec<Descriptor>, Bip138Error> {
    if values.len() > 255 || values.iter().map(String::len).sum::<usize>() > MAX_ENVELOPE {
        return Err(Bip138Error::TooLarge);
    }
    values
        .iter()
        .map(|s| {
            if s.len() > 64 * 1024 {
                return Err(Bip138Error::TooLarge);
            }
            // DescriptorPublicKey parsing rejects xprivs and WIF; never use
            // parse_descriptor, which accepts secrets and converts them to public.
            Descriptor::from_str(s).map_err(|_| Bip138Error::InvalidDescriptor)
        })
        .collect()
}

fn key_source(values: &[Descriptor]) -> Result<EncryptedBackup, Bip138Error> {
    let refs = values
        .iter()
        .map(|d| d as &dyn ToPayload)
        .collect::<Vec<_>>();
    let source = EncryptedBackup::new()
        .set_payloads(&refs)
        .map_err(|_| Bip138Error::InvalidDescriptor)?;
    if source.get_keys().is_empty() {
        return Err(Bip138Error::NoEligibleKeys);
    }
    Ok(source)
}

fn warning(w: bip138::Warning) -> Bip138ExcludedKey {
    match w {
        bip138::Warning::DisallowedKeyExpression(_) => Bip138ExcludedKey::DisallowedExpression,
        bip138::Warning::NumsKey(_) => Bip138ExcludedKey::Nums,
        bip138::Warning::ExposedRoot(_) => Bip138ExcludedKey::ExposedRoot,
    }
}

/// Inspect exclusions without returning descriptor/key material.
pub fn bip138_excluded_keys(
    public_descriptors: Vec<String>,
) -> Result<Vec<Bip138ExcludedKey>, Bip138Error> {
    let parsed = descriptors(&public_descriptors)?;
    // Encrypting an empty set is forbidden, but inspection must still report
    // why every key was excluded. The upstream output owns pooled warnings.
    let refs = parsed
        .iter()
        .map(|d| d as &dyn ToPayload)
        .collect::<Vec<_>>();
    let source = EncryptedBackup::new()
        .set_payloads(&refs)
        .map_err(|_| Bip138Error::InvalidDescriptor)?;
    Ok(source.get_warnings().iter().cloned().map(warning).collect())
}

fn content(t: &Bip138ContentType) -> Content {
    match t {
        Bip138ContentType::Bip { number } => Content::BIP(*number),
        Bip138ContentType::Vendor { tag } => Content::Proprietary(tag.clone()),
        Bip138ContentType::Text => Content::String,
    }
}

fn validate_item(item: &Bip138Item) -> Result<(), Bip138Error> {
    let limit = match item.content_type {
        Bip138ContentType::Vendor { .. } => MAX_VENDOR,
        Bip138ContentType::Bip { number: 329 } => 1024 * 1024,
        _ => MAX_ITEM,
    };
    if item.bytes.len() > limit {
        return Err(Bip138Error::TooLarge);
    }
    if let Bip138ContentType::Vendor { tag } = &item.content_type {
        if tag.len() > MAX_VENDOR {
            return Err(Bip138Error::TooLarge);
        }
    }
    if matches!(item.content_type, Bip138ContentType::Text)
        && std::str::from_utf8(&item.bytes).is_err()
    {
        return Err(Bip138Error::Malformed);
    }
    Ok(())
}

fn embedded_descriptors(items: &[Bip138Item]) -> Result<Vec<String>, Bip138Error> {
    let mut embedded = Vec::new();
    for item in items {
        match item.content_type {
            Bip138ContentType::Bip { number: 380 } => embedded
                .push(String::from_utf8(item.bytes.clone()).map_err(|_| Bip138Error::Malformed)?),
            Bip138ContentType::Bip { number: 139 } => {
                let doc: serde_json::Value =
                    serde_json::from_slice(&item.bytes).map_err(|_| Bip138Error::Malformed)?;
                if doc["version"] != "BIP139-1" {
                    return Err(Bip138Error::Unsupported);
                }
                let accounts = doc["accounts"].as_array().ok_or(Bip138Error::Malformed)?;
                if accounts.is_empty() {
                    return Err(Bip138Error::Malformed);
                }
                for account in accounts {
                    match account["type"].as_str() {
                        Some("bip380") => embedded.push(
                            account["descriptor"]
                                .as_str()
                                .ok_or(Bip138Error::Malformed)?
                                .into(),
                        ),
                        Some("multi_bip380") => {
                            let ds = account["descriptor"]
                                .as_array()
                                .ok_or(Bip138Error::Malformed)?;
                            if ds.is_empty() {
                                return Err(Bip138Error::Malformed);
                            }
                            for d in ds {
                                embedded.push(d.as_str().ok_or(Bip138Error::Malformed)?.into());
                            }
                        }
                        _ => return Err(Bip138Error::Unsupported),
                    }
                }
            }
            // Policy parsing would need the forbidden descriptor_backup feature.
            Bip138ContentType::Bip { number: 388 } => return Err(Bip138Error::Unsupported),
            _ => {}
        }
    }
    Ok(embedded)
}

/// Encrypt only to descriptors present in BIP139 accounts or bare BIP380 items.
/// The supplied set must equal the embedded set after public-descriptor parsing.
/// Opaque items must not carry additional descriptor/policy material.
pub fn bip138_encrypt(
    public_descriptors: Vec<String>,
    items: Vec<Bip138Item>,
    padded: bool,
) -> Result<Vec<u8>, Bip138Error> {
    // Bound allocation before parsing JSON or constructing the plaintext.
    let mut total = 0usize;
    for item in &items {
        validate_item(item)?;
        total = total
            .checked_add(item.bytes.len() + 16)
            .ok_or(Bip138Error::TooLarge)?;
        if let Bip138ContentType::Vendor { tag } = &item.content_type {
            total = total.checked_add(tag.len()).ok_or(Bip138Error::TooLarge)?;
        }
        if total > MAX_ENVELOPE {
            return Err(Bip138Error::TooLarge);
        }
    }
    let supplied = descriptors(&public_descriptors)?;
    let embedded = descriptors(&embedded_descriptors(&items)?)?;
    let canonical = |ds: &[Descriptor]| ds.iter().map(ToString::to_string).collect::<BTreeSet<_>>();
    if canonical(&supplied) != canonical(&embedded) {
        return Err(Bip138Error::DescriptorMismatch);
    }
    // Use the embedded set itself, including cross-item exposed-root filtering.
    let source = key_source(&embedded)?;
    let pairs = items
        .iter()
        .map(|i| (content(&i.content_type), i.bytes.as_slice()))
        .collect::<Vec<_>>();
    let paths = source
        .get_derivation_paths()
        .iter()
        .map(Active::to_ll_path)
        .collect();
    let keys = source.get_keys().iter().map(Active::xonly).collect();
    let padding = if padded {
        Padding::Geometric
    } else {
        Padding::None
    };
    let bytes = ll::encrypt_chacha20_poly1305_v1_items(
        &RustBitcoin,
        &mut ll::crypto::OsRandom,
        paths,
        false,
        &pairs,
        keys,
        padding,
    )
    .map_err(|_| Bip138Error::Encryption)?;
    if bytes.len() > MAX_ENVELOPE {
        return Err(Bip138Error::TooLarge);
    }
    Ok(bytes)
}

/// None means no candidate authenticated the ciphertext; authenticated malformed
/// plaintext is an error. Avoid upstream decrypt(), which conflates those cases
/// and skips BIP139/vendor items without their optional parsers.
pub fn bip138_decrypt(
    bytes: Vec<u8>,
    candidate_public_descriptors: Vec<String>,
) -> Result<Option<Vec<Bip138Item>>, Bip138Error> {
    if bytes.len() > MAX_ENVELOPE {
        return Err(Bip138Error::TooLarge);
    }
    let (_, secrets, encryption, nonce, ciphertext) =
        ll::decode_v1(&bytes).map_err(|_| Bip138Error::Malformed)?;
    if encryption != 1 {
        return Err(Bip138Error::Unsupported);
    }
    if ciphertext.len() < 16 {
        return Err(Bip138Error::Malformed);
    }
    let ds = descriptors(&candidate_public_descriptors)?;
    // Decrypt eligibility differs from encryption: even a bare xpub can offer
    // its root. Literal on-chain keys and NUMS must never become candidates.
    let mut keys = BTreeSet::new();
    for d in &ds {
        for k in Active::descriptor_keys(d) {
            if let Ok(pk) = dpk_to_root_pk(&k) {
                let key = Active::xonly(&pk);
                if key != bip138::descriptor::BIP341_NUMS {
                    keys.insert(key);
                }
            }
        }
    }
    if keys.is_empty() {
        return Err(Bip138Error::NoEligibleKeys);
    }
    for key in keys {
        let si = ll::tagged_hash(&RustBitcoin, b"BIP138_INDIVIDUAL_SECRET", &key);
        for ci in &secrets {
            let secret = std::array::from_fn(|i| si[i] ^ ci[i]);
            if let Some(plaintext) = RustBitcoin.aead_decrypt(&secret, &nonce, &ciphertext) {
                let decoded =
                    ll::decode_plaintext(&plaintext).map_err(|_| Bip138Error::Malformed)?;
                let mut items = Vec::new();
                for (t, bytes) in decoded {
                    if bytes.len() > MAX_ITEM {
                        return Err(Bip138Error::TooLarge);
                    }
                    let content_type = match t {
                        Content::Bip138 => Bip138ContentType::Bip { number: 138 },
                        Content::Bip139 => Bip138ContentType::Bip { number: 139 },
                        Content::Bip329 => Bip138ContentType::Bip { number: 329 },
                        Content::Bip380 => Bip138ContentType::Bip { number: 380 },
                        Content::Bip388 => Bip138ContentType::Bip { number: 388 },
                        Content::BIP(number) => Bip138ContentType::Bip { number },
                        Content::Proprietary(tag) => Bip138ContentType::Vendor { tag },
                        Content::String => Bip138ContentType::Text,
                        Content::Unknown | Content::None => continue,
                    };
                    let item = Bip138Item {
                        content_type,
                        bytes,
                    };
                    validate_item(&item)?;
                    items.push(item);
                }
                return Ok(Some(items));
            }
        }
    }
    Ok(None)
}
