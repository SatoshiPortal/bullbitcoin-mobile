use flutter_rust_bridge::frb;

/// Liquid Bitcoin mainnet asset ID
pub const L_BTC_ASSET_ID: &str =
    "6f0279e9ed041c3d710a9f57d0c02928416460c4b722ae3457a11eec381c526d";

/// Liquid Bitcoin testnet asset ID
pub const L_TEST_ASSET_ID: &str =
    "144c654344aa716d6f3abcc1ca90e5641e4e2a7f633bc09fe3baf64585819a49";

/// Default policy asset of an Elements regtest node (`chain=liquidregtest`), as in lwk
pub const L_REGTEST_ASSET_ID: &str =
    "5ac9f65c0efcc4775e0baec4ec03abdde22473cd3cf33c0419ca290e0751b225";

/// Get balance value for a specific asset ID from a list of balances
#[frb(sync)]
pub fn get_balance_by_asset_id(balances: Vec<WalletBalance>, asset_id: String) -> u64 {
    balances
        .iter()
        .find(|b| b.asset_id == asset_id)
        .map(|b| b.value)
        .unwrap_or(0)
}

/// Get L-BTC mainnet balance
#[frb(sync)]
pub fn get_lbtc_balance(balances: Vec<WalletBalance>) -> u64 {
    get_balance_by_asset_id(balances, L_BTC_ASSET_ID.to_string())
}

/// Get L-BTC testnet balance
#[frb(sync)]
pub fn get_ltest_balance(balances: Vec<WalletBalance>) -> u64 {
    get_balance_by_asset_id(balances, L_TEST_ASSET_ID.to_string())
}

/// Get L-BTC mainnet asset ID
#[frb(sync)]
pub fn get_lbtc_asset_id() -> String {
    L_BTC_ASSET_ID.to_string()
}

/// Get L-BTC testnet asset ID
#[frb(sync)]
pub fn get_ltest_asset_id() -> String {
    L_TEST_ASSET_ID.to_string()
}

use lwk_common::PsetBalance;
use lwk_wollet::{
    elements::{
        self,
        pset::PartiallySignedTransaction,
        Address as LwkAddress, AddressParams, AssetId, Script,
    },
    secp256k1, AddressResult, WalletTx, WalletTxOut,
};
pub use std::collections::{BTreeMap, HashMap};
use std::str::FromStr;
pub use std::vec::Vec;

use lwk_common::Network as ElementsNetwork;
use std::convert::TryFrom;

use super::error::LwkError;

#[derive(Clone, Copy, PartialEq, Debug)]
pub enum LiquidNetwork {
    Mainnet,
    Testnet,
    /// Local Elements regtest, with testnet keys and `el`/`ert` addresses.
    ///
    /// Its policy asset is the node's own: the default is lwk's, a wallet can take another.
    Regtest,
}

impl LiquidNetwork {
    pub(crate) fn address_params(self) -> &'static AddressParams {
        match self {
            LiquidNetwork::Mainnet => &AddressParams::LIQUID,
            LiquidNetwork::Testnet => &AddressParams::LIQUID_TESTNET,
            LiquidNetwork::Regtest => &AddressParams::ELEMENTS,
        }
    }

    /// The lwk network, with `policy_asset` replacing the default regtest policy asset.
    ///
    /// Mainnet and testnet have a fixed policy asset, so `policy_asset` is rejected there.
    pub(crate) fn elements_network(
        self,
        policy_asset: Option<String>,
    ) -> anyhow::Result<ElementsNetwork, LwkError> {
        match (self, policy_asset) {
            (network, None) => Ok(network.into()),
            (LiquidNetwork::Regtest, Some(policy_asset)) => {
                let policy_asset = AssetId::from_str(&policy_asset)?;
                Ok(ElementsNetwork::CustomElements(
                    lwk_common::ElementsParamsBuilder::new()
                        .with_policy_asset(policy_asset)
                        .build()
                        .map_err(|e| LwkError { msg: e.to_string() })?,
                ))
            }
            (network, Some(_)) => Err(LwkError {
                msg: format!("{network:?} has a fixed policy asset"),
            }),
        }
    }
}

/// Every custom Elements network is regtest: [`LiquidNetwork::elements_network`] builds no other.
impl From<ElementsNetwork> for LiquidNetwork {
    fn from(network: ElementsNetwork) -> Self {
        match network {
            ElementsNetwork::Liquid => LiquidNetwork::Mainnet,
            ElementsNetwork::TestnetLiquid => LiquidNetwork::Testnet,
            ElementsNetwork::CustomElements(_) => LiquidNetwork::Regtest,
        }
    }
}

impl Into<ElementsNetwork> for LiquidNetwork {
    fn into(self) -> ElementsNetwork {
        match self {
            LiquidNetwork::Mainnet => ElementsNetwork::Liquid,
            LiquidNetwork::Testnet => ElementsNetwork::TestnetLiquid,
            LiquidNetwork::Regtest => ElementsNetwork::default_regtest(),
        }
    }
}

pub struct AssetIdBTreeMapUInt(BTreeMap<AssetId, u64>);
pub struct AssetIdBTreeMapInt(BTreeMap<AssetId, i64>);
pub struct AssetIdHashMapInt(HashMap<AssetId, i64>);
pub struct AssetIdHashMapUInt(HashMap<AssetId, u64>);

// Implement From for BTreeMap and HashMap
impl From<BTreeMap<AssetId, i64>> for AssetIdBTreeMapInt {
    fn from(map: BTreeMap<AssetId, i64>) -> Self {
        AssetIdBTreeMapInt(map)
    }
}

impl From<BTreeMap<AssetId, u64>> for AssetIdBTreeMapUInt {
    fn from(map: BTreeMap<AssetId, u64>) -> Self {
        AssetIdBTreeMapUInt(map)
    }
}

impl From<HashMap<AssetId, i64>> for AssetIdHashMapInt {
    fn from(map: HashMap<AssetId, i64>) -> Self {
        AssetIdHashMapInt(map)
    }
}
impl From<HashMap<AssetId, u64>> for AssetIdHashMapUInt {
    fn from(map: HashMap<AssetId, u64>) -> Self {
        AssetIdHashMapUInt(map)
    }
}
/// Balance represents a balance of a specific asset
#[derive(Clone, Debug, PartialEq)]
pub struct Balance {
    pub asset_id: String,
    pub value: i64,
}

/// Balances is a list of Balance objects
/// A multi asset wallet will have more than one item in the list for each asset
pub type Balances = Vec<Balance>;

/// WalletBalance represents a non-negative amount held by a wallet.
#[derive(Clone, Debug, PartialEq)]
pub struct WalletBalance {
    pub asset_id: String,
    pub value: u64,
}

/// Current wallet balances, keyed by asset.
pub type WalletBalances = Vec<WalletBalance>;

impl From<AssetIdBTreeMapInt> for Balances {
    fn from(asset_id_map: AssetIdBTreeMapInt) -> Self {
        asset_id_map
            .0
            .into_iter()
            .map(|(key, value)| Balance {
                asset_id: key.to_string(),
                value,
            })
            .collect()
    }
}
impl From<AssetIdHashMapInt> for Balances {
    fn from(asset_id_map: AssetIdHashMapInt) -> Self {
        asset_id_map
            .0
            .into_iter()
            .map(|(key, value)| Balance {
                asset_id: key.to_string(),
                value,
            })
            .collect()
    }
}

impl From<AssetIdBTreeMapUInt> for WalletBalances {
    fn from(asset_id_map: AssetIdBTreeMapUInt) -> Self {
        asset_id_map
            .0
            .into_iter()
            .map(|(key, value)| WalletBalance {
                asset_id: key.to_string(),
                value,
            })
            .collect()
    }
}

impl From<AssetIdHashMapUInt> for WalletBalances {
    fn from(asset_id_map: AssetIdHashMapUInt) -> Self {
        asset_id_map
            .0
            .into_iter()
            .map(|(key, value)| WalletBalance {
                asset_id: key.to_string(),
                value,
            })
            .collect()
    }
}

impl From<elements::TxOutSecrets> for TxOutSecrets {
    fn from(value: elements::TxOutSecrets) -> Self {
        TxOutSecrets {
            value: value.value,
            value_bf: value.value_bf.to_string(),
            asset: value.asset.to_string(),
            asset_bf: value.asset_bf.to_string(),
        }
    }
}

impl From<WalletTxOut> for TxOut {
    fn from(wallet_tx_out: WalletTxOut) -> Self {
        TxOut {
            script_pubkey: hex::encode(wallet_tx_out.script_pubkey.as_bytes()),
            height: wallet_tx_out.height,
            unblinded: wallet_tx_out.unblinded.into(),
            outpoint: OutPoint {
                txid: wallet_tx_out.outpoint.txid.to_string(),
                vout: wallet_tx_out.outpoint.vout,
            },
            address: Address::from(wallet_tx_out.address.clone()),
            is_spent: wallet_tx_out.is_spent,
        }
    }
}

/// Address class which contains both standard and confidential addresses with the address index in the wallet
#[derive(Clone, Debug, PartialEq)]
pub struct Address {
    pub standard: String,
    pub confidential: String,
    pub index: Option<u32>,
    pub blinding_key: Option<String>,
}

impl From<AddressResult> for Address {
    fn from(address: AddressResult) -> Self {
        Address {
            standard: address.address().to_unconfidential().to_string(),
            confidential: address.address().to_string(),
            index: Some(address.index()),
            blinding_key: address.address().blinding_pubkey.map(|pk| pk.to_string()),
        }
    }
}
impl From<LwkAddress> for Address {
    fn from(address: LwkAddress) -> Self {
        Address {
            standard: address.to_unconfidential().to_string(),
            confidential: address.to_string(),
            index: None,
            blinding_key: address.blinding_pubkey.map(|pk| pk.to_string()),
        }
    }
}

impl Address {
    /// Validate the address string and return the network
    pub fn validate(address_string: String) -> anyhow::Result<LiquidNetwork, LwkError> {
        let address = LwkAddress::from_str(&address_string)?;
        if address.params == &AddressParams::LIQUID {
            Ok(LiquidNetwork::Mainnet)
        } else if address.params == &AddressParams::LIQUID_TESTNET {
            Ok(LiquidNetwork::Testnet)
        } else if address.params == &AddressParams::ELEMENTS {
            Ok(LiquidNetwork::Regtest)
        } else {
            Err(LwkError {
                msg: "Unsupported address network".to_string(),
            })
        }
    }

    /// Create an address from a scriptpubkey. Always returns 0 as the index is only for wallet generated addresses
    pub fn address_from_script(
        network: LiquidNetwork,
        script: String,
        blinding_key: Option<String>,
    ) -> anyhow::Result<Address, LwkError> {
        let blinding_pubkey = if blinding_key == None {
            None
        } else {
            let pubkey = match secp256k1::PublicKey::from_str(&blinding_key.clone().unwrap()) {
                Ok(result) => result,
                Err(e) => return Err(LwkError { msg: e.to_string() }),
            };
            Some(pubkey)
        };
        let script_pubkey = match hex::decode(&script) {
            Ok(result) => Script::from(result),
            Err(e) => return Err(LwkError { msg: e.to_string() }),
        };

        let address =
            LwkAddress::from_script(&script_pubkey, blinding_pubkey, network.address_params());
        if let Some(address) = address {
            Ok(Address {
                standard: address.to_unconfidential().to_string(),
                confidential: address.to_string(),
                index: None,
                blinding_key: blinding_key,
            })
        } else {
            Err(LwkError {
                msg: "Could not convert script to address".to_string(),
            })
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn address_validate_only_accepts_supported_liquid_networks() {
        let mainnet = "ex1q7gkeyjut0mrxc3j0kjlt7rmcnvsh0gt45d3fud";
        let testnet = "tlq1qq2xvpcvfup5j8zscjq05u2wxxjcyewk7979f3mmz5l7uw5pqmx6xf5xy50hsn6vhkm5euwt72x878eq6zxx2z58hd7zrsg9qn";
        let elements_regtest = "ert1qwhh2n5qypypm0eufahm2pvj8raj9zq5c27cysu";

        assert_eq!(
            Address::validate(mainnet.to_string()).unwrap(),
            LiquidNetwork::Mainnet
        );
        assert_eq!(
            Address::validate(testnet.to_string()).unwrap(),
            LiquidNetwork::Testnet
        );
        assert_eq!(
            Address::validate(elements_regtest.to_string()).unwrap(),
            LiquidNetwork::Regtest
        );
        // Bitcoin addresses are no Liquid network.
        assert!(
            Address::validate("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4".to_string()).is_err()
        );
    }

    fn lwk_network(network: LiquidNetwork) -> ElementsNetwork {
        network.into()
    }

    #[test]
    fn networks_map_to_their_lwk_network() {
        assert_eq!(lwk_network(LiquidNetwork::Mainnet), ElementsNetwork::Liquid);
        assert_eq!(
            lwk_network(LiquidNetwork::Testnet),
            ElementsNetwork::TestnetLiquid
        );
        let regtest: ElementsNetwork = LiquidNetwork::Regtest.into();
        assert_eq!(regtest, ElementsNetwork::default_regtest());
        assert_eq!(regtest.policy_asset().to_string(), L_REGTEST_ASSET_ID);
        assert_eq!(regtest.address_params(), &AddressParams::ELEMENTS);
        assert!(!regtest.is_mainnet());

        assert_eq!(
            lwk_network(LiquidNetwork::Mainnet)
                .policy_asset()
                .to_string(),
            L_BTC_ASSET_ID
        );
        assert_eq!(
            lwk_network(LiquidNetwork::Testnet)
                .policy_asset()
                .to_string(),
            L_TEST_ASSET_ID
        );
    }

    #[test]
    fn lwk_networks_map_back_to_their_liquid_network() {
        for network in [
            LiquidNetwork::Mainnet,
            LiquidNetwork::Testnet,
            LiquidNetwork::Regtest,
        ] {
            assert_eq!(LiquidNetwork::from(lwk_network(network)), network);
        }
        let custom = "b2e15d0d7a0c94e4e2ce0fe6e8691b9e451377f6e46e8045a86f7c4b5d4f0f23";
        let custom = LiquidNetwork::Regtest
            .elements_network(Some(custom.to_string()))
            .unwrap();
        assert_eq!(LiquidNetwork::from(custom), LiquidNetwork::Regtest);
    }

    #[test]
    fn only_regtest_takes_another_policy_asset() {
        let custom = "b2e15d0d7a0c94e4e2ce0fe6e8691b9e451377f6e46e8045a86f7c4b5d4f0f23";
        let network = LiquidNetwork::Regtest
            .elements_network(Some(custom.to_string()))
            .unwrap();
        assert_eq!(network.policy_asset().to_string(), custom);
        assert_eq!(network.address_params(), &AddressParams::ELEMENTS);
        assert_eq!(
            LiquidNetwork::Regtest.elements_network(None).unwrap(),
            ElementsNetwork::default_regtest()
        );

        assert!(LiquidNetwork::Regtest
            .elements_network(Some("not an asset id".to_string()))
            .is_err());
        for network in [LiquidNetwork::Mainnet, LiquidNetwork::Testnet] {
            assert!(network.elements_network(Some(custom.to_string())).is_err());
            assert_eq!(
                network.elements_network(None).unwrap(),
                lwk_network(network)
            );
        }
    }

    #[test]
    fn address_from_script_uses_the_network_address_params() {
        // P2WPKH script of an arbitrary key hash.
        let script = "0014751e76e8199196d454941c45d1b3a323f1433bd6";
        let expected = [
            (LiquidNetwork::Mainnet, "ex1q"),
            (LiquidNetwork::Testnet, "tex1q"),
            (LiquidNetwork::Regtest, "ert1q"),
        ];
        for (network, prefix) in expected {
            let address = Address::address_from_script(network, script.to_string(), None).unwrap();
            assert!(address.standard.starts_with(prefix), "{}", address.standard);
            assert_eq!(Address::validate(address.standard).unwrap(), network);
        }
    }

    #[test]
    fn address_from_script_decodes_a_hex_script_pubkey() {
        let address = Address::address_from_script(
            LiquidNetwork::Mainnet,
            "0014f22d924b8b7ec66c464fb4bebf0f789b2177a175".to_string(),
            None,
        )
        .unwrap();
        assert_eq!(address.standard, "ex1q7gkeyjut0mrxc3j0kjlt7rmcnvsh0gt45d3fud");

        assert!(Address::address_from_script(LiquidNetwork::Mainnet, "0g".to_string(), None)
            .is_err());
        assert!(Address::address_from_script(LiquidNetwork::Mainnet, "001".to_string(), None)
            .is_err());
    }

    #[test]
    fn wallet_balances_preserve_the_full_u64_range() {
        let asset = AssetId::from_str(L_BTC_ASSET_ID).unwrap();
        let balances =
            WalletBalances::from(AssetIdBTreeMapUInt(BTreeMap::from([(asset, u64::MAX)])));

        assert_eq!(balances[0].value, u64::MAX);
        assert_eq!(
            get_balance_by_asset_id(balances, L_BTC_ASSET_ID.to_string()),
            u64::MAX
        );
    }

    #[test]
    fn only_liquid_mainnet_uses_mainnet_signing_keys() {
        let mainnet: ElementsNetwork = LiquidNetwork::Mainnet.into();
        let testnet: ElementsNetwork = LiquidNetwork::Testnet.into();
        assert!(mainnet.is_mainnet());
        assert!(!testnet.is_mainnet());
    }
}

#[derive(Clone, Debug, PartialEq)]
pub struct OutPoint {
    pub txid: String,
    pub vout: u32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TxOutputSpec {
    pub address: String,
    pub satoshi: u64,
    /// `None` means the policy asset (L-BTC).
    pub asset_id: Option<String>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TxOut {
    pub script_pubkey: String,
    pub outpoint: OutPoint,
    pub height: Option<u32>,
    pub unblinded: TxOutSecrets,
    pub is_spent: bool,
    pub address: Address,
}

#[derive(Clone, Debug, PartialEq)]
pub struct TxOutSecrets {
    pub value: u64,
    pub value_bf: String,
    pub asset: String,
    pub asset_bf: String,
}

/// Transaction object returned by getTransactions.
#[derive(Clone, Debug, PartialEq)]
pub struct Tx {
    pub timestamp: Option<u32>,
    pub kind: String,
    pub balances: Balances,
    pub txid: String,
    pub outputs: Vec<TxOut>,
    pub inputs: Vec<TxOut>,
    pub fee: u64,
    pub height: Option<u32>,
    pub unblinded_url: String,
    pub vsize: usize,
}

impl From<WalletTx> for Tx {
    fn from(wallet_tx: WalletTx) -> Self {
        let mut outputs: Vec<TxOut> = Vec::new();
        let mut inputs: Vec<TxOut> = Vec::new();

        for output in &wallet_tx.outputs {
            if let Some(output) = output {
                let script_pubkey = hex::encode(output.script_pubkey.as_bytes());
                outputs.push(TxOut {
                    script_pubkey,
                    height: output.height,
                    unblinded: output.unblinded.into(),
                    outpoint: OutPoint {
                        txid: output.outpoint.txid.to_string(),
                        vout: output.outpoint.vout,
                    },
                    address: Address::from(output.address.clone()),
                    is_spent: output.is_spent,
                })
            }
        }

        for input in &wallet_tx.inputs {
            if let Some(input) = input {
                let script_pubkey = input.script_pubkey.to_string();
                inputs.push(TxOut {
                    script_pubkey,
                    height: input.height,
                    unblinded: input.unblinded.into(),
                    outpoint: OutPoint {
                        txid: input.outpoint.txid.to_string(),
                        vout: input.outpoint.vout,
                    },
                    address: Address::from(input.address.clone()),
                    is_spent: input.is_spent,
                })
            }
        }
        // let now = SystemTime::now();
        // let since_the_epoch = now.duration_since(UNIX_EPOCH).expect("Time went backwards");
        Tx {
            kind: wallet_tx.type_.clone(),
            balances: Balances::from(AssetIdBTreeMapInt(wallet_tx.balance.as_ref().clone())),
            txid: wallet_tx.tx.txid().to_string().clone(),
            outputs: outputs,
            inputs: inputs,
            fee: wallet_tx.fee,
            timestamp: wallet_tx.timestamp,
            height: wallet_tx.height,
            unblinded_url: wallet_tx.unblinded_url("").clone(),
            vsize: wallet_tx.tx.discount_vsize(),
        }
    }
}

/// Decoded PSET amounts
#[derive(Clone, Debug, PartialEq)]
pub struct PsetAmounts {
    pub absolute_fees: u64,
    pub balances: Balances,
}
impl PsetAmounts {
    pub(super) fn from_balance(balance: &PsetBalance, policy_asset: &AssetId) -> Self {
        PsetAmounts {
            absolute_fees: balance.fees_in(policy_asset),
            balances: Balances::from(AssetIdBTreeMapInt(balance.balances().as_ref().clone())),
        }
    }
}

#[frb(unignore)]
#[derive(Clone, Debug, PartialEq)]
pub struct SizeAndFees {
    pub discounted_vsize: usize,
    pub discounted_weight: usize,
    pub absolute_fees: WalletBalances,
}
impl TryFrom<String> for SizeAndFees {
    type Error = LwkError;
    fn try_from(pset_string: String) -> Result<Self, Self::Error> {
        let pset = PartiallySignedTransaction::from_str(&pset_string)
            .map_err(|e| LwkError { msg: e.to_string() })?;
        let tx = pset
            .extract_tx()
            .map_err(|e| LwkError { msg: e.to_string() })?;
        let all_fees: AssetIdHashMapUInt = tx.all_fees().into();

        Ok(SizeAndFees {
            discounted_vsize: tx.discount_vsize(),
            discounted_weight: tx.discount_weight(),
            absolute_fees: all_fees.into(),
        })
    }
}

// #[test]
// fn test_address_from_script() {
//     // The script provided: 0014ac45b647d82582d4ed416e5b84fd418789025dc5
//     let script = "0014ac45b647d82582d4ed416e5b84fd418789025dc5".to_string();
//     // Generate blinding key from SLIP77 seed
//     let slip77_string = "".to_string();

//     // Get the script for blinding

//     // Call the address_from_script method
//     let address_result = Address::address_from_script(
//         LiquidNetwork::Mainnet,
//         script,
//         slip77_string,
//     ).unwrap();
//     println!("{:?}", address_result);
//     // Expected values - verify these are correct for your implementation
//     // let expected_standard = "ex1q9g4gvcdszt4krclr7tcw50vg5hyuuk2kjfyyxu";
//     // let expected_confidential = "lq1qqg4gvcdszt4krclr7tcw50vg5hyuuk2krzm3el3kvfpe60vf025x2dfqlxzse3rppkan5kdz8qc9f7qwjcc0shw90x34wlse5s3ydw8pyq4eqehu";

//     // assert_eq!(address_result.standard, expected_standard);
//     // assert_eq!(address_result.confidential, expected_confidential);
//     // assert_eq!(address_result.index, 0);
// }
