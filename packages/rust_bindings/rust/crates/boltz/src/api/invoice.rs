use std::{
    str::FromStr,
    time::{Duration, SystemTime, UNIX_EPOCH},
};

use boltz_client::{swaps::boltz::BoltzApiClientV2, Bolt11Invoice};

use crate::util::{ensure_http_prefix, HTTP_TIMEOUT};

use super::error::BoltzError;

#[derive(Debug, Clone)]
pub struct DecodedInvoice {
    pub msats: u64,
    pub expiry: u64,
    pub expires_in: u64,
    pub expires_at: u64,
    pub is_expired: bool,
    pub network: String,
    pub cltv_exp_delta: u64,
    pub bip21: Option<String>,
    pub preimage_hash: String,
    pub description: String,
}

impl DecodedInvoice {
    pub async fn from_string(s: String, boltz_url: Option<String>) -> Result<Self, BoltzError> {
        let invoice = match Bolt11Invoice::from_str(&s) {
            Ok(result) => result,
            Err(e) => return Err(BoltzError::new("Input".to_string(), e.to_string())),
        };
        let bip21 = if boltz_url.is_some() {
            let mrh = match boltz_client::swaps::magic_routing::find_magic_routing_hint(&s) {
                Ok(s) => s,
                Err(_) => None,
            };
            if mrh.is_none() {
                None
            } else {
                let boltz_client = BoltzApiClientV2::new(
                    ensure_http_prefix(&boltz_url.unwrap()),
                    Some(HTTP_TIMEOUT),
                );
                match boltz_client.get_mrh_bip21(&s).await {
                    Ok(r) => Some(r.bip21),
                    Err(_) => None,
                }
            }
        } else {
            None
        };
        let now = SystemTime::now();
        let duration_since_epoch = now.duration_since(UNIX_EPOCH).expect("Time went backwards");
        let current_secs = duration_since_epoch.as_secs();
        let expires_at = invoice
            .expires_at()
            .unwrap_or(Duration::from_secs(0))
            .as_secs();

        Ok(DecodedInvoice {
            expiry: invoice.expiry_time().as_secs(),
            expires_in: invoice
                .expiration_remaining_from_epoch(duration_since_epoch)
                .as_secs(),
            expires_at: expires_at,
            is_expired: if current_secs >= expires_at {
                true
            } else {
                false
            },
            msats: invoice.amount_milli_satoshis().unwrap_or(0),
            cltv_exp_delta: invoice.min_final_cltv_expiry_delta(),
            network: invoice.network().to_string(),
            bip21: bip21,
            preimage_hash: invoice.payment_hash().to_string(),
            description: invoice.description().to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const INVOICE_123_SAT: &str = "lntb1230n1pjmwkxwpp5etvpredwjpwvsrmrcs3l854tcwyz8tnfm453uyp3kcsrmnmu26xsdqqcqzzsxqyjw5qsp5jmejjyf0v6lyn3c5z6uxdslxtnu6t72perfp8ps6ldyen5as9juq9qyyssqtc8409xlyar4vmn70sszyzeu3k28jzlx0k2cjpg6pvh8mdglkn3ymxslmq8entcz56hwu3hx0d8mzjsvtkc3vu9da6j88exflp8urkqppw0vkq";
    const INVOICE_26M_SAT: &str = "lntb260m1pjmwkv7pp5g8hy6pe8md7rz6jwcgvntgsqwr2eck0rcvj8trqkuehuvl9g2w4qdqqcqzzsxqyjw5qsp59fq60rmf6mkx9hhkcdw4akl7ksgzl3rfchgj94f6vfwzq9x7wvps9qyyssq2mkjtc67ktcnxf0cch8d66fkxlx9fyryy2k79cqv8gzjxw7wmh7xm3qdra7lawm6nvjrs2zyu50qf428uzqu25mxmvev6zckzt8ew7gp0xfna2";

    #[tokio::test]
    async fn decodes_amount_and_network_offline() {
        let decoded = DecodedInvoice::from_string(INVOICE_123_SAT.to_string(), None)
            .await
            .expect("decode 123 sat invoice");
        assert_eq!(decoded.msats, 123_000);
        assert_eq!(decoded.network, "testnet");
        assert!(decoded.bip21.is_none());
        assert_eq!(decoded.preimage_hash.len(), 64);
        assert!(decoded.expiry > 0);
    }

    #[tokio::test]
    async fn decodes_millibitcoin_amount() {
        let decoded = DecodedInvoice::from_string(INVOICE_26M_SAT.to_string(), None)
            .await
            .expect("decode 26m sat invoice");
        assert_eq!(decoded.msats, 26_000_000_000);
        assert_eq!(decoded.network, "testnet");
    }

    #[tokio::test]
    async fn old_invoice_is_expired() {
        let decoded = DecodedInvoice::from_string(INVOICE_123_SAT.to_string(), None)
            .await
            .unwrap();
        assert!(decoded.is_expired);
    }

    #[tokio::test]
    async fn invalid_invoice_errors() {
        let result = DecodedInvoice::from_string("lntbinvalidinvoice".to_string(), None).await;
        assert!(result.is_err());
    }
}
