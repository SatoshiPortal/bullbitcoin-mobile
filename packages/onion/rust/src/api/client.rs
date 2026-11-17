//! The service object: one Tor client plus its local SOCKS5 listener.

use std::net::{Ipv4Addr, SocketAddr};
use std::sync::{Arc, Mutex, Weak};
use std::time::{Duration, Instant};

use arti_client::config::pt::TransportConfigBuilder;
use arti_client::config::{BridgeConfigBuilder, TorClientConfigBuilder};
use arti_client::{BootstrapBehavior, HasKind as _, IntoTorAddr as _, TorClient};
use futures::Stream;
use futures::StreamExt as _;
use tokio::sync::watch;
use tor_rtcompat::tokio::TokioNativeTlsRuntime;

use super::error::{TorFailure, TorResult};
use super::session::{SocksPolicy, TorSession, TorSessionInner};
use super::status::{TorStatus, TorTransport};
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;

/// A running Tor client with circuit-isolated loopback SOCKS5 sessions.
///
/// Construction is deliberately split from bootstrap: [`TorService::start`]
/// returns as soon as the listener is bound, so the caller learns the port and
/// can subscribe to [`TorService::status_stream`] *before* the slow part
/// begins. The old design blocked inside `create_bootstrapped()` with no
/// progress channel, which is why a censored network presented as an
/// indefinite spinner followed by an unattributable RecoverBull error.
pub struct TorService {
    client: Mutex<Option<Arc<TorClient<TokioNativeTlsRuntime>>>>,
    default_session: TorSession,
    sessions: Mutex<SessionRegistry>,
    transport: TorTransport,
    shutdown: watch::Sender<bool>,
}

struct SessionRegistry {
    stopping: bool,
    sessions: Vec<Weak<TorSessionInner>>,
}

impl TorService {
    /// Create the client and bind the SOCKS listener. Does not bootstrap.
    ///
    /// `socks_port` may be `0` to let the OS choose; read the real value back
    /// from [`TorService::socks_port`].
    pub async fn start(
        state_dir: &str,
        cache_dir: &str,
        socks_port: u16,
        policy: SocksPolicy,
    ) -> Result<Self, TorFailure> {
        Self::start_with_connect_timeout(state_dir, cache_dir, socks_port, policy, None).await
    }

    /// Create the client and bind the SOCKS listener with a custom Tor
    /// connection budget in milliseconds. `None` uses the 30-second default.
    pub async fn start_with_connect_timeout(
        state_dir: &str,
        cache_dir: &str,
        socks_port: u16,
        policy: SocksPolicy,
        connect_timeout_ms: Option<u64>,
    ) -> Result<Self, TorFailure> {
        Self::start_with_transport(
            state_dir,
            cache_dir,
            socks_port,
            TorTransport::Direct,
            None,
            policy,
            connect_timeout_ms,
        )
        .await
    }

    /// Create a client routed through an already-running Snowflake SOCKS proxy.
    ///
    /// The proxy is unmanaged: the native plugin owns its process-wide
    /// lifecycle while Arti only receives its loopback port.
    pub async fn start_with_snowflake(
        state_dir: &str,
        cache_dir: &str,
        socks_port: u16,
        snowflake_port: u16,
        policy: SocksPolicy,
    ) -> Result<Self, TorFailure> {
        Self::start_with_snowflake_connect_timeout(
            state_dir,
            cache_dir,
            socks_port,
            snowflake_port,
            policy,
            None,
        )
        .await
    }

    /// Create a Snowflake-routed client with a custom Tor connection budget in
    /// milliseconds. `None` uses the 30-second default.
    pub async fn start_with_snowflake_connect_timeout(
        state_dir: &str,
        cache_dir: &str,
        socks_port: u16,
        snowflake_port: u16,
        policy: SocksPolicy,
        connect_timeout_ms: Option<u64>,
    ) -> Result<Self, TorFailure> {
        if snowflake_port == 0 {
            return Err(TorFailure::configuration(
                "Snowflake proxy port must not be zero",
            ));
        }
        Self::start_with_transport(
            state_dir,
            cache_dir,
            socks_port,
            TorTransport::Snowflake,
            Some(snowflake_port),
            policy,
            connect_timeout_ms,
        )
        .await
    }

    async fn start_with_transport(
        state_dir: &str,
        cache_dir: &str,
        socks_port: u16,
        transport: TorTransport,
        snowflake_port: Option<u16>,
        policy: SocksPolicy,
        connect_timeout_ms: Option<u64>,
    ) -> Result<Self, TorFailure> {
        let runtime = TokioNativeTlsRuntime::current()
            .map_err(|e| TorFailure::configuration(format!("no tokio runtime: {e}")))?;

        // Besides state and cache, this derives Arti's keystore location from
        // the state directory. Setting storage fields manually leaves the
        // keystore at its unrelated default path.
        let mut cfg = TorClientConfigBuilder::from_directories(state_dir, cache_dir);
        // Required for .onion targets to be routable through the proxy.
        cfg.address_filter().allow_onion_addrs(true);
        if let Some(port) = snowflake_port {
            configure_snowflake(&mut cfg, port)?;
        }
        let cfg = cfg
            .build()
            .map_err(|e| TorFailure::configuration(format!("config: {e}")))?;

        let client = TorClient::with_runtime(runtime)
            .config(cfg)
            // `Manual` keeps bootstrap under our control so progress is
            // observable. With `OnDemand` the first proxied request would
            // silently trigger it and we would lose the reporting window.
            .bootstrap_behavior(BootstrapBehavior::Manual)
            .create_unbootstrapped()
            .map_err(|e| TorFailure::configuration(format!("create client: {e}")))?;

        let default_session =
            TorSession::start(&client, socks_port, policy, connect_timeout_ms).await?;
        let sessions = vec![default_session.downgrade()];
        let (shutdown, _) = watch::channel(false);

        Ok(Self {
            client: Mutex::new(Some(client)),
            default_session,
            sessions: Mutex::new(SessionRegistry {
                stopping: false,
                sessions,
            }),
            transport,
            shutdown,
        })
    }

    /// The port the SOCKS proxy is actually listening on.
    pub fn socks_port(&self) -> u16 {
        self.default_session.socks_port()
    }

    /// Open another loopback SOCKS listener with separate Tor circuits.
    ///
    /// Sessions share the root client's configuration, directory state,
    /// guards, channels, and transport. Their application streams never share
    /// circuits with the default session or with one another.
    pub async fn open_session(
        &self,
        socks_port: u16,
        policy: SocksPolicy,
    ) -> Result<TorSession, TorFailure> {
        self.open_session_with_connect_timeout(socks_port, policy, None)
            .await
    }

    /// Open an isolated SOCKS listener with a custom Tor connection budget in
    /// milliseconds. `None` uses the 30-second default.
    pub async fn open_session_with_connect_timeout(
        &self,
        socks_port: u16,
        policy: SocksPolicy,
        connect_timeout_ms: Option<u64>,
    ) -> Result<TorSession, TorFailure> {
        {
            let mut registry = self
                .sessions
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner());
            registry
                .sessions
                .retain(|session| session.strong_count() > 0);
            if registry.stopping {
                return Err(TorFailure::not_running(
                    "cannot open a session after service stop",
                ));
            }
        }

        let client = self
            .client()
            .ok_or_else(|| TorFailure::not_running("cannot open a session after service stop"))?;
        let session = TorSession::start(&client, socks_port, policy, connect_timeout_ms).await?;

        let stopped_during_open = {
            let mut registry = self
                .sessions
                .lock()
                .unwrap_or_else(|poisoned| poisoned.into_inner());
            if registry.stopping {
                true
            } else {
                registry.sessions.push(session.downgrade());
                false
            }
        };
        if stopped_during_open {
            session.stop().await;
            return Err(TorFailure::not_running(
                "service stopped while opening a session",
            ));
        }
        Ok(session)
    }

    /// Current readiness snapshot.
    pub fn status(&self) -> TorStatus {
        self.client()
            .map(|client| TorStatus::from_bootstrap(&client.bootstrap_status(), self.transport))
            .unwrap_or_else(|| TorStatus::stopped(self.transport))
    }

    /// A stream of readiness changes, for Rust callers and tests.
    ///
    /// Not monotonic: arti emits a *lower* readiness when connectivity drops or
    /// the directory expires. Consumers must treat every item as the current
    /// truth rather than latching the first `ready_for_traffic`.
    ///
    /// A stopped service yields an empty stream rather than panicking:
    /// subscribing is a read, and a race with [`TorService::stop`] is normal.
    ///
    /// Hidden from the binding: `flutter_rust_bridge` has no mapping for
    /// `impl Stream`, it wants a [`StreamSink`]. [`TorService::watch_status`]
    /// is the same data in the shape the generator understands.
    #[frb(ignore)]
    pub fn status_stream(&self) -> impl Stream<Item = TorStatus> + Send + 'static {
        let transport = self.transport;
        match self.client() {
            Some(client) => futures::future::Either::Left(
                client
                    .bootstrap_events()
                    .map(move |s| TorStatus::from_bootstrap(&s, transport)),
            ),
            None => futures::future::Either::Right(futures::stream::empty()),
        }
    }

    /// Forward readiness changes to Dart from the FRB async runtime.
    ///
    /// Same data as [`TorService::status_stream`], expressed as a
    /// `StreamSink` because that is the only stream shape
    /// `flutter_rust_bridge` generates for. The task ends when Dart drops the
    /// subscription, arti closes the channel, or [`TorService::stop`] runs.
    pub async fn watch_status(&self, sink: StreamSink<TorStatus>) {
        let Some(client) = self.client() else {
            return;
        };
        let mut events = client.bootstrap_events();
        let mut shutdown = self.shutdown.subscribe();
        let transport = self.transport;
        if *shutdown.borrow() {
            return;
        }
        loop {
            tokio::select! {
                changed = shutdown.changed() => {
                    if changed.is_err() || *shutdown.borrow() {
                        break;
                    }
                }
                event = events.next() => {
                    let Some(status) = event else { break };
                    // A send error means Dart cancelled; that is a normal
                    // end, not a failure to report.
                    if sink.add(TorStatus::from_bootstrap(&status, transport)).is_err() {
                        break;
                    }
                }
            }
        }
    }

    /// Bootstrap, resolving when the client is usable.
    pub async fn bootstrap(&self) -> Result<(), TorFailure> {
        const BOOTSTRAP_TIMEOUT_MS: u64 = 120_000;
        self.bootstrap_with_timeout(Some(BOOTSTRAP_TIMEOUT_MS))
            .await
    }

    /// Bootstrap with a caller-chosen deadline in milliseconds. `None` sets no
    /// deadline: the caller bounds the attempt and cancels it with `stop`.
    pub async fn bootstrap_with_timeout(&self, timeout_ms: Option<u64>) -> Result<(), TorFailure> {
        let timeout = timeout_ms.map(Duration::from_millis);
        let client = self
            .client()
            .ok_or_else(|| TorFailure::not_running("service stopped before bootstrap"))?;
        let mut shutdown = self.shutdown.subscribe();
        if *shutdown.borrow() {
            return Err(TorFailure::not_running("service stopped before bootstrap"));
        }
        let attempt = tokio::select! {
            changed = shutdown.changed() => {
                let _ = changed;
                return Err(TorFailure::not_running("service stopped during bootstrap"));
            }
            result = async {
                match timeout {
                    Some(timeout) => tokio::time::timeout(timeout, client.bootstrap()).await,
                    None => Ok(client.bootstrap().await),
                }
            } => result,
        };
        match attempt {
            Err(_) => Err(TorFailure::timeout(format!(
                "bootstrap exceeded {:?}",
                timeout.unwrap_or_default()
            ))),
            Ok(Err(e)) => {
                // The status snapshot carries `blockage`, which is what tells
                // the user *why* — including `Filtering`, the censorship
                // signature.
                Err(TorFailure::bootstrap(format!("{e}")))
            }
            Ok(Ok(())) => Ok(()),
        }
    }

    /// Open and immediately close a circuit to `host:port`, returning how long
    /// it took.
    ///
    /// This is the canary that separates "the Tor network is unreachable" from
    /// "an application hidden service is down". It goes through
    /// `TorClient::connect`
    /// directly, bypassing both the SOCKS listener and the application's
    /// servers, so a success here means Tor genuinely carries traffic.
    ///
    /// `ready_for_traffic` is not a substitute: it means "a request can be
    /// started", not "a request succeeded".
    ///
    /// Times are milliseconds: FRB has no outbound mapping for
    /// `std::time::Duration`, and an integer keeps `chrono` out of our types.
    ///
    /// No failure returned here names `host`. The probe target is a hidden
    /// service the user is reaching over Tor, and these strings are logged;
    /// `socks::handle_conn` keeps destinations out of its errors for the same
    /// reason, so this must not be the one place that reintroduces them.
    pub async fn probe(&self, host: &str, port: u16, timeout_ms: u32) -> Result<u32, TorFailure> {
        let client = self
            .client()
            .ok_or_else(|| TorFailure::not_running("service stopped before probe"))?;
        let timeout = Duration::from_millis(u64::from(timeout_ms));
        let target = (host, port)
            .into_tor_addr()
            // `e` would quote the address back; its kind is enough to tell a
            // malformed target from an unroutable one.
            .map_err(|e| TorFailure::connect(format!("bad probe target: {}", e.kind())))?;

        let started = Instant::now();
        let attempt = tokio::time::timeout(timeout, client.connect(target)).await;

        match attempt {
            Err(_elapsed) => Err(TorFailure::timeout(format!("probe exceeded {timeout:?}"))),
            // arti's `Display` embeds the destination; its kind does not.
            Ok(Err(e)) => Err(TorFailure::connect(format!("probe failed: {}", e.kind()))),
            Ok(Ok(stream)) => {
                drop(stream);
                Ok(started.elapsed().as_millis().min(u128::from(u32::MAX)) as u32)
            }
        }
    }

    /// Whether the SOCKS accept loop is still running.
    ///
    /// It can die on its own — a listener error ends it — after which every
    /// connection to [`TorService::socks_port`] is refused. Without this, the
    /// app would see unexplained transport failures and blame the
    /// network. Cheap enough to check before handing the port out.
    pub fn proxy_is_alive(&self) -> bool {
        !*self.shutdown.borrow() && self.default_session.proxy_is_alive()
    }

    /// Put background activity to sleep, or wake it up.
    pub fn set_dormant(&self, dormant: bool) {
        use arti_client::DormantMode;
        if let Some(client) = self.client() {
            client.set_dormant(if dormant {
                DormantMode::Soft
            } else {
                DormantMode::Normal
            });
        }
    }

    /// Stop the proxy listener, bootstrap, and status-forwarding tasks.
    ///
    /// Safe to call more than once. Keeping this as `&self` is required by the
    /// FFI boundary: a status-stream task may briefly hold another opaque
    /// reference, so consuming `self` could panic while decoding the call.
    pub async fn stop(&self) {
        self.shutdown.send_replace(true);
        let sessions = self.begin_stop();
        for session in sessions {
            session.stop().await;
        }
        self.client
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
    }

    /// A poisoned lock is recovered rather than propagated.
    ///
    /// Every guard here only swaps an `Option` or a `Vec`, so a panic while one
    /// is held cannot leave a torn value. Propagating the poison would instead
    /// turn one unrelated panic into a permanent failure of every later Tor
    /// call — and, because the release profile sets `panic = "abort"`, into a
    /// process abort of the wallet rather than a Dart exception.
    fn client(&self) -> Option<Arc<TorClient<TokioNativeTlsRuntime>>> {
        self.client
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .clone()
    }

    fn begin_stop(&self) -> Vec<Arc<TorSessionInner>> {
        let mut registry = self
            .sessions
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        registry.stopping = true;
        registry
            .sessions
            .drain(..)
            .filter_map(|session| session.upgrade())
            .collect()
    }
}

/// The Snowflake bridge lines Tor Browser ships, copied verbatim from
/// `projects/tor-expert-bundle/pt_config.json` in `tpo/applications/
/// tor-browser-build` (re-checked 2026-10-07; last changed upstream by
/// 01d3e9d3 on 2026-04-09).
///
/// Hardcoded rather than fetched: a censored client cannot reach Moat to ask
/// for them. That makes them a maintenance liability, so keep them literal and
/// re-copy the whole line when upstream changes rather than editing fields —
/// the two identities are the only thing that has stayed stable.
///
/// Both entries are the *same* broker reached through two rendezvous
/// identities; the `192.0.2.x` addresses are RFC 5737 placeholders, since a
/// Snowflake client never dials the bridge directly.
const SNOWFLAKE_BRIDGES: [&str; 2] = [
    "Bridge snowflake 192.0.2.3:80 2B280B23E1107BB62ABFC40DDCC8824814F80A72 fingerprint=2B280B23E1107BB62ABFC40DDCC8824814F80A72 url=https://1098762253.rsc.cdn77.org/ fronts=app.datapacket.com,www.datapacket.com ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.mixvoip.com:3478,stun:stun.telnyx.com:3478,stun:stun.hot-chilli.net:3478,stun:stun.fitauto.ru:3478,stun:stun.m-online.net:3478 utls-imitate=hellorandomizedalpn",
    "Bridge snowflake 192.0.2.4:80 8838024498816A039FCBBAB14E6F40A0843051FA fingerprint=8838024498816A039FCBBAB14E6F40A0843051FA url=https://1098762253.rsc.cdn77.org/ fronts=app.datapacket.com,www.datapacket.com ice=stun:stun.epygi.com:3478,stun:stun.uls.co.za:3478,stun:stun.voipgate.com:3478,stun:stun.mixvoip.com:3478,stun:stun.telnyx.com:3478,stun:stun.hot-chilli.net:3478,stun:stun.fitauto.ru:3478,stun:stun.m-online.net:3478 utls-imitate=hellorandomizedalpn",
];

/// Configure the unmanaged IPtProxy listener and the Snowflake bridges.
fn configure_snowflake(cfg: &mut TorClientConfigBuilder, port: u16) -> TorResult<()> {
    for line in SNOWFLAKE_BRIDGES {
        let bridge = line
            .parse::<BridgeConfigBuilder>()
            .map_err(|e| TorFailure::configuration(format!("invalid Snowflake bridge: {e}")))?;
        cfg.bridges().bridges().push(bridge);
    }

    let mut unmanaged = TransportConfigBuilder::default();
    unmanaged
        .protocols(vec!["snowflake".parse().map_err(|e| {
            TorFailure::configuration(format!("invalid Snowflake protocol: {e}"))
        })?])
        .proxy_addr(SocketAddr::from((Ipv4Addr::LOCALHOST, port)));
    cfg.bridges().transports().push(unmanaged);
    Ok(())
}

impl Drop for TorService {
    fn drop(&mut self) {
        // `JoinHandle::drop` detaches the task. Abort explicitly so losing the
        // Dart opaque handle cannot leave a listener and Tor client behind.
        self.shutdown.send_replace(true);
        let registry = self
            .sessions
            .get_mut()
            .unwrap_or_else(|poisoned| poisoned.into_inner());
        registry.stopping = true;
        for session in registry
            .sessions
            .drain(..)
            .filter_map(|session| session.upgrade())
        {
            session.abort();
        }
        self.client
            .get_mut()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
            .take();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Everything up to (not including) bootstrap must work with no network:
    /// the port is known and the status is a well-formed "not ready".
    #[tokio::test]
    async fn start_binds_without_network_and_reports_a_port() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/state"),
            &format!("{dir}/cache"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start must not require the network");

        assert_ne!(svc.socks_port(), 0);
        assert!(
            svc.proxy_is_alive(),
            "accept loop must be running after start"
        );

        let st = svc.status();
        assert!(!st.ready_for_traffic, "cannot be ready before bootstrap");
        assert!(!st.suggests_censorship(), "no blockage diagnosed yet");

        svc.stop().await;
    }

    #[tokio::test]
    async fn two_services_get_distinct_ports() {
        let d1 = tempdir();
        let d2 = tempdir();
        let a = TorService::start(&format!("{d1}/s"), &format!("{d1}/c"), 0, SocksPolicy::Any)
            .await
            .expect("start a");
        let b = TorService::start(&format!("{d2}/s"), &format!("{d2}/c"), 0, SocksPolicy::Any)
            .await
            .expect("start b");

        assert_ne!(a.socks_port(), b.socks_port());

        a.stop().await;
        b.stop().await;
    }

    #[tokio::test]
    async fn default_proxy_uses_an_isolated_client() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/s"),
            &format!("{dir}/c"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start");
        let root = svc.client().expect("root client");
        let default = svc.default_session.client().expect("default client");

        assert!(
            !Arc::ptr_eq(&root, &default),
            "the default proxy must not use the root client's isolation token"
        );
        svc.stop().await;
    }

    #[tokio::test]
    async fn sessions_use_distinct_clients_and_ports() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/s"),
            &format!("{dir}/c"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start");
        let first = svc
            .open_session(0, SocksPolicy::Any)
            .await
            .expect("first session");
        let second = svc
            .open_session(0, SocksPolicy::Any)
            .await
            .expect("second session");
        let first_client = first.client().expect("first client");
        let second_client = second.client().expect("second client");

        assert_ne!(first.socks_port(), second.socks_port());
        assert!(!Arc::ptr_eq(&first_client, &second_client));
        assert!(first.proxy_is_alive());
        assert!(second.proxy_is_alive());

        svc.stop().await;
    }

    #[tokio::test]
    async fn stopping_one_session_leaves_other_sessions_running() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/s"),
            &format!("{dir}/c"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start");
        let first = svc
            .open_session(0, SocksPolicy::Any)
            .await
            .expect("first session");
        let second = svc
            .open_session(0, SocksPolicy::Any)
            .await
            .expect("second session");

        first.stop().await;

        assert!(!first.proxy_is_alive());
        assert!(second.proxy_is_alive());
        assert!(svc.proxy_is_alive());
        svc.stop().await;
    }

    #[tokio::test]
    async fn stopping_service_stops_every_session_and_rejects_new_ones() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/s"),
            &format!("{dir}/c"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start");
        let session = svc
            .open_session(0, SocksPolicy::Any)
            .await
            .expect("session");

        svc.stop().await;

        assert!(!session.proxy_is_alive());
        let result = svc.open_session(0, SocksPolicy::Any).await;
        assert!(
            matches!(
                result,
                Err(TorFailure {
                    kind: super::super::error::TorFailureKind::NotRunning,
                    ..
                })
            ),
            "opening a session after stop must fail as not-running"
        );
    }

    #[tokio::test]
    async fn snowflake_service_reports_its_configured_transport() {
        let dir = tempdir();
        let svc = TorService::start_with_snowflake(
            &format!("{dir}/state"),
            &format!("{dir}/cache"),
            0,
            49152,
            SocksPolicy::Any,
        )
        .await
        .expect("start must not contact Snowflake before bootstrap");

        assert_eq!(svc.status().transport, TorTransport::Snowflake);
        svc.stop().await;
    }

    /// The bridge lines are copied from Tor Browser and cannot be fetched at
    /// runtime by a censored client, so a transcription slip would only surface
    /// as "Snowflake never connects" for the users who need it most.
    #[test]
    fn snowflake_bridge_lines_parse_and_keep_their_identities() {
        let identities = [
            "2B280B23E1107BB62ABFC40DDCC8824814F80A72",
            "8838024498816A039FCBBAB14E6F40A0843051FA",
        ];
        for (line, identity) in SNOWFLAKE_BRIDGES.iter().zip(identities) {
            line.parse::<BridgeConfigBuilder>()
                .unwrap_or_else(|e| panic!("bridge line must parse: {e}"));
            assert!(line.contains(identity), "bridge identity must be preserved");
            assert!(
                line.contains("fingerprint=") && line.contains("utls-imitate="),
                "bridge line must keep its rendezvous parameters"
            );
        }
    }

    /// Upstream replaced Fastly + the AMP cache with a CDN77 broker and the
    /// plural `fronts=` in 2025. Reintroducing any of the retired parameters
    /// would silently point the client at a decommissioned rendezvous.
    #[test]
    fn snowflake_bridge_lines_use_no_retired_rendezvous() {
        for line in SNOWFLAKE_BRIDGES {
            assert!(line.contains("fronts="), "must use the plural `fronts=`");
            assert!(!line.contains("ampcache="), "the AMP cache was retired");
            assert!(
                !line.contains("front="),
                "`front=` was replaced by `fronts=`"
            );
            assert!(
                !line.contains("fastly"),
                "the Fastly broker front was retired"
            );
        }
    }

    #[tokio::test]
    async fn snowflake_rejects_a_zero_proxy_port() {
        let dir = tempdir();
        let result = TorService::start_with_snowflake(
            &format!("{dir}/state"),
            &format!("{dir}/cache"),
            0,
            0,
            SocksPolicy::Any,
        )
        .await;
        let Err(err) = result else {
            panic!("port zero cannot identify the native listener");
        };

        assert_eq!(err.kind, super::super::error::TorFailureKind::Configuration);
    }

    #[tokio::test]
    async fn probe_before_bootstrap_times_out_rather_than_hanging() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/s"),
            &format!("{dir}/c"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start");

        let err = svc
            .probe("example.com", 80, 300)
            .await
            .expect_err("must not succeed without bootstrap");

        // Either shape is acceptable; what matters is that it returns.
        assert!(matches!(
            err.kind,
            super::super::error::TorFailureKind::Timeout
                | super::super::error::TorFailureKind::Connect
        ));

        svc.stop().await;
    }

    #[tokio::test]
    async fn stop_cancels_bootstrap_and_is_idempotent() {
        let dir = tempdir();
        let svc = Arc::new(
            TorService::start(
                &format!("{dir}/s"),
                &format!("{dir}/c"),
                0,
                SocksPolicy::Any,
            )
            .await
            .expect("start"),
        );
        let worker = Arc::clone(&svc);
        let bootstrap = tokio::spawn(async move { worker.bootstrap().await });

        tokio::task::yield_now().await;
        svc.stop().await;
        svc.stop().await;

        let result = tokio::time::timeout(Duration::from_secs(1), bootstrap)
            .await
            .expect("bootstrap cancellation must not hang")
            .expect("bootstrap task must not panic");
        let failure = result.expect_err("stopped bootstrap must fail");
        assert_eq!(
            failure.kind,
            super::super::error::TorFailureKind::NotRunning
        );
        assert!(!svc.proxy_is_alive());
    }

    #[tokio::test]
    async fn bootstrap_with_timeout_reports_an_elapsed_deadline_as_timeout() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/s"),
            &format!("{dir}/c"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start");

        let failure = svc
            .bootstrap_with_timeout(Some(1))
            .await
            .expect_err("bootstrap cannot finish within 1 ms");
        assert_eq!(failure.kind, super::super::error::TorFailureKind::Timeout);

        svc.stop().await;
    }

    #[tokio::test]
    async fn stop_cancels_a_bootstrap_without_deadline() {
        let dir = tempdir();
        let svc = Arc::new(
            TorService::start(
                &format!("{dir}/s"),
                &format!("{dir}/c"),
                0,
                SocksPolicy::Any,
            )
            .await
            .expect("start"),
        );
        let worker = Arc::clone(&svc);
        let bootstrap = tokio::spawn(async move { worker.bootstrap_with_timeout(None).await });

        tokio::task::yield_now().await;
        svc.stop().await;

        let result = tokio::time::timeout(Duration::from_secs(1), bootstrap)
            .await
            .expect("bootstrap cancellation must not hang")
            .expect("bootstrap task must not panic");
        let failure = result.expect_err("stopped bootstrap must fail");
        assert_eq!(
            failure.kind,
            super::super::error::TorFailureKind::NotRunning
        );
    }

    #[tokio::test]
    async fn stop_releases_state_for_an_immediate_restart() {
        let dir = tempdir();
        let state = format!("{dir}/state");
        let cache = format!("{dir}/cache");
        let first = TorService::start(&state, &cache, 0, SocksPolicy::Any)
            .await
            .expect("start first");

        first.stop().await;

        let second = TorService::start(&state, &cache, 0, SocksPolicy::Any)
            .await
            .expect("restart with the same state directory");
        second.stop().await;
    }

    #[tokio::test]
    async fn dropping_service_closes_the_proxy_listener() {
        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/state"),
            &format!("{dir}/cache"),
            0,
            SocksPolicy::Any,
        )
        .await
        .expect("start");
        let port = svc.socks_port();

        drop(svc);

        tokio::time::timeout(Duration::from_secs(1), async {
            loop {
                if tokio::net::TcpStream::connect(("127.0.0.1", port))
                    .await
                    .is_err()
                {
                    break;
                }
                tokio::task::yield_now().await;
            }
        })
        .await
        .expect("proxy listener must close when the service is dropped");
    }

    #[tokio::test]
    /// The refusal is a property of `OnionOnly`, not of the proxy: with the
    /// library default (`Any`) the same request is relayed to Tor instead.
    async fn the_onion_only_policy_refuses_clearnet_at_the_socks_layer() {
        use tokio::io::{AsyncReadExt as _, AsyncWriteExt as _};

        let dir = tempdir();
        let svc = TorService::start(
            &format!("{dir}/state"),
            &format!("{dir}/cache"),
            0,
            SocksPolicy::OnionOnly,
        )
        .await
        .expect("start");
        let mut sock = tokio::net::TcpStream::connect(("127.0.0.1", svc.socks_port()))
            .await
            .expect("connect to proxy");

        sock.write_all(&[0x05, 0x01, 0x00]).await.expect("greeting");
        let mut greeting = [0u8; 2];
        sock.read_exact(&mut greeting)
            .await
            .expect("greeting reply");
        assert_eq!(greeting, [0x05, 0x00]);

        let host = b"example.com";
        let mut request = vec![0x05, 0x01, 0x00, 0x03, host.len() as u8];
        request.extend_from_slice(host);
        request.extend_from_slice(&80u16.to_be_bytes());
        sock.write_all(&request).await.expect("connect request");

        let mut reply = [0u8; 4];
        sock.read_exact(&mut reply).await.expect("connect reply");
        assert_eq!(reply[0], 0x05);
        assert_eq!(reply[1], 0x02, "clearnet must be rejected as not allowed");

        svc.stop().await;
    }

    /// Unique scratch directory per test, cleaned up by the OS.
    fn tempdir() -> String {
        use std::sync::atomic::{AtomicU32, Ordering};
        static N: AtomicU32 = AtomicU32::new(0);
        let n = N.fetch_add(1, Ordering::Relaxed);
        let p = std::env::temp_dir().join(format!("onion_test_{}_{}", std::process::id(), n));
        std::fs::create_dir_all(&p).expect("mkdir");
        p.to_string_lossy().into_owned()
    }
}
