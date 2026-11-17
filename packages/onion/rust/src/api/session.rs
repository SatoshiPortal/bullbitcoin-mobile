//! Circuit-isolated SOCKS sessions derived from the shared Tor client.

use std::sync::{Arc, Mutex, Weak};

use arti_client::TorClient;
use tokio::task::JoinHandle;
use tor_rtcompat::tokio::TokioNativeTlsRuntime;
use tracing::info;

use super::error::{TorFailure, TorResult};
use super::socks;

/// Inner state shared with the parent service's weak session registry.
pub(crate) struct TorSessionInner {
    client: Mutex<Option<Arc<TorClient<TokioNativeTlsRuntime>>>>,
    proxy_task: Mutex<Option<JoinHandle<TorResult<()>>>>,
    socks_port: u16,
}

/// Which destinations a session's SOCKS listener will relay.
///
/// The library default is [`SocksPolicy::Any`]: a Tor proxy that refuses the
/// clearnet is not a Tor proxy, and deciding otherwise is the embedding
/// application's business, not this package's.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum SocksPolicy {
    /// Relay any destination the Tor network can reach.
    #[default]
    Any,
    /// Relay `.onion` destinations only; answer anything else `NOT_ALLOWED`.
    ///
    /// Worth knowing before choosing it: a loopback TCP port is host-local,
    /// not process-private, and this proxy performs no authentication, so any
    /// process on the device that finds the port can use it. An application
    /// that only ever contacts hidden services can pick this to bound what
    /// that exposure is worth — it narrows the open door, it does not close
    /// it. Closing it needs SOCKS credentials or an `AF_UNIX` socket.
    OnionOnly,
}

impl SocksPolicy {
    pub(crate) fn allows(self, host: &str) -> bool {
        match self {
            Self::Any => true,
            Self::OnionOnly => is_onion_host(host),
        }
    }
}

fn is_onion_host(host: &str) -> bool {
    host.trim_end_matches('.')
        .to_ascii_lowercase()
        .ends_with(".onion")
}

/// A loopback SOCKS5 listener whose streams cannot share circuits with another session.
///
/// Arti's [`TorClient::isolated_client`] guarantee applies between every
/// `TorSession`, including the default session exposed by
/// [`super::client::TorService::socks_port`]. Configuration, directory state,
/// guards, channels, and the pluggable transport remain shared.
pub struct TorSession {
    pub(crate) inner: Arc<TorSessionInner>,
}

impl TorSession {
    pub(crate) async fn start(
        root_client: &TorClient<TokioNativeTlsRuntime>,
        socks_port: u16,
        policy: SocksPolicy,
        connect_timeout_ms: Option<u64>,
    ) -> Result<Self, TorFailure> {
        let (listener, addr) = socks::bind_loopback(socks_port).await?;
        let client = root_client.isolated_client();
        let bound_port = addr.port();
        info!(port = bound_port, "isolated socks session bound");
        let proxy_task = tokio::spawn(socks::serve(
            listener,
            Arc::clone(&client),
            policy,
            connect_timeout_ms,
        ));

        Ok(Self {
            inner: Arc::new(TorSessionInner {
                client: Mutex::new(Some(client)),
                proxy_task: Mutex::new(Some(proxy_task)),
                socks_port: bound_port,
            }),
        })
    }

    /// The loopback SOCKS port assigned to this session.
    pub fn socks_port(&self) -> u16 {
        self.inner.socks_port
    }

    /// Whether this session's SOCKS accept loop is still running.
    pub fn proxy_is_alive(&self) -> bool {
        self.inner.proxy_is_alive()
    }

    /// Stop this session without affecting the shared Tor core or other sessions.
    pub async fn stop(&self) {
        self.inner.stop().await;
    }

    pub(crate) fn downgrade(&self) -> Weak<TorSessionInner> {
        Arc::downgrade(&self.inner)
    }

    #[cfg(test)]
    pub(crate) fn client(&self) -> Option<Arc<TorClient<TokioNativeTlsRuntime>>> {
        self.inner.client()
    }
}

impl TorSessionInner {
    pub(crate) fn proxy_is_alive(&self) -> bool {
        self.client().is_some()
            && self
                .proxy_task
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner())
                .as_ref()
                .is_some_and(|task| !task.is_finished())
    }

    pub(crate) async fn stop(&self) {
        let proxy_task = self
            .proxy_task
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
        if let Some(proxy_task) = proxy_task {
            proxy_task.abort();
            let _ = proxy_task.await;
        }
        self.client
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
    }

    pub(crate) fn abort(&self) {
        if let Some(proxy_task) = self
            .proxy_task
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take()
        {
            proxy_task.abort();
        }
        self.client
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
    }

    /// Poison is recovered, not propagated — see `TorService::client` for why.
    fn client(&self) -> Option<Arc<TorClient<TokioNativeTlsRuntime>>> {
        self.client
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
    }
}

impl Drop for TorSession {
    fn drop(&mut self) {
        self.inner.abort();
    }
}
