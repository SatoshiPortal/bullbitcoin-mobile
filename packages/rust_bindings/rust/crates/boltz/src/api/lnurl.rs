use boltz_client::util::lnurl as boltz_lnurl;
use lnurl::{lightning_address::LightningAddress, lnurl::LnUrl};
use std::{str::FromStr, time::Duration};

use super::error::BoltzError;

// Leave room for the LNURL-pay metadata image allowed by LUD-06.
const MAX_PAY_RESPONSE_BYTES: usize = 256 * 1024;

#[derive(Clone, serde::Serialize, serde::Deserialize, Debug, PartialEq, Eq)]
pub struct LnurlPayBounds {
    pub min_sendable_msat: u64,
    pub max_sendable_msat: u64,
}

fn pay_error(kind: &str) -> BoltzError {
    BoltzError::new(
        kind.to_owned(),
        "Unable to fetch LNURL-pay limits".to_owned(),
    )
}

fn pay_endpoint(value: &str) -> Result<reqwest::Url, BoltzError> {
    // Match the pinned Boltz invoice client's recipient normalization. The
    // decoded LNURL's URL retains its original path and query casing.
    let value = value.to_lowercase();
    let endpoint = LnUrl::from_str(&value)
        .map(|lnurl| lnurl.url)
        .or_else(|_| LightningAddress::from_str(&value).map(|address| address.lnurlp_url()))
        .map_err(|_| pay_error("invalid_lnurl"))?;
    let url = reqwest::Url::parse(&endpoint).map_err(|_| pay_error("invalid_lnurl"))?;
    let host = url.host_str().ok_or_else(|| pay_error("invalid_lnurl"))?;
    if host
        .trim_end_matches('.')
        .to_ascii_lowercase()
        .ends_with(".onion")
        || host.eq_ignore_ascii_case("onion")
    {
        return Err(pay_error("onion_unsupported"));
    }
    if url.scheme() != "https" || !url.username().is_empty() || url.password().is_some() {
        return Err(pay_error("invalid_lnurl"));
    }
    Ok(url)
}

#[derive(serde::Deserialize)]
struct PayLimitsResponse {
    tag: String,
    status: Option<String>,
    #[serde(rename = "minSendable")]
    min_sendable: u64,
    #[serde(rename = "maxSendable")]
    max_sendable: u64,
}

fn parse_pay_bounds(bytes: &[u8]) -> Result<LnurlPayBounds, BoltzError> {
    let response: PayLimitsResponse =
        serde_json::from_slice(bytes).map_err(|_| pay_error("invalid_pay_response"))?;
    if response.tag != "payRequest"
        || response
            .status
            .as_deref()
            .is_some_and(|status| status != "OK")
        || response.min_sendable == 0
        || response.min_sendable > response.max_sendable
    {
        return Err(pay_error("invalid_pay_response"));
    }
    Ok(LnurlPayBounds {
        min_sendable_msat: response.min_sendable,
        max_sendable_msat: response.max_sendable,
    })
}

/// LNURL utilities for working with Lightning Network URLs
#[derive(Clone, serde::Serialize, serde::Deserialize, Debug)]
pub struct Lnurl {
    pub value: String,
}

impl Lnurl {
    /// Create a new Lnurl instance
    pub fn new(value: String) -> Self {
        Lnurl { value }
    }
    /// LNURL helper to validate an lnurl string
    pub fn validate(&self) -> bool {
        boltz_lnurl::validate_lnurl(&self.value)
    }
    /// Read only the recipient's LNURL-pay amount limits.
    pub async fn fetch_pay_limits(&self) -> Result<LnurlPayBounds, BoltzError> {
        let url = pay_endpoint(&self.value)?;
        let client = reqwest::Client::builder()
            .redirect(reqwest::redirect::Policy::none())
            .timeout(Duration::from_secs(15))
            .build()
            .map_err(|_| pay_error("pay_request_failed"))?;
        let mut response = client
            .get(url)
            .send()
            .await
            .map_err(|_| pay_error("pay_request_failed"))?;
        if !response.status().is_success() {
            return Err(pay_error("pay_request_failed"));
        }
        let mut body = Vec::new();
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|_| pay_error("pay_request_failed"))?
        {
            if chunk.len() > MAX_PAY_RESPONSE_BYTES - body.len() {
                return Err(pay_error("pay_response_too_large"));
            }
            body.extend_from_slice(&chunk);
        }
        parse_pay_bounds(&body)
    }
    /// LNURL helper to get an invoice from an lnurl string
    pub async fn fetch_invoice(&self, msats: u64) -> Result<String, BoltzError> {
        Ok(boltz_lnurl::fetch_invoice(&self.value, msats).await?)
    }
    /// LNURL helper to get an lnurl-w voucher amount
    pub async fn get_voucher_max_amount(&self) -> Result<u64, BoltzError> {
        let max_withdrawable_msat = boltz_lnurl::create_withdraw_response(&self.value)
            .await?
            .max_withdrawable;
        Ok(max_withdrawable_msat / 1000)
    }
    /// LNURL helper to claim an lnurl-w
    pub async fn withdraw(&self, invoice: String) -> Result<(), BoltzError> {
        Ok(boltz_lnurl::process_withdrawal(
            &boltz_lnurl::create_withdraw_response(&self.value).await?,
            &invoice,
        )
        .await?)
    }
}
