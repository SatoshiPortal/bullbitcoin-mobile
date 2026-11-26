//! A minimal SOCKS5 front end for [`arti_client::TorClient`].
//!
//! # Why this exists
//!
//! The obvious move is to depend on the `arti` crate and call
//! `arti::proxy::run_proxy`. We deliberately do not: since arti 2.0.0 the Tor
//! Project marked *every* API in the `arti` crate experimental, "likely to get
//! moved into other crates or removed", and reaching them needs the
//! `experimental-api` feature. That dependency is precisely what pinned the
//! previous wrapper to arti 1.7.0 while upstream shipped nine more releases.
//!
//! So we speak the wire protocol ourselves through `tor-socksproto`, a normal
//! non-experimental crate, and keep `arti-client` as the only high-level
//! dependency.
//!
//! # Why a SOCKS proxy at all
//!
//! The port is the integration point for application clients that already
//! support a SOCKS5 endpoint. Binding `TorClient::connect` directly would
//! require separate transports over Arti streams for every protocol.
//!
//! # Scope
//!
//! `CONNECT` only. The Tor-specific `RESOLVE`/`RESOLVE_PTR` extensions are
//! answered with a clean SOCKS error: no consumer of ours uses them, and
//! silently mis-implementing name resolution in an anonymity path is worse
//! than refusing it.

use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::sync::Arc;
use std::time::Duration;

use arti_client::{HasKind as _, IntoTorAddr as _, TorClient};
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::{TcpListener, TcpStream};
use tokio::task::JoinSet;
use tor_error::ErrorKind;
use tor_rtcompat::tokio::TokioNativeTlsRuntime;
use tor_socksproto::{
    Buffer, Handshake as _, NextStep, SocksCmd, SocksProxyHandshake, SocksRequest, SocksStatus,
};
use tracing::{debug, warn};

use super::error::{TorFailure, TorResult};
use super::session::SocksPolicy;

const MAX_CONNECTIONS: usize = 64;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(10);
const DEFAULT_CONNECT_TIMEOUT: Duration = Duration::from_secs(30);

fn connect_timeout(timeout_ms: Option<u64>) -> Duration {
    timeout_ms.map_or(DEFAULT_CONNECT_TIMEOUT, Duration::from_millis)
}

fn socks_status_for_error(kind: ErrorKind) -> SocksStatus {
    match kind {
        ErrorKind::TorDirectoryError
        | ErrorKind::TorDirectoryUnusable
        | ErrorKind::NoPath
        | ErrorKind::NoExit
        | ErrorKind::CircuitCollapse
        | ErrorKind::CircuitRefused
        | ErrorKind::BootstrapRequired
        | ErrorKind::RemoteNetworkTimeout => SocksStatus::NETWORK_UNREACHABLE,
        ErrorKind::OnionServiceNotFound
        | ErrorKind::OnionServiceNotRunning
        | ErrorKind::OnionServiceConnectionFailed
        | ErrorKind::RemoteHostNotFound
        | ErrorKind::RemoteHostResolutionFailed => SocksStatus::HOST_UNREACHABLE,
        ErrorKind::RemoteConnectionRefused
        | ErrorKind::RemoteStreamClosed
        | ErrorKind::RemoteStreamReset
        | ErrorKind::RemoteStreamError
        | ErrorKind::OnionServiceProtocolViolation => SocksStatus::CONNECTION_REFUSED,
        // The local timeout is handled separately because it has no Arti kind.
        // Any future or otherwise unclassified Arti kind stays deliberately
        // conservative and does not claim a specific network cause.
        _ => SocksStatus::GENERAL_FAILURE,
    }
}

fn socks_status_for_timeout() -> SocksStatus {
    SocksStatus::TTL_EXPIRED
}

/// Bind a SOCKS5 listener on loopback.
///
/// Pass `0` to let the OS pick a free port; the bound port is returned in the
/// [`SocketAddr`]. That is deliberate: the previous implementation drew a
/// random port in Dart, closed the probe socket, then bound it later in Rust,
/// which is a time-of-check/time-of-use race against any other process on the
/// device.
pub(crate) async fn bind_loopback(port: u16) -> TorResult<(TcpListener, SocketAddr)> {
    let requested = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), port);
    let listener = TcpListener::bind(requested)
        .await
        .map_err(|e| TorFailure::listener_bind(format!("bind {requested}: {e}")))?;
    let actual = listener
        .local_addr()
        .map_err(|e| TorFailure::listener_bind(format!("local_addr: {e}")))?;
    Ok((listener, actual))
}

/// Accept connections forever, tunnelling each one over Tor.
///
/// Returns only if the listener itself fails. Per-connection errors are logged
/// and dropped: one malformed client must not take the proxy down.
pub(crate) async fn serve(
    listener: TcpListener,
    client: Arc<TorClient<TokioNativeTlsRuntime>>,
    policy: SocksPolicy,
    connect_timeout_ms: Option<u64>,
) -> TorResult<()> {
    let mut connections = JoinSet::new();
    let permits = Arc::new(tokio::sync::Semaphore::new(MAX_CONNECTIONS));
    loop {
        tokio::select! {
            accepted = listener.accept() => {
                let (stream, peer) = match accepted {
                    Ok(v) => v,
                    Err(e) => {
                        // The proxy is now dead. Every later SOCKS connection
                        // will be refused with no explanation, so this must not
                        // be silent.
                        tracing::error!(error = %e, "socks accept loop terminated");
                        return Err(TorFailure::listener_bind(format!("accept: {e}")));
                    }
                };

                let Ok(permit) = Arc::clone(&permits).try_acquire_owned() else {
                    debug!(%peer, "socks connection limit reached");
                    drop(stream);
                    continue;
                };
                let client = Arc::clone(&client);
                connections.spawn(async move {
                    let _permit = permit;
                    if let Err(e) = handle_conn(stream, client, policy, connect_timeout_ms).await {
                        // Deliberately not `warn!` with the target address: that
                        // would put the user's browsing destinations in the log.
                        debug!(%peer, error = %e, "socks connection ended with an error");
                    }
                });
            }
            completed = connections.join_next(), if !connections.is_empty() => {
                if let Some(Err(e)) = completed {
                    debug!(error = %e, "socks connection task failed");
                }
            }
        }
    }
}

/// Run one SOCKS5 exchange and, on `CONNECT`, splice the two streams.
async fn handle_conn(
    mut sock: TcpStream,
    client: Arc<TorClient<TokioNativeTlsRuntime>>,
    policy: SocksPolicy,
    connect_timeout_ms: Option<u64>,
) -> TorResult<()> {
    let request = tokio::time::timeout(HANDSHAKE_TIMEOUT, negotiate(&mut sock))
        .await
        .map_err(|_| TorFailure::unexpected("socks handshake timed out"))??;

    let addr = request.addr().to_string();
    let port = request.port();

    if request.command() != SocksCmd::CONNECT {
        warn!(command = ?request.command(), "unsupported SOCKS command");
        reply(&mut sock, &request, SocksStatus::COMMAND_NOT_SUPPORTED).await?;
        return Ok(());
    }

    // Whether non-onion destinations are relayed is the caller's decision,
    // not this package's — see `SocksPolicy`.
    if !policy.allows(&addr) {
        reply(&mut sock, &request, SocksStatus::NOT_ALLOWED).await?;
        return Ok(());
    }

    // `e` here would name the destination; report only its kind.
    let target = (addr.as_str(), port)
        .into_tor_addr()
        .map_err(|e| TorFailure::connect(format!("rejected target address: {}", e.kind())))?;

    let tor_stream =
        match tokio::time::timeout(connect_timeout(connect_timeout_ms), client.connect(target))
            .await
        {
            Err(_) => {
                reply(&mut sock, &request, socks_status_for_timeout()).await?;
                return Err(TorFailure::connect("tor connect timed out"));
            }
            Ok(Ok(s)) => s,
            Ok(Err(e)) => {
                // Report the failure to the SOCKS client rather than dropping the
                // socket, so the caller sees a protocol-level refusal instead of a
                // bare connection reset it cannot attribute.
                reply(&mut sock, &request, socks_status_for_error(e.kind())).await?;
                // Deliberately `e.kind()` and not `e`: arti's Display embeds the
                // destination, and this string ends up in logs.
                return Err(TorFailure::connect(format!(
                    "tor connect failed: {}",
                    e.kind()
                )));
            }
        };

    reply(&mut sock, &request, SocksStatus::SUCCEEDED).await?;

    let mut tor_stream = tor_stream;
    tokio::io::copy_bidirectional(&mut sock, &mut tor_stream)
        .await
        .map_err(|e| TorFailure::connect(format!("relay: {e}")))?;

    Ok(())
}

/// Drive the SOCKS handshake state machine to completion.
async fn negotiate(sock: &mut TcpStream) -> TorResult<SocksRequest> {
    let mut handshake = SocksProxyHandshake::new();
    let mut inbuf = Buffer::new();

    loop {
        let step = handshake
            .step(&mut inbuf)
            .map_err(|e| TorFailure::unexpected(format!("socks handshake: {e}")))?;

        match step {
            NextStep::Recv(mut recv) => {
                let n = sock
                    .read(recv.buf())
                    .await
                    .map_err(|e| TorFailure::unexpected(format!("socks read: {e}")))?;
                if n == 0 {
                    return Err(TorFailure::unexpected("socks client closed mid-handshake"));
                }
                recv.note_received(n)
                    .map_err(|e| TorFailure::unexpected(format!("socks note_received: {e}")))?;
            }
            NextStep::Send(data) => {
                sock.write_all(&data)
                    .await
                    .map_err(|e| TorFailure::unexpected(format!("socks write: {e}")))?;
                sock.flush()
                    .await
                    .map_err(|e| TorFailure::unexpected(format!("socks flush: {e}")))?;
            }
            NextStep::Finished(fin) => {
                // `forbid_pipelining` rejects a client that sent payload before
                // our reply. Accepting it would mean relaying bytes we never
                // authorised over a Tor circuit.
                return fin
                    .into_output_forbid_pipelining()
                    .map_err(|e| TorFailure::unexpected(format!("socks pipelining: {e}")));
            }
        }
    }
}

/// Encode and send a SOCKS reply.
async fn reply(sock: &mut TcpStream, request: &SocksRequest, status: SocksStatus) -> TorResult<()> {
    let bytes = request
        .reply(status, None)
        .map_err(|e| TorFailure::unexpected(format!("encode socks reply: {e}")))?;
    sock.write_all(&bytes)
        .await
        .map_err(|e| TorFailure::unexpected(format!("socks reply write: {e}")))?;
    sock.flush()
        .await
        .map_err(|e| TorFailure::unexpected(format!("socks reply flush: {e}")))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn maps_each_error_class_to_the_compatible_rfc1928_status() {
        for kind in [
            ErrorKind::TorDirectoryError,
            ErrorKind::TorDirectoryUnusable,
            ErrorKind::NoPath,
            ErrorKind::NoExit,
            ErrorKind::CircuitCollapse,
            ErrorKind::CircuitRefused,
            ErrorKind::BootstrapRequired,
            ErrorKind::RemoteNetworkTimeout,
        ] {
            assert_eq!(
                socks_status_for_error(kind),
                SocksStatus::NETWORK_UNREACHABLE
            );
        }
        for kind in [
            ErrorKind::OnionServiceNotFound,
            ErrorKind::OnionServiceNotRunning,
            ErrorKind::OnionServiceConnectionFailed,
            ErrorKind::RemoteHostNotFound,
            ErrorKind::RemoteHostResolutionFailed,
        ] {
            assert_eq!(socks_status_for_error(kind), SocksStatus::HOST_UNREACHABLE);
        }
        for kind in [
            ErrorKind::RemoteConnectionRefused,
            ErrorKind::RemoteStreamClosed,
            ErrorKind::RemoteStreamReset,
            ErrorKind::RemoteStreamError,
            ErrorKind::OnionServiceProtocolViolation,
        ] {
            assert_eq!(
                socks_status_for_error(kind),
                SocksStatus::CONNECTION_REFUSED
            );
        }
        assert_eq!(
            socks_status_for_error(ErrorKind::Other),
            SocksStatus::GENERAL_FAILURE
        );
        assert_eq!(socks_status_for_timeout(), SocksStatus::TTL_EXPIRED);
    }

    #[test]
    fn uses_thirty_seconds_by_default_and_accepts_a_caller_budget() {
        assert_eq!(connect_timeout(None), Duration::from_secs(30));
        assert_eq!(connect_timeout(Some(1_250)), Duration::from_millis(1_250));
    }

    #[tokio::test]
    async fn bind_zero_reports_the_actual_port() {
        let (_listener, addr) = bind_loopback(0).await.expect("bind");
        assert_ne!(addr.port(), 0, "port 0 must be resolved to a real port");
        assert!(
            addr.ip().is_loopback(),
            "must never bind a public interface"
        );
    }

    #[tokio::test]
    async fn bind_is_loopback_only() {
        let (_listener, addr) = bind_loopback(0).await.expect("bind");
        assert_eq!(addr.ip(), IpAddr::V4(Ipv4Addr::LOCALHOST));
    }

    #[tokio::test]
    async fn binding_a_taken_port_fails_cleanly() {
        let (_held, addr) = bind_loopback(0).await.expect("bind");
        let err = bind_loopback(addr.port()).await.expect_err("must fail");
        assert_eq!(err.kind, super::super::error::TorFailureKind::ListenerBind);
    }

    /// The handshake must not hang or panic when the peer disappears; it must
    /// return a modelled failure.
    #[tokio::test]
    async fn negotiate_reports_early_close() {
        let (listener, addr) = bind_loopback(0).await.expect("bind");
        let accept = tokio::spawn(async move {
            let (mut sock, _) = listener.accept().await.expect("accept");
            negotiate(&mut sock).await
        });

        let client = TcpStream::connect(addr).await.expect("connect");
        drop(client); // close before sending a single byte

        let res = accept.await.expect("join");
        assert!(res.is_err(), "closing mid-handshake must be an error");
    }

    #[test]
    fn the_onion_only_policy_filters_hosts_and_the_default_does_not() {
        assert!(SocksPolicy::OnionOnly.allows("examplehiddenservice.onion"));
        assert!(SocksPolicy::OnionOnly.allows("EXAMPLEHIDDENSERVICE.ONION."));
        assert!(!SocksPolicy::OnionOnly.allows("example.com"));
        assert!(!SocksPolicy::OnionOnly.allows("example.onion.invalid"));
        assert!(!SocksPolicy::OnionOnly.allows("127.0.0.1"));

        // The library default relays anything; restricting is the caller's job.
        assert!(SocksPolicy::default().allows("example.com"));
        assert!(SocksPolicy::Any.allows("examplehiddenservice.onion"));
    }
}
