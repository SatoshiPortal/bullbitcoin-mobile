//! Two local protocol fixtures, with normal TLS and explicit fixture trust.
use axum_server::tls_rustls::RustlsConfig;
use payjoin_mailroom::{config::Config, ohttp_relay::GatewayUri, serve_manual_tls};
use rustls::{pki_types::CertificateDer, RootCertStore};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    rustls::crypto::ring::default_provider()
        .install_default()
        .map_err(|_| anyhow::anyhow!("TLS provider already configured"))?;
    let tls = RustlsConfig::from_pem_file("/data/cert.pem", "/data/key.pem").await?;
    let mut roots = RootCertStore::empty();
    roots.add(CertificateDer::from(std::fs::read("/data/cert.der")?))?;
    let mut first = Config::default();
    first.listener = "[::]:8040".parse().map_err(anyhow::Error::msg)?;
    first.storage_dir = "/data/directory-a".into();
    let mut second = Config::default();
    second.listener = "[::]:8041".parse().map_err(anyhow::Error::msg)?;
    second.storage_dir = "/data/directory-b".into();
    let gateway_b = "https://127.0.0.1:8041"
        .parse::<GatewayUri>()
        .map_err(|error| anyhow::anyhow!("{error}"))?;
    let gateway_a = "https://localhost:8040"
        .parse::<GatewayUri>()
        .map_err(|error| anyhow::anyhow!("{error}"))?;
    let (_, mut a) =
        serve_manual_tls(first, Some(tls.clone()), roots.clone(), Some(gateway_b)).await?;
    let (_, mut b) = serve_manual_tls(second, Some(tls), roots, Some(gateway_a)).await?;
    let mut terminate = tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate())?;
    tokio::select! {
        result = &mut a => { result??; }
        result = &mut b => { result??; }
        result = tokio::signal::ctrl_c() => { result?; }
        _ = terminate.recv() => {}
    }
    a.abort();
    b.abort();
    Ok(())
}
