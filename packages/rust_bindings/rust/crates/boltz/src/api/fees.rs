use crate::util::{ensure_http_prefix, HTTP_TIMEOUT};
use boltz_client::{
    boltz::{
        ChainFees, GetChainPairsResponse, GetReversePairsResponse, GetSubmarinePairsResponse,
        PairMinerFees, ReverseFees, SubmarineFees,
    },
    error::Error as LibError,
    fees::Fee,
    swaps::boltz::BoltzApiClientV2,
};
use serde::{Deserialize, Serialize};

use super::error::BoltzError;

#[derive(Clone, Copy, PartialEq, Serialize, Deserialize)]
pub enum TxFee {
    Absolute(u64),
    Relative(f64),
}

impl Into<Fee> for TxFee {
    fn into(self) -> Fee {
        match self {
            TxFee::Absolute(x) => Fee::Absolute(x),
            TxFee::Relative(x) => Fee::Relative(x),
        }
    }
}

/// A Class that helps fetch both Fees and Limits for the various swap types
pub struct Fees {
    pub boltz_url: String,
}

impl Fees {
    /// Constructor
    pub fn new(boltz_url: String) -> Fees {
        let url = ensure_http_prefix(&boltz_url);
        Fees { boltz_url: url }
    }

    /// Method to get the fees & limits for a submarine swap
    pub async fn submarine(&self) -> Result<SubmarineFeesAndLimits, BoltzError> {
        let boltz_client = BoltzApiClientV2::new(self.boltz_url.clone(), Some(HTTP_TIMEOUT));
        let sub_fees: SubmarineFeesAndLimits =
            boltz_client.get_submarine_pairs().await?.try_into()?;
        Ok(sub_fees)
    }
    /// Method to get the fees & limits for a reverse swap
    pub async fn reverse(&self) -> Result<ReverseFeesAndLimits, BoltzError> {
        let boltz_client = BoltzApiClientV2::new(self.boltz_url.clone(), Some(HTTP_TIMEOUT));
        let reverse_fees: ReverseFeesAndLimits =
            boltz_client.get_reverse_pairs().await?.try_into()?;
        Ok(reverse_fees)
    }
    /// Method to get the fees & limits for a chain swap
    pub async fn chain(&self) -> Result<ChainFeesAndLimits, BoltzError> {
        let boltz_client = BoltzApiClientV2::new(self.boltz_url.clone(), Some(HTTP_TIMEOUT));
        let chain_fees: ChainFeesAndLimits = boltz_client.get_chain_pairs().await?.try_into()?;
        Ok(chain_fees)
    }
}

/// Boltz limits for swaps.
/// Internally used and returned by the Fees class methods.
#[derive(Debug, Clone)]
pub struct SwapLimits {
    pub minimal: u64,
    pub maximal: u64,
    /// Submarine and chain pairs. Maximum amount allowed for zero-conf.
    pub maximal_zero_conf: Option<u64>,
    /// Submarine pairs only; use for batched swap minimum validation.
    pub minimal_batched: Option<u64>,
}

impl From<boltz_client::swaps::boltz::PairLimits> for SwapLimits {
    fn from(limits: boltz_client::swaps::boltz::PairLimits) -> Self {
        SwapLimits {
            minimal: limits.minimal as u64,
            maximal: limits.maximal as u64,
            maximal_zero_conf: Some(limits.maximal_zero_conf),
            minimal_batched: None,
        }
    }
}
impl From<boltz_client::swaps::boltz::ReverseLimits> for SwapLimits {
    fn from(limits: boltz_client::swaps::boltz::ReverseLimits) -> Self {
        SwapLimits {
            minimal: limits.minimal as u64,
            maximal: limits.maximal as u64,
            maximal_zero_conf: None,
            minimal_batched: None,
        }
    }
}
impl From<boltz_client::swaps::boltz::SubmarinePairLimits> for SwapLimits {
    fn from(limits: boltz_client::swaps::boltz::SubmarinePairLimits) -> Self {
        SwapLimits {
            minimal: limits.minimal,
            maximal: limits.maximal,
            maximal_zero_conf: Some(limits.maximal_zero_conf),
            minimal_batched: limits.minimal_batched,
        }
    }
}

/// Submarine swap fee breakdown.
#[derive(Debug, Clone)]
pub struct SubSwapFees {
    /// Boltz fees as a percentage
    pub percentage: f64,
    /// Fees going to Bitcoin miners/Liquid block validators
    pub miner_fees: u64,
}

impl Into<SubSwapFees> for SubmarineFees {
    fn into(self) -> SubSwapFees {
        SubSwapFees {
            percentage: self.percentage,
            miner_fees: self.miner_fees as u64,
        }
    }
}

/// Complete fees and limits class for Submarine swaps
#[derive(Debug, Clone)]
pub struct SubmarineFeesAndLimits {
    pub btc_limits: SwapLimits,
    pub lbtc_limits: SwapLimits,
    pub btc_fees: SubSwapFees,
    pub lbtc_fees: SubSwapFees,
}
impl TryInto<SubmarineFeesAndLimits> for GetSubmarinePairsResponse {
    type Error = BoltzError; // Use a more specific error type in a real application

    fn try_into(self) -> Result<SubmarineFeesAndLimits, Self::Error> {
        let btc_pair = match self.get_btc_to_btc_pair() {
            Some(result) => result,
            None => return Err(LibError::Protocol("Could Not find BTC Pair".to_string()).into()),
        };
        let btc_limits: SwapLimits = btc_pair.limits.into();
        let btc_fees = btc_pair.fees.into();
        let lbtc_pair = match self.get_lbtc_to_btc_pair() {
            Some(result) => result,
            None => return Err(LibError::Protocol("Could Not find L-BTC Pair".to_string()).into()),
        };
        let lbtc_limits = lbtc_pair.limits.into();
        let lbtc_fees = lbtc_pair.fees.into();
        Ok(SubmarineFeesAndLimits {
            btc_limits,
            lbtc_limits,
            btc_fees,
            lbtc_fees,
        })
    }
}

/// Breakdown of Miner Fees
#[derive(Debug, Clone)]
pub struct MinerFees {
    pub lockup: u64,
    pub claim: u64,
}
impl Into<MinerFees> for PairMinerFees {
    fn into(self) -> MinerFees {
        MinerFees {
            lockup: self.lockup,
            claim: self.claim,
        }
    }
}
/// Reverse swap fee breakdown.
#[derive(Debug, Clone)]
pub struct RevSwapFees {
    pub percentage: f64,
    pub miner_fees: MinerFees,
}

impl Into<RevSwapFees> for ReverseFees {
    fn into(self) -> RevSwapFees {
        RevSwapFees {
            percentage: self.percentage,
            miner_fees: self.miner_fees.into(),
        }
    }
}
/// Complete fees and limits class for Reverse swaps

#[derive(Debug, Clone)]
pub struct ReverseFeesAndLimits {
    pub btc_limits: SwapLimits,
    pub lbtc_limits: SwapLimits,
    pub btc_fees: RevSwapFees,
    pub lbtc_fees: RevSwapFees,
}

impl TryInto<ReverseFeesAndLimits> for GetReversePairsResponse {
    type Error = BoltzError; // Use a more specific error type in a real application

    fn try_into(self) -> Result<ReverseFeesAndLimits, Self::Error> {
        let btc_pair = match self.get_btc_to_btc_pair() {
            Some(result) => result,
            None => return Err(LibError::Protocol("Could Not find BTC Pair".to_string()).into()),
        };
        let btc_limits = btc_pair.limits.into();
        let btc_reverse = btc_pair.fees.into();
        let lbtc_pair = match self.get_btc_to_lbtc_pair() {
            Some(result) => result,
            None => return Err(LibError::Protocol("Could Not find L-BTC Pair".to_string()).into()),
        };
        let lbtc_limits = lbtc_pair.limits.into();
        let lbtc_reverse = lbtc_pair.fees.into();
        Ok(ReverseFeesAndLimits {
            btc_limits,
            lbtc_limits,
            btc_fees: btc_reverse,
            lbtc_fees: lbtc_reverse,
        })
    }
}

/// Chain swap fee breakdown.
#[derive(Debug, Clone)]
pub struct ChainSwapFees {
    pub percentage: f64,
    pub user_lockup: u64,
    pub user_claim: u64,
    pub server: u64,
}

impl From<ChainFees> for ChainSwapFees {
    fn from(cf: ChainFees) -> Self {
        Self {
            percentage: cf.percentage,
            user_lockup: cf.lockup(),
            user_claim: cf.claim_estimate(),
            server: cf.server(),
        }
    }
}
/// Complete fees and limits class for Chain swaps
#[derive(Debug, Clone)]
pub struct ChainFeesAndLimits {
    pub lbtc_to_btc_limits: SwapLimits,
    pub btc_to_lbtc_limits: SwapLimits,
    pub lbtc_to_btc_fees: ChainSwapFees,
    pub btc_to_lbtc_fees: ChainSwapFees,
}
impl TryInto<ChainFeesAndLimits> for GetChainPairsResponse {
    type Error = BoltzError; // Use a more specific error type in a real application

    fn try_into(self) -> Result<ChainFeesAndLimits, Self::Error> {
        let lbtc_to_btc_pair = match self.get_lbtc_to_btc_pair() {
            Some(result) => result,
            None => return Err(LibError::Protocol("Could Not find BTC Pair".to_string()).into()),
        };
        let lbtc_to_btc_limits = lbtc_to_btc_pair.limits.into();
        let lbtc_to_btc_fees = lbtc_to_btc_pair.fees.into();
        let btc_to_lbtc_pair = match self.get_btc_to_lbtc_pair() {
            Some(result) => result,
            None => return Err(LibError::Protocol("Could Not find BTC Pair".to_string()).into()),
        };
        let btc_to_lbtc_limits = btc_to_lbtc_pair.limits.into();
        let btc_to_lbtc_fees = btc_to_lbtc_pair.fees.into();
        Ok(ChainFeesAndLimits {
            lbtc_to_btc_limits,
            btc_to_lbtc_limits,
            lbtc_to_btc_fees,
            btc_to_lbtc_fees,
        })
    }
}

// Cross test values by calling the API endpoint
// GET https://api.boltz.exchange/v2/swap/submarine
// #[cfg(test)]
// mod tests {
//     use super::*;

//     #[test]
//     fn test_new_fees() {
//         let url = "https://api.boltz.exchange/v2";
//         let fees = Fees::new(url.to_string());
//         assert_eq!(fees.boltz_url, url);

//         let url1 = "api.boltz.exchange";
//         let fees1 = Fees::new(url1.to_string());
//         assert_eq!(fees1.boltz_url, "https://".to_owned() + url1);
//     }

//     #[test]
//     fn test_submarine_fees() {
//         let url = "https://api.boltz.exchange/v2";
//         let fees = Fees::new(url.to_string());

//         let result = fees.submarine();
//         if let Ok(sub_fees) = result {
//             println!("BTC");
//             println!("percentage: {:?}", sub_fees.btc_fees.percentage);
//             println!("miner fees: {:?}", sub_fees.btc_fees.miner_fees);
//             println!("L-BTC");
//             println!("percentage: {:?}", sub_fees.lbtc_fees.percentage);
//             println!("miner fees: {:?}", sub_fees.lbtc_fees.miner_fees);
//         }
//     }

//     #[test]
//     fn test_reverse_fees() {
//         let url = "https://api.boltz.exchange/v2";
//         let fees = Fees::new(url.to_string());

//         let result = fees.reverse();
//         if let Ok(reverse_fees) = result {
//             println!("BTC");
//             println!("percentage: {:?}", reverse_fees.btc_fees.percentage);
//             println!("miner fees: {:?}", reverse_fees.btc_fees.miner_fees);
//             println!("L-BTC");
//             println!("percentage: {:?}", reverse_fees.lbtc_fees.percentage);
//             println!("miner fees: {:?}", reverse_fees.lbtc_fees.miner_fees);
//         }
//     }

//     /*
//     #[test]
//     fn test_chain_fees() {
//         let url = "https://api.boltz.exchange/v2";
//         let fees = Fees::new(url.to_string());

//         let result = fees.chain();
//         if let Ok(chain_fees) = result {
//             println!("BTC");
//             println!("{:?}", chain_fees);
//         }
//     }
//     */
// }
