use std::str::FromStr;

use boltz_client::{
    network::{BitcoinChain, Chain as AllChains, LiquidChain, Network as BoltzNetwork},
    swaps::boltz::{Side as BoltzSide, SwapTxKind as BoltzSwapTxKind, SwapType as BoltzSwapType},
    Address, BtcSwapScript, ElementsAddress, Hash, LBtcSwapScript, PublicKey, ZKKeyPair,
};
use serde::{Deserialize, Serialize};

use super::error::BoltzError;

pub use super::secrets::KeyPair;

/// Used for chain-swaps only. The side is based on which transaction is being made by the user.
/// When a swap is created the user must first make a Lockup.
/// Once the swap is completed, the user must make a Claim.
#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Side {
    Lockup,
    Claim,
}

impl Into<BoltzSide> for Side {
    fn into(self) -> BoltzSide {
        match self {
            Side::Lockup => BoltzSide::Lockup,
            Side::Claim => BoltzSide::Claim,
        }
    }
}
impl From<BoltzSide> for Side {
    fn from(boltz_side: BoltzSide) -> Self {
        match boltz_side {
            BoltzSide::Lockup => Side::Lockup,
            BoltzSide::Claim => Side::Claim,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Debug)]
pub enum SwapTxKind {
    Claim,
    Refund,
}

impl Into<BoltzSwapTxKind> for SwapTxKind {
    fn into(self) -> BoltzSwapTxKind {
        match self {
            SwapTxKind::Refund => BoltzSwapTxKind::Refund,
            SwapTxKind::Claim => BoltzSwapTxKind::Claim,
        }
    }
}
impl From<BoltzSwapTxKind> for SwapTxKind {
    fn from(kind: BoltzSwapTxKind) -> Self {
        match kind {
            BoltzSwapTxKind::Refund => SwapTxKind::Refund,
            BoltzSwapTxKind::Claim => SwapTxKind::Claim,
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SwapType {
    Submarine,
    Reverse,
    Chain,
}

impl Into<BoltzSwapType> for SwapType {
    fn into(self) -> BoltzSwapType {
        match self {
            SwapType::Submarine => BoltzSwapType::Submarine,
            SwapType::Reverse => BoltzSwapType::ReverseSubmarine,
            SwapType::Chain => BoltzSwapType::Chain,
        }
    }
}
impl From<BoltzSwapType> for SwapType {
    fn from(boltz_swap_type: BoltzSwapType) -> Self {
        match boltz_swap_type {
            BoltzSwapType::Submarine => SwapType::Submarine,
            BoltzSwapType::ReverseSubmarine => SwapType::Reverse,
            BoltzSwapType::Chain => SwapType::Chain,
        }
    }
}

#[derive(Clone, Copy, Eq, Serialize, Deserialize, PartialEq)]
pub enum Chain {
    Bitcoin,
    BitcoinTestnet,
    Liquid,
    LiquidTestnet,
    BitcoinRegtest,
    LiquidRegtest,
}

impl Chain {
    pub fn is_testnet(&self) -> bool {
        matches!(self, Chain::BitcoinTestnet | Chain::LiquidTestnet)
    }
}

impl Into<AllChains> for Chain {
    fn into(self) -> AllChains {
        match self {
            Chain::Bitcoin => AllChains::Bitcoin(BitcoinChain::Bitcoin),
            Chain::BitcoinTestnet => AllChains::Bitcoin(BitcoinChain::BitcoinTestnet),
            Chain::BitcoinRegtest => AllChains::Bitcoin(BitcoinChain::BitcoinRegtest),
            Chain::Liquid => AllChains::Liquid(LiquidChain::Liquid),
            Chain::LiquidTestnet => AllChains::Liquid(LiquidChain::LiquidTestnet),
            Chain::LiquidRegtest => AllChains::Liquid(LiquidChain::LiquidRegtest),
        }
    }
}
// implement from AllChains
impl From<AllChains> for Chain {
    fn from(chain: AllChains) -> Self {
        match chain {
            AllChains::Bitcoin(BitcoinChain::Bitcoin) => Chain::Bitcoin,
            AllChains::Bitcoin(BitcoinChain::BitcoinTestnet) => Chain::BitcoinTestnet,
            AllChains::Bitcoin(BitcoinChain::BitcoinRegtest) => Chain::BitcoinRegtest,
            AllChains::Liquid(LiquidChain::Liquid) => Chain::Liquid,
            AllChains::Liquid(LiquidChain::LiquidTestnet) => Chain::LiquidTestnet,
            AllChains::Liquid(LiquidChain::LiquidRegtest) => Chain::LiquidRegtest,
        }
    }
}

impl Into<BitcoinChain> for Chain {
    fn into(self) -> BitcoinChain {
        match self {
            Chain::Bitcoin => BitcoinChain::Bitcoin,
            Chain::BitcoinTestnet => BitcoinChain::BitcoinTestnet,
            Chain::BitcoinRegtest => BitcoinChain::BitcoinRegtest,
            _ => panic!("Invalid chain"),
        }
    }
}
impl Into<LiquidChain> for Chain {
    fn into(self) -> LiquidChain {
        match self {
            Chain::Liquid => LiquidChain::Liquid,
            Chain::LiquidTestnet => LiquidChain::LiquidTestnet,
            Chain::LiquidRegtest => LiquidChain::LiquidRegtest,
            _ => panic!("Invalid chain"),
        }
    }
}

#[derive(Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum ChainSwapDirection {
    BtcToLbtc,
    LbtcToBtc,
}

/// Wrapper for Network from boltz-rust
#[derive(Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Network {
    Mainnet,
    Testnet,
    Regtest,
}

impl Network {
    pub(crate) fn bitcoin(self) -> Chain {
        match self {
            Self::Mainnet => Chain::Bitcoin,
            Self::Testnet => Chain::BitcoinTestnet,
            Self::Regtest => Chain::BitcoinRegtest,
        }
    }

    pub(crate) fn liquid(self) -> Chain {
        match self {
            Self::Mainnet => Chain::Liquid,
            Self::Testnet => Chain::LiquidTestnet,
            Self::Regtest => Chain::LiquidRegtest,
        }
    }
}

impl Into<BoltzNetwork> for Network {
    fn into(self) -> BoltzNetwork {
        match self {
            Network::Mainnet => BoltzNetwork::Mainnet,
            Network::Testnet => BoltzNetwork::Testnet,
            Network::Regtest => BoltzNetwork::Regtest,
        }
    }
}

impl From<BoltzNetwork> for Network {
    fn from(network: BoltzNetwork) -> Self {
        match network {
            BoltzNetwork::Mainnet => Network::Mainnet,
            BoltzNetwork::Testnet => Network::Testnet,
            BoltzNetwork::Regtest => Network::Regtest,
        }
    }
}

impl From<Chain> for Network {
    fn from(chain: Chain) -> Self {
        match chain {
            Chain::Bitcoin | Chain::Liquid => Network::Mainnet,
            Chain::BitcoinTestnet | Chain::LiquidTestnet => Network::Testnet,
            Chain::BitcoinRegtest | Chain::LiquidRegtest => Network::Regtest,
        }
    }
}

pub use super::secrets::PreImage;

/// Helper to store a BtcSwapScript and convert to a BtcSwapScript
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct BtcSwapScriptStr {
    pub swap_type: SwapType,
    pub funding_addrs: Option<String>,
    pub hashlock: String,
    pub receiver_pubkey: String,
    pub locktime: u32,
    pub sender_pubkey: String,
    pub side: Option<Side>,
}

impl BtcSwapScriptStr {
    pub fn new(
        swap_type: SwapType,
        funding_addrs: Option<String>,
        hashlock: String,
        receiver_pubkey: String,
        locktime: u32,
        sender_pubkey: String,
        side: Option<Side>,
    ) -> Self {
        BtcSwapScriptStr {
            swap_type,
            funding_addrs,
            hashlock,
            receiver_pubkey,
            locktime,
            sender_pubkey,
            side,
        }
    }
}

impl TryInto<BtcSwapScript> for BtcSwapScriptStr {
    type Error = BoltzError; // Use a more specific error type in a real application

    fn try_into(self) -> Result<BtcSwapScript, Self::Error> {
        let address: Option<Address> = if self.funding_addrs.is_some() {
            let address = match Address::from_str(&self.funding_addrs.unwrap()) {
                Ok(r) => r.assume_checked(),
                Err(_) => {
                    return Err(BoltzError::new(
                        "Input".to_string(),
                        "Could not parse elements address".to_string(),
                    ))
                }
            };
            Some(address)
        } else {
            None
        };
        let hashlock = match Hash::from_str(&self.hashlock) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not parse hash value".to_string(),
                ))
            }
        };
        let receiver_pubkey = match PublicKey::from_str(&self.receiver_pubkey) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not receiver pubkey value".to_string(),
                ))
            }
        };
        let sender_pubkey = match PublicKey::from_str(&self.sender_pubkey) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not sender pubkey value".to_string(),
                ))
            }
        };
        let locktime = match boltz_client::LockTime::from_height(self.locktime) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not locktime value".to_string(),
                ))
            }
        };
        Ok(BtcSwapScript {
            swap_type: self.swap_type.clone().into(),
            funding_addrs: address,
            hashlock: hashlock,
            receiver_pubkey: receiver_pubkey,
            locktime: locktime,
            sender_pubkey: sender_pubkey,
            side: if self.side.is_some() {
                Some(self.side.unwrap().into())
            } else {
                None
            },
        })
    }
}

impl From<BtcSwapScript> for BtcSwapScriptStr {
    fn from(swap: BtcSwapScript) -> Self {
        BtcSwapScriptStr {
            swap_type: swap.swap_type.into(),
            funding_addrs: swap.funding_addrs.map(|addr| addr.to_string()),
            hashlock: swap.hashlock.to_string(),
            receiver_pubkey: swap.receiver_pubkey.to_string(),
            locktime: swap.locktime.to_consensus_u32(),
            sender_pubkey: swap.sender_pubkey.to_string(),
            side: if swap.side.is_some() {
                Some(swap.side.unwrap().into())
            } else {
                None
            },
        }
    }
}
/// Helper to store a LBtcSwapScript and convert to a LBtcSwapScript
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LBtcSwapScriptStr {
    pub swap_type: SwapType,
    pub funding_addrs: Option<String>,
    pub hashlock: String,
    pub receiver_pubkey: String,
    pub locktime: u32,
    pub sender_pubkey: String,
    pub blinding_key: String,
    pub side: Option<Side>,
}
impl LBtcSwapScriptStr {
    pub fn new(
        swap_type: SwapType,
        funding_addrs: Option<String>,
        hashlock: String,
        receiver_pubkey: String,
        locktime: u32,
        sender_pubkey: String,
        blinding_key: String,
        side: Option<Side>,
    ) -> Self {
        LBtcSwapScriptStr {
            swap_type,
            funding_addrs,
            hashlock,
            receiver_pubkey,
            locktime,
            sender_pubkey,
            blinding_key,
            side,
        }
    }
}
impl TryInto<LBtcSwapScript> for LBtcSwapScriptStr {
    type Error = BoltzError; // Use a more specific error type in a real application

    fn try_into(self) -> Result<LBtcSwapScript, Self::Error> {
        let address: Option<ElementsAddress> = if self.funding_addrs.is_some() {
            let address = match ElementsAddress::from_str(&self.funding_addrs.unwrap()) {
                Ok(r) => r,
                Err(_) => {
                    return Err(BoltzError::new(
                        "Input".to_string(),
                        "Could not parse elements address".to_string(),
                    ))
                }
            };
            Some(address)
        } else {
            None
        };
        let hashlock = match Hash::from_str(&self.hashlock) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not parse hashlock value".to_string(),
                ))
            }
        };
        let receiver_pubkey = match PublicKey::from_str(&self.receiver_pubkey) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not parse receiver pubkey value".to_string(),
                ))
            }
        };
        let sender_pubkey = match PublicKey::from_str(&self.sender_pubkey) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not parse sender pubkey value".to_string(),
                ))
            }
        };
        let locktime = match boltz_client::ElementsLockTime::from_height(self.locktime) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not parse locktime value".to_string(),
                ))
            }
        };
        let blinding_key = match ZKKeyPair::from_str(&self.blinding_key) {
            Ok(r) => r,
            Err(_) => {
                return Err(BoltzError::new(
                    "Input".to_string(),
                    "Could not parse blinding key value".to_string(),
                ))
            }
        };
        Ok(LBtcSwapScript {
            swap_type: self.swap_type.clone().into(),
            funding_addrs: address,
            hashlock: hashlock,
            receiver_pubkey: receiver_pubkey,
            locktime: locktime,
            sender_pubkey: sender_pubkey,
            blinding_key: blinding_key,
            side: if self.side.is_some() {
                Some(self.side.unwrap().into())
            } else {
                None
            },
        })
    }
}

impl From<LBtcSwapScript> for LBtcSwapScriptStr {
    fn from(swap: LBtcSwapScript) -> Self {
        LBtcSwapScriptStr {
            swap_type: swap.swap_type.into(),
            funding_addrs: swap.funding_addrs.map(|addr| addr.to_string()),
            hashlock: swap.hashlock.to_string(),
            receiver_pubkey: swap.receiver_pubkey.inner.to_string(),
            locktime: swap.locktime.to_consensus_u32(),
            sender_pubkey: swap.sender_pubkey.inner.to_string(),
            blinding_key: swap.blinding_key.display_secret().to_string(),
            side: if swap.side.is_some() {
                Some(swap.side.unwrap().into())
            } else {
                None
            },
        }
    }
}

#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ElectrumSettings {
    pub url: String,
    pub validate_domain: bool,
    pub tls: bool,
    pub timeout: u8,
}

/// Result of checking if a transaction output has been spent
#[derive(Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct OutspendStatus {
    pub kind: SwapTxKind,
    pub txid: Option<String>,
    pub timestamp: Option<u64>,
}

/// Outspend report for one output of a lockup transaction.
///
/// A lockup tx is not guaranteed to carry the swap covenant at vout 0 —
/// Boltz's wallet (and our own on the refund side) can order change first.
/// Callers therefore get every vout and decide which spend, if any, is
/// theirs; a spender txid here proves only that the output was spent, never
/// that the swap participant claiming it was paid.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct VoutOutspend {
    pub vout: u32,
    /// Output amount in sats. None for confidential (Liquid) outputs, whose
    /// value is blinded in the explorer response.
    pub value_sat: Option<u64>,
    /// Txid of the spending transaction, when the output is spent.
    pub spender_txid: Option<String>,
    /// Block time of the spending transaction, when confirmed.
    pub timestamp: Option<u64>,
}
