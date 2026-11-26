use std::str::FromStr;
use std::time::Duration;

use lwk_wollet::{
    blocking::BlockchainBackend,
    elements::{
        pset::{serialize::Deserialize, PartiallySignedTransaction},
        Transaction, Txid,
    },
    ElectrumClient, ElectrumClientBuilder,
};

use super::error::LwkError;
use super::types::LiquidNetwork;

/// Plaintext is allowed only for an explicit `tcp://` URL on regtest.
/// All other combinations use TLS with domain validation.
pub(crate) fn electrum_url(network: LiquidNetwork, url: &str) -> String {
    if network == LiquidNetwork::Regtest && url.starts_with("tcp://") {
        return url.to_owned();
    }
    let host_port = url
        .strip_prefix("ssl://")
        .or_else(|| url.strip_prefix("tcp://"))
        .unwrap_or(url);
    format!("ssl://{host_port}")
}

pub(crate) fn electrum_client(
    network: LiquidNetwork,
    url: &str,
    timeout: Option<u8>,
) -> Result<ElectrumClient, LwkError> {
    let mut builder = ElectrumClientBuilder::new(&electrum_url(network, url));
    if let Some(timeout) = timeout {
        builder = builder.timeout(Duration::from_secs(timeout.into()));
    }
    Ok(builder.build()?)
}

pub struct Blockchain {}

impl Blockchain {
    /// Check that a connection to the Electrum server can be opened.
    /// Plaintext is allowed only for a `tcp://` URL on regtest.
    ///
    /// ⚠️ For TLS, like `Wallet.sync`, it always validates the certificate against the
    /// server's domain name, so a self-signed or IP-addressed server fails.
    pub fn test(
        &self,
        network: LiquidNetwork,
        electrum_url: String,
    ) -> anyhow::Result<(), LwkError> {
        super::ensure_crypto_provider();
        electrum_client(network, &electrum_url, None)?;
        Ok(())
    }
    /// Broadcast transaction bytes over TLS, or plaintext for `tcp://` on regtest.
    pub fn broadcast_tx_bytes(
        network: LiquidNetwork,
        electrum_url: String,
        tx_bytes: Vec<u8>,
    ) -> anyhow::Result<String, LwkError> {
        super::ensure_crypto_provider();
        let electrum_client = electrum_client(network, &electrum_url, None)?;
        let tx = Transaction::deserialize(&tx_bytes)?;
        let txid: Txid = electrum_client.broadcast(&tx)?;
        Ok(txid.to_string())
    }

    /// Broadcast a signed pset over TLS, or plaintext for `tcp://` on regtest.
    pub fn broadcast_signed_pset(
        network: LiquidNetwork,
        electrum_url: String,
        signed_pset: String,
    ) -> anyhow::Result<String, LwkError> {
        super::ensure_crypto_provider();
        let electrum_client = electrum_client(network, &electrum_url, None)?;
        let pset = PartiallySignedTransaction::from_str(&signed_pset)?;
        let tx = pset.extract_tx()?;
        let txid: Txid = electrum_client.broadcast(&tx)?;
        Ok(txid.to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn plaintext_only_for_a_tcp_url_on_regtest() {
        for network in [
            LiquidNetwork::Mainnet,
            LiquidNetwork::Testnet,
            LiquidNetwork::Regtest,
        ] {
            for scheme in ["", "ssl://", "tcp://"] {
                let expected = if network == LiquidNetwork::Regtest && scheme == "tcp://" {
                    "tcp://example.com:50002"
                } else {
                    "ssl://example.com:50002"
                };
                assert_eq!(
                    electrum_url(network, &format!("{scheme}example.com:50002")),
                    expected
                );
            }
        }
    }

    #[test]
    fn tls_to_an_ip_address_is_rejected() {
        // Rejected while parsing the URL, before any connection attempt.
        let err = electrum_client(LiquidNetwork::Mainnet, "127.0.0.1:50002", None).unwrap_err();
        assert!(err.msg.contains("SslWithoutDomain"), "{}", err.msg);
    }
}
