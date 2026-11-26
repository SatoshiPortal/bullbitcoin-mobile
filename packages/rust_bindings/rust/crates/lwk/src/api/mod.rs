pub mod descriptor;
pub mod error;
pub mod types;
pub mod wallet;
pub mod transaction;
pub mod blockchain;

use std::sync::Once;

static CRYPTO_PROVIDER_INIT: Once = Once::new();

/// rustls 0.23 panics when both the `ring` and `aws-lc-rs` crypto providers are
/// linked (they both are, transitively, in the bull_sdk aggregate) because it
/// can't pick a process default. Install `ring` once before any electrum TLS
/// connection so the SSL handshake doesn't panic.
pub(crate) fn ensure_crypto_provider() {
    CRYPTO_PROVIDER_INIT.call_once(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}