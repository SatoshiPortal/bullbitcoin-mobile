use boltz::api::types::{Chain, Network};
use boltz_client::network::{BitcoinChain, Chain as CoreChain, LiquidChain};

#[test]
fn regtest_core_chains_round_trip_without_panicking() {
    for core in [
        CoreChain::Bitcoin(BitcoinChain::Bitcoin),
        CoreChain::Bitcoin(BitcoinChain::BitcoinTestnet),
        CoreChain::Bitcoin(BitcoinChain::BitcoinRegtest),
        CoreChain::Liquid(LiquidChain::Liquid),
        CoreChain::Liquid(LiquidChain::LiquidTestnet),
        CoreChain::Liquid(LiquidChain::LiquidRegtest),
    ] {
        let chain = Chain::from(core.clone());
        match chain {
            Chain::BitcoinRegtest | Chain::LiquidRegtest => {
                assert!(Network::from(chain) == Network::Regtest);
                assert!(!chain.is_testnet());
            }
            _ => {}
        }
        let restored: CoreChain = chain.into();
        assert!(restored == core);
    }
}

use boltz::api::secrets::KeyPair;
use boltz::api::types::{BtcSwapScriptStr, LBtcSwapScriptStr, PreImage};
use boltz::api::{
    btc_ln::BtcLnSwap, chain_swap::ChainSwap, lbtc_ln::LbtcLnSwap, secrets::SwapMasterKey,
    types::ChainSwapDirection,
};
use serde::Deserialize;
#[derive(Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
struct Ce7ChainSwap {
    pub id: String,
    pub is_testnet: bool,
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

use serde_json::Value;

const MAINNET: &str = include_str!("fixtures/chain_swap_mainnet.json");
const TESTNET: &str = include_str!("fixtures/chain_swap_testnet.json");

#[derive(Deserialize)]
struct LegacyNetwork {
    is_testnet: bool,
}

#[tokio::test]
async fn production_chain_json_read_and_rewrite_matches_ce7_golden() {
    for (blob, network) in [(MAINNET, Network::Mainnet), (TESTNET, Network::Testnet)] {
        let legacy_blob: Ce7ChainSwap = serde_json::from_str(blob).unwrap();
        assert!(serde_json::to_string(&legacy_blob).unwrap().as_bytes() == blob.as_bytes());
        let swap = ChainSwap::from_json(blob).await.unwrap();
        assert!(swap.network == network);
        let encoded = swap.to_json().await.unwrap();
        assert!(encoded.as_bytes() == blob.as_bytes());
        let legacy: LegacyNetwork = serde_json::from_str(&encoded).unwrap();
        assert!(legacy.is_testnet == (network == Network::Testnet));
        assert!(
            serde_json::from_str::<Value>(&encoded).unwrap()
                == serde_json::from_str::<Value>(blob).unwrap()
        );
    }
}

fn regtest_blob() -> Value {
    let mut blob: Value = serde_json::from_str(MAINNET).unwrap();
    blob.as_object_mut().unwrap().remove("is_testnet");
    blob["network"] = "Regtest".into();
    blob["boltz_url"] = "http://boltz.example:18200/custom/v2".into();
    blob["btc_electrum_url"] = "bitcoin.example:18201".into();
    blob["lbtc_electrum_url"] = "liquid.example:18202".into();
    blob
}

#[tokio::test]
async fn regtest_json_round_trips_and_legacy_reader_refuses_it() {
    let blob = regtest_blob().to_string();
    let swap = ChainSwap::from_json(&blob).await.unwrap();
    assert!(swap.network == Network::Regtest);
    let encoded = swap.to_json().await.unwrap();
    assert!(serde_json::from_str::<LegacyNetwork>(&encoded).is_err());
    assert!(ChainSwap::from_json(&encoded).await.unwrap().network == Network::Regtest);
}

#[tokio::test]
async fn ambiguous_or_missing_network_json_is_rejected() {
    let mut blob = regtest_blob();
    blob["is_testnet"] = false.into();
    assert!(ChainSwap::from_json(&blob.to_string()).await.is_err());
    blob.as_object_mut().unwrap().remove("is_testnet");
    blob["network"] = "Testnet".into();
    assert!(ChainSwap::from_json(&blob.to_string()).await.is_err());
    blob.as_object_mut().unwrap().remove("network");
    assert!(ChainSwap::from_json(&blob.to_string()).await.is_err());
    for network in ["null", "false", "\"Unknown\""] {
        let mut blob = regtest_blob();
        blob["network"] = serde_json::from_str(network).unwrap();
        assert!(ChainSwap::from_json(&blob.to_string()).await.is_err());
    }
}

#[tokio::test]
async fn duplicate_network_fields_are_rejected_in_raw_json() {
    let duplicate_legacy = MAINNET.replace(
        "\"is_testnet\":false",
        "\"is_testnet\":false,\"is_testnet\":false",
    );
    assert!(ChainSwap::from_json(&duplicate_legacy).await.is_err());
    let regtest = regtest_blob().to_string();
    let duplicate_concrete = regtest.replace(
        "\"network\":\"Regtest\"",
        "\"network\":\"Regtest\",\"network\":\"Regtest\"",
    );
    assert!(ChainSwap::from_json(&duplicate_concrete).await.is_err());
    let legacy_and_null = MAINNET.replacen('{', "{\"network\":null,", 1);
    assert!(ChainSwap::from_json(&legacy_and_null).await.is_err());
}

fn invalid_key(network: Network) -> SwapMasterKey {
    SwapMasterKey {
        xprv: String::new(),
        xpub: String::new(),
        mnemonic: String::new(),
        fingerprint: String::new(),
        network,
    }
}

#[tokio::test]
async fn all_networks_reject_mismatched_keys_before_derivation_or_io() {
    for (network, btc, liquid) in [
        (Network::Mainnet, Chain::Bitcoin, Chain::Liquid),
        (
            Network::Testnet,
            Chain::BitcoinTestnet,
            Chain::LiquidTestnet,
        ),
        (
            Network::Regtest,
            Chain::BitcoinRegtest,
            Chain::LiquidRegtest,
        ),
    ] {
        for key_network in [Network::Mainnet, Network::Testnet, Network::Regtest] {
            if network == key_network {
                continue;
            }
            let key = invalid_key(key_network);
            let url = "http://127.0.0.1:1".to_string();
            let electrum = "127.0.0.1:1".to_string();
            let btc_sub = BtcLnSwap::new_submarine(
                key.clone(),
                0,
                String::new(),
                btc,
                electrum.clone(),
                url.clone(),
                None,
            )
            .await;
            let liquid_sub = LbtcLnSwap::new_submarine(
                key.clone(),
                0,
                String::new(),
                liquid,
                electrum.clone(),
                url.clone(),
                None,
            )
            .await;
            let btc_rev = BtcLnSwap::new_reverse(
                key.clone(),
                0,
                1000,
                None,
                btc,
                electrum.clone(),
                url.clone(),
                None,
                None,
            )
            .await;
            let liquid_rev = LbtcLnSwap::new_reverse(
                key.clone(),
                0,
                1000,
                None,
                liquid,
                electrum.clone(),
                url.clone(),
                None,
                None,
            )
            .await;
            assert!(btc_sub.err().unwrap().kind == "Network");
            assert!(liquid_sub.err().unwrap().kind == "Network");
            assert!(btc_rev.err().unwrap().kind == "Network");
            assert!(liquid_rev.err().unwrap().kind == "Network");
            for direction in [ChainSwapDirection::BtcToLbtc, ChainSwapDirection::LbtcToBtc] {
                let swap = ChainSwap::new_swap(
                    direction,
                    key.clone(),
                    0,
                    1000,
                    network,
                    electrum.clone(),
                    electrum.clone(),
                    url.clone(),
                    None,
                )
                .await;
                assert!(swap.err().unwrap().kind == "Network");
            }
        }
    }
}

#[test]
fn manual_constructor_preserves_custom_regtest_urls_and_production_policy() {
    let base: Ce7ChainSwap = serde_json::from_str(MAINNET).unwrap();
    for network in [Network::Mainnet, Network::Testnet, Network::Regtest] {
        let swap = ChainSwap::new(
            base.id.clone(),
            network,
            base.direction,
            base.refund_keys.clone(),
            base.refund_index,
            base.claim_keys.clone(),
            base.claim_index,
            base.preimage.clone(),
            base.btc_script_str.clone(),
            base.lbtc_script_str.clone(),
            base.script_address.clone(),
            base.out_amount,
            "tcp://bitcoin.example:18201".into(),
            "ssl://liquid.example:18202".into(),
            "http://boltz.example:18200/custom/v2".into(),
            None,
            base.blinding_key.clone(),
        );
        assert!(swap.network == network);
        assert_eq!(swap.btc_electrum_url, "bitcoin.example:18201");
        assert_eq!(swap.lbtc_electrum_url, "liquid.example:18202");
        assert_eq!(
            swap.boltz_url,
            if network == Network::Mainnet {
                "https://boltz.example:18200/custom/v2"
            } else {
                "http://boltz.example:18200/custom/v2"
            }
        );
    }
}
