use std::collections::{HashMap, HashSet};
use std::str::FromStr;

use anyhow::{anyhow, bail, Result};
use bitbox_api::btc::{make_script_config_multisig, make_script_config_policy, KeyOriginInfo};
use bitbox_api::pb;
use bitcoin::bip32::{ChildNumber, DerivationPath, Fingerprint, Xpub};
use bitcoin::secp256k1::Secp256k1;
use bitcoin::NetworkKind;
use miniscript::descriptor::{DescriptorPublicKey, ShInner, Wildcard, WshInner};
use miniscript::{Descriptor, TranslatePk, Translator};

const MAX_MULTISIG_KEYS: usize = 15;
const MAX_POLICY_KEYS: usize = 20;
const MAX_MINISCRIPT_TREE_HEIGHT: usize = 64;

#[derive(Debug, Clone, PartialEq, Eq, Hash)]
struct AccountKey {
    root_fingerprint: Option<Fingerprint>,
    account_keypath: Option<DerivationPath>,
    xpub: Xpub,
}

impl AccountKey {
    fn to_key_origin_info(&self) -> KeyOriginInfo {
        KeyOriginInfo {
            root_fingerprint: self.root_fingerprint,
            keypath: self.account_keypath.as_ref().map(Into::into),
            xpub: self.xpub,
        }
    }

    fn to_device_key(&self, derivation_branches: [u32; 2]) -> Result<WalletPolicyDeviceKey> {
        Ok(WalletPolicyDeviceKey {
            root_fingerprint: self.root_fingerprint.ok_or_else(|| {
                anyhow!("the connected BitBox key is missing its master fingerprint")
            })?,
            account_keypath: self.account_keypath.clone().ok_or_else(|| {
                anyhow!("the connected BitBox key is missing its account derivation")
            })?,
            xpub: self.xpub,
            derivation_branches: derivation_branches.to_vec(),
        })
    }
}

#[derive(Debug, Clone)]
enum ScriptTemplate {
    Multisig {
        threshold: u32,
        script_type: pb::btc_script_config::multisig::ScriptType,
    },
    Miniscript {
        policy: String,
    },
}

#[derive(Debug, Clone)]
pub(crate) struct ParsedWalletPolicy {
    template: ScriptTemplate,
    keys: Vec<AccountKey>,
    key_roles: Vec<(usize, [u32; 2])>,
}

impl ParsedWalletPolicy {
    pub(crate) fn parse(descriptor: &str, expected_network: NetworkKind) -> Result<Self> {
        let descriptor = Descriptor::<DescriptorPublicKey>::from_str(descriptor)
            .map_err(|error| anyhow!("invalid descriptor: {error}"))?;
        descriptor
            .sanity_check()
            .map_err(|error| anyhow!("invalid descriptor: {error}"))?;

        match &descriptor {
            Descriptor::Tr(_) => Self::miniscript(&descriptor, expected_network),
            Descriptor::Wsh(wsh) => match wsh.as_inner() {
                WshInner::SortedMulti(multisig) => Self::multisig(
                    multisig.k(),
                    multisig.pks(),
                    pb::btc_script_config::multisig::ScriptType::P2wsh,
                    expected_network,
                ),
                WshInner::Ms(_) => Self::miniscript(&descriptor, expected_network),
            },
            Descriptor::Sh(sh) => match sh.as_inner() {
                ShInner::Wsh(wsh) => match wsh.as_inner() {
                    WshInner::SortedMulti(multisig) => Self::multisig(
                        multisig.k(),
                        multisig.pks(),
                        pb::btc_script_config::multisig::ScriptType::P2wshP2sh,
                        expected_network,
                    ),
                    WshInner::Ms(_) => Err(anyhow!(
                        "BitBox supports only native or nested SegWit multisig and native SegWit Miniscript policies"
                    )),
                },
                _ => Err(anyhow!(
                    "BitBox supports only native or nested SegWit multisig and native SegWit Miniscript policies"
                )),
            },
            _ => Err(anyhow!(
                "BitBox supports only native or nested SegWit multisig and native SegWit Miniscript policies"
            )),
        }
    }

    pub(crate) fn device_candidate_keypaths(
        &self,
        fingerprint: Fingerprint,
    ) -> Vec<DerivationPath> {
        self.keys
            .iter()
            .filter_map(|key| {
                (key.root_fingerprint == Some(fingerprint))
                    .then(|| key.account_keypath.clone())
                    .flatten()
            })
            .collect()
    }

    pub(crate) fn matching_device_key_indices(
        &self,
        fingerprint: Fingerprint,
        device_xpubs: &HashMap<DerivationPath, Xpub>,
    ) -> Vec<usize> {
        self.keys
            .iter()
            .enumerate()
            .filter_map(|(index, key)| {
                let keypath = key.account_keypath.as_ref()?;
                let device_xpub = device_xpubs.get(keypath)?;
                (key.root_fingerprint == Some(fingerprint) && key.xpub == *device_xpub)
                    .then_some(index)
            })
            .collect()
    }

    pub(crate) fn prepare(&self, matching_key_indices: &[usize]) -> Result<PreparedWalletPolicy> {
        let primary_device_key_index = *matching_key_indices.first().ok_or_else(|| {
            anyhow!("the connected BitBox does not control a key in this descriptor")
        })?;
        if matching_key_indices.len() != 1 {
            bail!("BitBox wallet policies must use one account key from the connected device");
        }
        let device_account_keypath = self.keys[primary_device_key_index]
            .account_keypath
            .clone()
            .filter(|keypath| !keypath.is_empty())
            .ok_or_else(|| {
                anyhow!("BitBox wallet policy keys require an account derivation path")
            })?;
        let device_keychain_branches = self
            .key_roles
            .iter()
            .find_map(|(key_index, branches)| {
                (*key_index == primary_device_key_index).then_some(*branches)
            })
            .ok_or_else(|| {
                anyhow!("the connected BitBox key is missing its derivation branches")
            })?;
        let mut device_keys: Vec<WalletPolicyDeviceKey> = Vec::new();
        for matching_index in matching_key_indices {
            for (key_index, branches) in &self.key_roles {
                if key_index == matching_index {
                    let device_key = self.keys[*key_index].to_device_key(*branches)?;
                    if let Some(existing) = device_keys.iter_mut().find(|existing| {
                        existing.root_fingerprint == device_key.root_fingerprint
                            && existing.account_keypath == device_key.account_keypath
                            && existing.xpub == device_key.xpub
                    }) {
                        for branch in device_key.derivation_branches {
                            if !existing.derivation_branches.contains(&branch) {
                                existing.derivation_branches.push(branch);
                            }
                        }
                    } else {
                        device_keys.push(device_key);
                    }
                }
            }
        }

        match &self.template {
            ScriptTemplate::Multisig {
                threshold,
                script_type,
            } => {
                let xpubs = self.keys.iter().map(|key| key.xpub).collect::<Vec<_>>();
                let script_config = make_script_config_multisig(
                    *threshold,
                    &xpubs,
                    primary_device_key_index as u32,
                    *script_type,
                );
                Ok(PreparedWalletPolicy {
                    script_config,
                    registration_keypath: Some(device_account_keypath.clone()),
                    device_account_keypath,
                    device_keychain_branches,
                    device_keys,
                })
            }
            ScriptTemplate::Miniscript { policy } => {
                let keys = self
                    .keys
                    .iter()
                    .map(AccountKey::to_key_origin_info)
                    .collect::<Vec<_>>();
                Ok(PreparedWalletPolicy {
                    script_config: make_script_config_policy(policy, &keys),
                    registration_keypath: None,
                    device_account_keypath,
                    device_keychain_branches,
                    device_keys,
                })
            }
        }
    }

    fn multisig(
        threshold: usize,
        descriptor_keys: &[DescriptorPublicKey],
        script_type: pb::btc_script_config::multisig::ScriptType,
        expected_network: NetworkKind,
    ) -> Result<Self> {
        let normalized_keys = descriptor_keys
            .iter()
            .map(|key| normalize_account_key(key, expected_network))
            .collect::<Result<Vec<_>>>()?;
        if !(2..=MAX_MULTISIG_KEYS).contains(&normalized_keys.len()) {
            bail!("BitBox multisig wallets require between 2 and 15 distinct keys");
        }
        if normalized_keys
            .iter()
            .map(|(key, _)| key.xpub)
            .collect::<HashSet<_>>()
            .len()
            != normalized_keys.len()
        {
            bail!("BitBox multisig wallet keys must use distinct extended public keys");
        }
        let keychain_branches = normalized_keys
            .iter()
            .map(|(_, branches)| *branches)
            .collect::<Vec<_>>();
        if keychain_branches
            .iter()
            .any(|branches| *branches != keychain_branches[0])
        {
            bail!("multisig wallet policy keys must use the same derivation branches");
        }
        if keychain_branches[0] != [0, 1] {
            bail!("BitBox native multisig wallets require <0;1> derivation branches");
        }
        let key_roles = keychain_branches.iter().copied().enumerate().collect();
        Ok(Self {
            template: ScriptTemplate::Multisig {
                threshold: threshold as u32,
                script_type,
            },
            keys: normalized_keys.into_iter().map(|(key, _)| key).collect(),
            key_roles,
        })
    }

    fn miniscript(
        descriptor: &Descriptor<DescriptorPublicKey>,
        expected_network: NetworkKind,
    ) -> Result<Self> {
        validate_miniscript_depth(descriptor)?;
        let mut translator = PolicyTranslator::new(expected_network);
        if let Descriptor::Tr(taproot) = descriptor {
            let (internal_key, _, _) = wallet_policy_key(taproot.internal_key(), expected_network)?;
            translator.key_index(internal_key)?;
        }
        let translated = descriptor
            .translate_pk(&mut translator)
            .map_err(|error| match error {
                miniscript::TranslateErr::TranslatorErr(error) => error,
                miniscript::TranslateErr::OuterError(error) => {
                    anyhow!("invalid descriptor: {error}")
                }
            })?;
        if translator.keys.len() > MAX_POLICY_KEYS {
            bail!("BitBox wallet policies support at most 20 keys");
        }
        Ok(Self {
            template: ScriptTemplate::Miniscript {
                policy: format!("{translated:#}"),
            },
            keys: translator.keys,
            key_roles: translator.key_roles,
        })
    }
}

fn validate_miniscript_depth(descriptor: &Descriptor<DescriptorPublicKey>) -> Result<()> {
    let too_deep = match descriptor {
        Descriptor::Wsh(wsh) => match wsh.as_inner() {
            WshInner::Ms(miniscript) => miniscript.ext.tree_height >= MAX_MINISCRIPT_TREE_HEIGHT,
            WshInner::SortedMulti(_) => false,
        },
        Descriptor::Tr(taproot) => taproot
            .iter_scripts()
            .any(|(_, miniscript)| miniscript.ext.tree_height >= MAX_MINISCRIPT_TREE_HEIGHT),
        _ => false,
    };
    if too_deep {
        bail!("BitBox wallet policy spending conditions are too deeply nested");
    }
    Ok(())
}

#[derive(Debug, Clone)]
pub(crate) struct PreparedWalletPolicy {
    pub(crate) script_config: pb::BtcScriptConfig,
    pub(crate) registration_keypath: Option<DerivationPath>,
    pub(crate) device_account_keypath: DerivationPath,
    device_keychain_branches: [u32; 2],
    device_keys: Vec<WalletPolicyDeviceKey>,
}

#[derive(Debug, Clone)]
pub(crate) struct WalletPolicyDeviceKey {
    pub(crate) root_fingerprint: Fingerprint,
    pub(crate) account_keypath: DerivationPath,
    pub(crate) xpub: Xpub,
    pub(crate) derivation_branches: Vec<u32>,
}

impl PreparedWalletPolicy {
    pub(crate) fn is_miniscript(&self) -> bool {
        matches!(
            self.script_config.config.as_ref(),
            Some(pb::btc_script_config::Config::Policy(_))
        )
    }

    pub(crate) fn is_taproot(&self) -> bool {
        matches!(
            self.script_config.config.as_ref(),
            Some(pb::btc_script_config::Config::Policy(policy))
                if policy.policy.starts_with("tr(")
        )
    }

    pub(crate) fn script_config_with_keypath(
        &self,
        device_key: &WalletPolicyDeviceKey,
    ) -> pb::BtcScriptConfigWithKeypath {
        pb::BtcScriptConfigWithKeypath {
            script_config: Some(self.script_config.clone()),
            keypath: bitbox_api::Keypath::from(&device_key.account_keypath).to_vec(),
        }
    }

    pub(crate) fn device_keys(&self) -> &[WalletPolicyDeviceKey] {
        &self.device_keys
    }

    pub(crate) fn address_keypath(&self, change: bool, index: u32) -> DerivationPath {
        let branch = self.device_keychain_branches[usize::from(change)];
        self.device_account_keypath
            .into_iter()
            .cloned()
            .chain([
                ChildNumber::Normal { index: branch },
                ChildNumber::Normal { index },
            ])
            .collect()
    }

    pub(crate) fn has_standard_multisig_keypath(&self, testnet: bool) -> bool {
        if self.device_keychain_branches != [0, 1] {
            return false;
        }
        let coin_type = if testnet { 1 } else { 0 };
        let script_type = match &self.script_config.config {
            Some(pb::btc_script_config::Config::Multisig(multisig)) => multisig.script_type,
            _ => return false,
        };
        let expected_script_type =
            if script_type == pb::btc_script_config::multisig::ScriptType::P2wsh as i32 {
                2
            } else if script_type == pb::btc_script_config::multisig::ScriptType::P2wshP2sh as i32 {
                1
            } else {
                return false;
            };
        match self.device_account_keypath.as_ref() {
            [ChildNumber::Hardened { index: 48 }, ChildNumber::Hardened { index: coin }, ChildNumber::Hardened { index: account }] => {
                *coin == coin_type && *account <= 99
            }
            [ChildNumber::Hardened { index: 48 }, ChildNumber::Hardened { index: coin }, ChildNumber::Hardened { index: account }, ChildNumber::Hardened { index: script }] => {
                *coin == coin_type && *account <= 99 && *script == expected_script_type
            }
            _ => false,
        }
    }
}

struct PolicyTranslator {
    expected_network: NetworkKind,
    key_indices: HashMap<Xpub, usize>,
    used_branches: HashMap<Xpub, HashSet<u32>>,
    keys: Vec<AccountKey>,
    key_roles: Vec<(usize, [u32; 2])>,
}

impl PolicyTranslator {
    fn new(expected_network: NetworkKind) -> Self {
        Self {
            expected_network,
            key_indices: HashMap::new(),
            used_branches: HashMap::new(),
            keys: Vec::new(),
            key_roles: Vec::new(),
        }
    }

    fn key_role(&mut self, key: AccountKey, branches: [u32; 2]) -> Result<usize> {
        let index = self.key_index(key.clone())?;
        let used_branches = self.used_branches.entry(key.xpub).or_default();
        if branches.iter().any(|branch| used_branches.contains(branch)) {
            bail!("repeated wallet policy keys must use disjoint derivation branches");
        }
        used_branches.extend(branches);
        self.key_roles.push((index, branches));
        Ok(index)
    }

    fn key_index(&mut self, key: AccountKey) -> Result<usize> {
        if let Some(index) = self.key_indices.get(&key.xpub) {
            if self.keys[*index] != key {
                bail!("the same wallet policy xpub has inconsistent key origins");
            }
            return Ok(*index);
        }

        let index = self.keys.len();
        self.key_indices.insert(key.xpub, index);
        self.keys.push(key);
        Ok(index)
    }
}

impl Translator<DescriptorPublicKey, String, anyhow::Error> for PolicyTranslator {
    fn pk(&mut self, key: &DescriptorPublicKey) -> Result<String> {
        let (account_key, branches, derivation) = wallet_policy_key(key, self.expected_network)?;
        let index = self.key_role(account_key, branches)?;
        Ok(format!("@{index}{derivation}"))
    }

    fn sha256(
        &mut self,
        _hash: &<DescriptorPublicKey as miniscript::MiniscriptKey>::Sha256,
    ) -> Result<String> {
        bail!("BitBox firmware does not support Miniscript hashlocks")
    }

    fn hash256(
        &mut self,
        _hash: &<DescriptorPublicKey as miniscript::MiniscriptKey>::Hash256,
    ) -> Result<String> {
        bail!("BitBox firmware does not support Miniscript hashlocks")
    }

    fn ripemd160(
        &mut self,
        _hash: &<DescriptorPublicKey as miniscript::MiniscriptKey>::Ripemd160,
    ) -> Result<String> {
        bail!("BitBox firmware does not support Miniscript hashlocks")
    }

    fn hash160(
        &mut self,
        _hash: &<DescriptorPublicKey as miniscript::MiniscriptKey>::Hash160,
    ) -> Result<String> {
        bail!("BitBox firmware does not support Miniscript hashlocks")
    }
}

fn wallet_policy_key(
    key: &DescriptorPublicKey,
    expected_network: NetworkKind,
) -> Result<(AccountKey, [u32; 2], String)> {
    let (account_key, branches) = normalize_account_key(key, expected_network)?;
    let derivation = if branches == [0, 1] {
        "/**".to_string()
    } else {
        format!("/<{};{}>/*", branches[0], branches[1])
    };
    Ok((account_key, branches, derivation))
}

fn normalize_account_key(
    key: &DescriptorPublicKey,
    expected_network: NetworkKind,
) -> Result<(AccountKey, [u32; 2])> {
    let descriptor_key = match key {
        DescriptorPublicKey::MultiXPub(key) => key,
        DescriptorPublicKey::Single(_) => {
            bail!("every descriptor key must be an extended public key")
        }
        DescriptorPublicKey::XPub(_) => {
            bail!("descriptor keys must use two unhardened derivation branches")
        }
    };
    if descriptor_key.xkey.network != expected_network {
        bail!("descriptor extended public key network does not match the selected Bitcoin network");
    }
    if descriptor_key.wildcard != Wildcard::Unhardened {
        bail!("descriptor keys must use two unhardened derivation branches");
    }

    let derivation_paths = descriptor_key.derivation_paths.paths();
    if derivation_paths.len() != 2 {
        bail!("descriptor keys must use two unhardened derivation branches");
    }
    let (account_suffix, branches) = account_suffix(&derivation_paths[0], &derivation_paths[1])?;
    let secp = Secp256k1::verification_only();
    let xpub = descriptor_key
        .xkey
        .derive_pub(&secp, &account_suffix)
        .map_err(|_| {
            anyhow!("descriptor keys cannot use hardened derivation after the extended public key")
        })?;
    let (root_fingerprint, account_keypath) = match &descriptor_key.origin {
        Some((fingerprint, origin_path)) => (
            Some(*fingerprint),
            Some(
                origin_path
                    .into_iter()
                    .cloned()
                    .chain(account_suffix.into_iter().cloned())
                    .collect(),
            ),
        ),
        None => (None, None),
    };

    Ok((
        AccountKey {
            root_fingerprint,
            account_keypath,
            xpub,
        },
        branches,
    ))
}

fn account_suffix(
    receive_path: &DerivationPath,
    change_path: &DerivationPath,
) -> Result<(DerivationPath, [u32; 2])> {
    if receive_path.len() != change_path.len() || receive_path.is_empty() {
        bail!("descriptor keys must use two unhardened derivation branches");
    }
    let branch_index = receive_path.len() - 1;
    let branches = match (receive_path[branch_index], change_path[branch_index]) {
        (ChildNumber::Normal { index: receive }, ChildNumber::Normal { index: change })
            if receive != change =>
        {
            [receive, change]
        }
        _ => bail!("descriptor keys must use two distinct unhardened derivation branches"),
    };
    if receive_path[..branch_index] != change_path[..branch_index] {
        bail!("descriptor derivation branches must share the same account path");
    }
    Ok((receive_path[..branch_index].to_vec().into(), branches))
}

#[cfg(test)]
mod tests {
    use super::*;
    use bitcoin::bip32::Xpriv;
    use bitcoin::Network;

    #[test]
    fn prepares_native_multisig_config() {
        let first = test_account_key(1, "m/48'/1'/0'");
        let second = test_account_key(2, "m/48'/1'/0'");
        let descriptor = format!(
            "wsh(sortedmulti(2,{},{}))",
            first.descriptor, second.descriptor
        );
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let device_xpubs = HashMap::from([(second.keypath.clone(), second.xpub)]);

        let matching_keys = parsed.matching_device_key_indices(second.fingerprint, &device_xpubs);
        let prepared = parsed.prepare(&matching_keys).unwrap();

        let multisig = match prepared.script_config.config.as_ref().unwrap() {
            pb::btc_script_config::Config::Multisig(multisig) => multisig,
            _ => panic!("expected native multisig configuration"),
        };
        assert_eq!(multisig.threshold, 2);
        assert_eq!(multisig.xpubs.len(), 2);
        assert_eq!(multisig.our_xpub_index, 1);
        assert_eq!(
            multisig.script_type,
            pb::btc_script_config::multisig::ScriptType::P2wsh as i32
        );
        assert_eq!(prepared.registration_keypath, Some(second.keypath));
        assert_eq!(
            prepared.address_keypath(false, 7),
            "m/48'/1'/0'/0/7".parse().unwrap()
        );
        assert_eq!(
            prepared.address_keypath(true, 7),
            "m/48'/1'/0'/1/7".parse().unwrap()
        );
        assert!(prepared.has_standard_multisig_keypath(true));
    }

    #[test]
    fn prepares_nested_segwit_multisig_config() {
        let first = test_account_key(1, "m/48'/1'/0'/1'");
        let second = test_account_key(2, "m/48'/1'/0'/1'");
        let descriptor = format!(
            "sh(wsh(sortedmulti(2,{},{})))",
            first.descriptor, second.descriptor
        );
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let device_xpubs = HashMap::from([(first.keypath.clone(), first.xpub)]);
        let matching_keys = parsed.matching_device_key_indices(first.fingerprint, &device_xpubs);

        let prepared = parsed.prepare(&matching_keys).unwrap();

        let multisig = match prepared.script_config.config.as_ref().unwrap() {
            pb::btc_script_config::Config::Multisig(multisig) => multisig,
            _ => panic!("expected native multisig configuration"),
        };
        assert_eq!(
            multisig.script_type,
            pb::btc_script_config::multisig::ScriptType::P2wshP2sh as i32
        );
        assert!(prepared.has_standard_multisig_keypath(true));
    }

    #[test]
    fn prepares_miniscript_wallet_policy_with_key_origins() {
        let first = test_account_key(1, "m/48'/1'/0'/3'");
        let recovery_descriptor = first.descriptor.replace("<0;1>", "<2;3>");
        let descriptor = format!(
            "wsh(or_d(pk({}),and_v(v:older(20),pk({}))))",
            first.descriptor, recovery_descriptor
        );
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let device_xpubs = HashMap::from([(first.keypath.clone(), first.xpub)]);
        let matching_keys = parsed.matching_device_key_indices(first.fingerprint, &device_xpubs);

        let prepared = parsed.prepare(&matching_keys).unwrap();

        let policy = match prepared.script_config.config.as_ref().unwrap() {
            pb::btc_script_config::Config::Policy(policy) => policy,
            _ => panic!("expected wallet policy configuration"),
        };
        assert_eq!(
            policy.policy,
            "wsh(or_d(pk(@0/**),and_v(v:older(20),pk(@0/<2;3>/*))))"
        );
        assert_eq!(policy.keys.len(), 1);
        assert_eq!(matching_keys, vec![0]);
        assert_eq!(
            prepared
                .device_keys
                .iter()
                .map(|key| key.derivation_branches.clone())
                .collect::<Vec<_>>(),
            vec![vec![0, 1, 2, 3]]
        );
        assert_eq!(prepared.registration_keypath, None);
        assert_eq!(
            prepared.address_keypath(false, 7),
            "m/48'/1'/0'/3'/0/7".parse().unwrap()
        );
        assert_eq!(
            prepared.address_keypath(true, 7),
            "m/48'/1'/0'/3'/1/7".parse().unwrap()
        );
    }

    #[test]
    fn normalizes_fixed_derivation_before_multipath_branches() {
        let key = test_account_key(1, "m/48'/1'/0'/3'");
        let descriptor = format!(
            "wsh(pk({}))",
            key.descriptor.replace("/<0;1>/*", "/2/<0;1>/*")
        );
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let derived_keypath = "m/48'/1'/0'/3'/2".parse::<DerivationPath>().unwrap();
        let derived_xpub = key
            .xpub
            .derive_pub(
                &Secp256k1::verification_only(),
                &"m/2".parse::<DerivationPath>().unwrap(),
            )
            .unwrap();
        let device_xpubs = HashMap::from([(derived_keypath.clone(), derived_xpub)]);
        let matching_keys = parsed.matching_device_key_indices(key.fingerprint, &device_xpubs);

        let prepared = parsed.prepare(&matching_keys).unwrap();
        let policy = match prepared.script_config.config.as_ref().unwrap() {
            pb::btc_script_config::Config::Policy(policy) => policy,
            _ => panic!("expected wallet policy configuration"),
        };

        assert_eq!(policy.policy, "wsh(pk(@0/**))");
        let expected_key: pb::KeyOriginInfo = AccountKey {
            root_fingerprint: Some(key.fingerprint),
            account_keypath: Some(derived_keypath),
            xpub: derived_xpub,
        }
        .to_key_origin_info()
        .into();
        assert_eq!(policy.keys[0].xpub, expected_key.xpub);
    }

    #[test]
    fn prepares_taproot_miniscript_wallet_policy() {
        let first = test_account_key(1, "m/48'/1'/0'/2'");
        let second = test_account_key(2, "m/48'/1'/0'/2'");
        let recovery = first.descriptor.replace("<0;1>", "<2;3>");
        let unspendable = "tpubD6NzVbkrYhZ4XokGX5s1FcKj2ozqibXqXc79NkzEbNQvT1j9F7YWe3fPp3eDeMVypHXocGWUkVaC6ZUqMqyQRS27XJcujQLbrqzpoYYLGW5/<0;1>/*";
        let descriptor = format!(
            "tr({unspendable},{{multi_a(2,{},{}),and_v(v:older(10),pk({recovery}))}})",
            first.descriptor, second.descriptor
        );
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let device_xpubs = HashMap::from([(first.keypath.clone(), first.xpub)]);
        let matching_keys = parsed.matching_device_key_indices(first.fingerprint, &device_xpubs);

        let prepared = parsed.prepare(&matching_keys).unwrap();

        let policy = match prepared.script_config.config.as_ref().unwrap() {
            pb::btc_script_config::Config::Policy(policy) => policy,
            _ => panic!("expected wallet policy configuration"),
        };
        assert_eq!(
            policy.policy,
            "tr(@0/**,{multi_a(2,@1/**,@2/**),and_v(v:older(10),pk(@1/<2;3>/*))})"
        );
        assert_eq!(policy.keys.len(), 3);
        assert_eq!(matching_keys, vec![1]);
        assert!(prepared.is_taproot());
        assert_eq!(prepared.registration_keypath, None);
    }

    #[test]
    fn matching_a_device_requires_its_exact_account_xpub() {
        let expected = test_account_key(1, "m/48'/1'/0'/2'");
        let other = test_account_key(2, "m/48'/1'/0'/2'");
        let descriptor = format!(
            "wsh(sortedmulti(1,{},{}))",
            expected.descriptor, other.descriptor
        );
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let device_xpubs = HashMap::from([(expected.keypath, other.xpub)]);

        let matching_keys = parsed.matching_device_key_indices(expected.fingerprint, &device_xpubs);

        assert!(matching_keys.is_empty());
        assert_eq!(
            parsed.prepare(&matching_keys).unwrap_err().to_string(),
            "the connected BitBox does not control a key in this descriptor"
        );

        let first = test_account_key(1, "m/48'/1'/0'/3'");
        let second = test_account_key(1, "m/48'/1'/1'/3'");
        let descriptor = format!(
            "wsh(or_d(pk({}),pk({})))",
            first.descriptor, second.descriptor
        );
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let device_xpubs =
            HashMap::from([(first.keypath, first.xpub), (second.keypath, second.xpub)]);
        let matching_keys = parsed.matching_device_key_indices(first.fingerprint, &device_xpubs);

        assert_eq!(
            parsed.prepare(&matching_keys).unwrap_err().to_string(),
            "BitBox wallet policies must use one account key from the connected device"
        );

        let master = Xpriv::new_master(Network::Testnet, &[3; 32]).unwrap();
        let secp = Secp256k1::new();
        let fingerprint = master.fingerprint(&secp);
        let master_xpub = Xpub::from_priv(&secp, &master);
        let descriptor = format!("wsh(pk([{fingerprint}]{master_xpub}/<0;1>/*))");
        let parsed = ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test).unwrap();
        let device_xpubs = HashMap::from([(DerivationPath::master(), master_xpub)]);
        let matching_keys = parsed.matching_device_key_indices(fingerprint, &device_xpubs);

        assert_eq!(
            parsed.prepare(&matching_keys).unwrap_err().to_string(),
            "BitBox wallet policy keys require an account derivation path"
        );
    }

    #[test]
    fn rejects_descriptor_forms_bitbox_cannot_represent() {
        let key = test_account_key(1, "m/48'/1'/0'/3'");
        let nested_miniscript = format!("sh(wsh(pk({})))", key.descriptor);
        let fixed_key = format!("wsh(pk({}))", key.xpub.public_key);
        let hardened_suffix = format!(
            "wsh(pk({}))",
            key.descriptor.replace("/<0;1>/*", "/0'/<0;1>/*")
        );
        let unsupported_suffix = format!(
            "wsh(pk({}))",
            key.descriptor.replace("/<0;1>/*", "/<0;1>/2/*")
        );
        let other = test_account_key(2, "m/48'/1'/0'/3'");
        let mixed_multisig = format!(
            "wsh(sortedmulti(2,{},{}))",
            key.descriptor,
            other.descriptor.replace("<0;1>", "<2;3>")
        );
        let custom_multisig = format!(
            "wsh(sortedmulti(2,{},{}))",
            key.descriptor.replace("<0;1>", "<2;3>"),
            other.descriptor.replace("<0;1>", "<2;3>")
        );
        let repeated_taproot_key = format!("tr({},pk({}))", key.descriptor, key.descriptor);
        let hashlock = format!(
            "wsh(and_v(v:pk({}),sha256(630dcd2966c4336691125448bbb25b4ff412a49c732db2c8abc1b8581bd710dd)))",
            key.descriptor
        );

        assert_eq!(
            ParsedWalletPolicy::parse(&nested_miniscript, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "BitBox supports only native or nested SegWit multisig and native SegWit Miniscript policies"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&fixed_key, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "every descriptor key must be an extended public key"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&format!("wsh(pk({}))", key.descriptor), NetworkKind::Main)
                .unwrap_err()
                .to_string(),
            "descriptor extended public key network does not match the selected Bitcoin network"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&hardened_suffix, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "descriptor keys cannot use hardened derivation after the extended public key"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&unsupported_suffix, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "descriptor keys must use two distinct unhardened derivation branches"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&mixed_multisig, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "multisig wallet policy keys must use the same derivation branches"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&custom_multisig, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "BitBox native multisig wallets require <0;1> derivation branches"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&repeated_taproot_key, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "repeated wallet policy keys must use disjoint derivation branches"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&hashlock, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "BitBox firmware does not support Miniscript hashlocks"
        );
    }

    #[test]
    fn rejects_wallet_policies_outside_device_resource_limits() {
        let keys = (1..=21)
            .map(|seed| test_account_key(seed, "m/48'/1'/0'/3'"))
            .collect::<Vec<_>>();
        let too_many_multisig_keys = format!(
            "wsh(sortedmulti(2,{}))",
            keys[..16]
                .iter()
                .map(|key| key.descriptor.as_str())
                .collect::<Vec<_>>()
                .join(",")
        );
        let too_many_policy_keys = format!(
            "tr({},multi_a(1,{}))",
            keys[0].descriptor,
            keys[1..]
                .iter()
                .map(|key| key.descriptor.as_str())
                .collect::<Vec<_>>()
                .join(",")
        );
        let too_deep = format!(
            "wsh({}:pk({}))",
            "n".repeat(MAX_MINISCRIPT_TREE_HEIGHT),
            keys[0].descriptor
        );

        assert_eq!(
            ParsedWalletPolicy::parse(&too_many_multisig_keys, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "BitBox multisig wallets require between 2 and 15 distinct keys"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&too_many_policy_keys, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "BitBox wallet policies support at most 20 keys"
        );
        assert_eq!(
            ParsedWalletPolicy::parse(&too_deep, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "BitBox wallet policy spending conditions are too deeply nested"
        );
    }

    #[test]
    fn rejects_multisig_keys_that_normalize_to_the_same_xpub() {
        let key = test_account_key(1, "m/48'/1'/0'/3'");
        let derived_xpub = key
            .xpub
            .derive_pub(
                &Secp256k1::verification_only(),
                &"m/2".parse::<DerivationPath>().unwrap(),
            )
            .unwrap();
        let derived_descriptor = format!(
            "[{}{}/2]{derived_xpub}/<0;1>/*",
            key.fingerprint,
            path_without_master(&key.keypath)
        );
        let descriptor = format!(
            "wsh(sortedmulti(2,{},{}))",
            key.descriptor.replace("/<0;1>/*", "/2/<0;1>/*"),
            derived_descriptor
        );

        assert_eq!(
            ParsedWalletPolicy::parse(&descriptor, NetworkKind::Test)
                .unwrap_err()
                .to_string(),
            "BitBox multisig wallet keys must use distinct extended public keys"
        );
    }

    struct TestAccountKey {
        descriptor: String,
        fingerprint: Fingerprint,
        keypath: DerivationPath,
        xpub: Xpub,
    }

    fn test_account_key(seed_byte: u8, keypath: &str) -> TestAccountKey {
        let secp = Secp256k1::new();
        let master = Xpriv::new_master(Network::Testnet, &[seed_byte; 32]).unwrap();
        let fingerprint = master.fingerprint(&secp);
        let keypath = keypath.parse::<DerivationPath>().unwrap();
        let account_xpriv = master.derive_priv(&secp, &keypath).unwrap();
        let xpub = Xpub::from_priv(&secp, &account_xpriv);
        TestAccountKey {
            descriptor: format!(
                "[{fingerprint}{}]{xpub}/<0;1>/*",
                path_without_master(&keypath)
            ),
            fingerprint,
            keypath,
            xpub,
        }
    }

    fn path_without_master(keypath: &DerivationPath) -> String {
        keypath
            .into_iter()
            .map(|child| format!("/{child}"))
            .collect()
    }
}
