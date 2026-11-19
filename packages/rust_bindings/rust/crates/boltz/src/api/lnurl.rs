use boltz_client::util::lnurl;

use super::error::BoltzError;

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
        lnurl::validate_lnurl(&self.value)
    }
    /// LNURL helper to get an invoice from an lnurl string
    pub async fn fetch_invoice(&self, msats: u64) -> Result<String, BoltzError> {
        Ok(lnurl::fetch_invoice(&self.value, msats).await?)
    }
    /// LNURL helper to get an lnurl-w voucher amount
    pub async fn get_voucher_max_amount(&self) -> Result<u64, BoltzError> {
        let max_withdrawable_msat = lnurl::create_withdraw_response(&self.value)
            .await?
            .max_withdrawable;
        Ok(max_withdrawable_msat / 1000)
    }
    /// LNURL helper to claim an lnurl-w
    pub async fn withdraw(&self, invoice: String) -> Result<(), BoltzError> {
        Ok(lnurl::process_withdrawal(
            &lnurl::create_withdraw_response(&self.value).await?,
            &invoice,
        )
        .await?)
    }
}
