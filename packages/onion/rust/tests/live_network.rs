//! End-to-end tests that require reaching the real Tor network.
//!
//! Ignored by default so `cargo test` stays hermetic and fast. Run with:
//!
//! ```sh
//! cargo test --test live_network -- --ignored --nocapture
//! ```
//!
//! These are the tests that actually prove the design: that the hand-written
//! SOCKS5 front end speaks the protocol correctly, that the status stream
//! reports progress, and that the probe distinguishes a working Tor from a
//! broken destination.

use std::time::Duration;

use futures::StreamExt as _;
use rust_lib_onion::api::client::TorService;
use rust_lib_onion::api::session::SocksPolicy;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpStream;

fn scratch(tag: &str) -> String {
    let p = std::env::temp_dir().join(format!("onion_live_{}_{}", std::process::id(), tag));
    std::fs::create_dir_all(&p).expect("mkdir");
    p.to_string_lossy().into_owned()
}

/// Bootstrap, then watch the status stream reach `ready_for_traffic`.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "requires the Tor network"]
async fn bootstraps_and_reports_progress() {
    let dir = scratch("boot");
    let svc = TorService::start(
        &format!("{dir}/state"),
        &format!("{dir}/cache"),
        0,
        SocksPolicy::Any,
    )
    .await
    .expect("start");

    let mut events = Box::pin(svc.status_stream());

    let watcher = tokio::spawn(async move {
        let mut last = 0.0f32;
        while let Some(s) = events.next().await {
            assert!(
                !s.stage.is_empty(),
                "a running client must describe its stage"
            );
            if s.fraction > last {
                last = s.fraction;
                eprintln!("  progress {:.0}%: {}", s.fraction * 100.0, s.stage);
            }
            if let Some(b) = &s.blockage {
                eprintln!("  BLOCKED {:?}: {}", b.kind, b.message);
            }
            if s.ready_for_traffic {
                return true;
            }
        }
        false
    });

    svc.bootstrap().await.expect("bootstrap");

    // `bootstrap()` resolving and the watcher observing `ready_for_traffic`
    // are two independent observations of the same fact, and nothing orders
    // them: the watcher is a separate task reading a `postage::watch` channel,
    // which coalesces. Give it a real budget rather than assuming it has
    // already caught up — a 5s window made this test flake.
    let saw_ready = tokio::time::timeout(Duration::from_secs(60), watcher)
        .await
        .expect("watcher did not observe readiness within 60s")
        .expect("watcher panicked");
    assert!(saw_ready, "status stream never reported ready_for_traffic");

    // Read the snapshot only after the stream has confirmed readiness, so this
    // is a check on the final state and not a race against it.
    let st = svc.status();
    assert!(st.ready_for_traffic, "bootstrap returned but not ready");
    assert!(
        st.fraction > 0.99,
        "fraction should be ~1.0, got {}",
        st.fraction
    );
    assert!(
        st.blockage.is_none(),
        "unexpected blockage: {:?}",
        st.blockage
    );

    svc.stop().await;
}

/// The canary: a successful probe means Tor genuinely carries traffic.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "requires the Tor network"]
async fn probe_succeeds_through_tor() {
    let dir = scratch("probe");
    let svc = TorService::start(
        &format!("{dir}/state"),
        &format!("{dir}/cache"),
        0,
        SocksPolicy::Any,
    )
    .await
    .expect("start");
    svc.bootstrap().await.expect("bootstrap");

    let elapsed = svc
        .probe("check.torproject.org", 443, 30_000)
        .await
        .expect("probe must succeed once bootstrapped");
    eprintln!("  probe ok in {elapsed} ms");

    // A destination that cannot exist must fail while Tor itself stays fine.
    let err = svc
        .probe("this-host-does-not-exist.invalid", 443, 30_000)
        .await
        .expect_err("bogus destination must fail");
    eprintln!("  bogus destination rejected: {}", err.kind);

    assert!(
        svc.status().ready_for_traffic,
        "a failed destination must not mark Tor itself unhealthy"
    );

    svc.stop().await;
}

/// Drive a real SOCKS5 CONNECT to Bull Bitcoin's RecoverBull hidden service
/// through our hand-written front end and read a live HTTP response back. This
/// is the test that validates `tor-socksproto` usage end to end.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "requires the Tor network"]
async fn socks5_connect_relays_onion_http() {
    let dir = scratch("socks");
    let svc = TorService::start(
        &format!("{dir}/state"),
        &format!("{dir}/cache"),
        0,
        SocksPolicy::Any,
    )
    .await
    .expect("start");
    svc.bootstrap().await.expect("bootstrap");

    let port = svc.socks_port();
    let mut sock = TcpStream::connect(("127.0.0.1", port))
        .await
        .expect("connect to our socks port");

    // SOCKS5 greeting: version 5, one method, "no authentication".
    sock.write_all(&[0x05, 0x01, 0x00]).await.expect("greeting");
    let mut greet = [0u8; 2];
    sock.read_exact(&mut greet).await.expect("greeting reply");
    assert_eq!(greet, [0x05, 0x00], "expected SOCKS5 / no-auth");

    // CONNECT by hostname, so Tor resolves the hidden service remotely.
    let host = b"5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion";
    let mut req = vec![0x05, 0x01, 0x00, 0x03, host.len() as u8];
    req.extend_from_slice(host);
    req.extend_from_slice(&80u16.to_be_bytes());
    sock.write_all(&req).await.expect("connect request");

    // Reply: VER REP RSV ATYP + addr + port. Bound address is IPv4 in practice.
    let mut head = [0u8; 4];
    sock.read_exact(&mut head)
        .await
        .expect("connect reply head");
    assert_eq!(head[0], 0x05, "reply version");
    assert_eq!(
        head[1], 0x00,
        "reply status must be SUCCEEDED, got {}",
        head[1]
    );
    let addr_len = match head[3] {
        0x01 => 4,
        0x04 => 16,
        0x03 => {
            let mut l = [0u8; 1];
            sock.read_exact(&mut l).await.expect("domain len");
            l[0] as usize
        }
        other => panic!("unexpected ATYP {other}"),
    };
    let mut rest = vec![0u8; addr_len + 2];
    sock.read_exact(&mut rest).await.expect("reply tail");

    // Now the socket is a plain tunnel. Speak HTTP/1.0 over it.
    sock.write_all(
        b"GET / HTTP/1.0\r\nHost: 5m7enm5y77tdgmaf3d5xuwa5c7fjma7v5ljtwxu4q5jtq6b5utspmpyd.onion\r\n\r\n",
    )
        .await
        .expect("http request");

    let mut buf = Vec::new();
    tokio::time::timeout(Duration::from_secs(60), sock.read_to_end(&mut buf))
        .await
        .expect("http read timed out")
        .expect("http read");

    let head = String::from_utf8_lossy(&buf[..buf.len().min(64)]);
    eprintln!("  got {} bytes, starts: {:?}", buf.len(), head.trim());
    assert!(
        head.starts_with("HTTP/1."),
        "expected an HTTP response through the tunnel"
    );

    svc.stop().await;
}

/// Commands we do not serve must terminate promptly rather than hang, and
/// must never be reported as succeeded.
///
/// The two cases behave differently on purpose, and the difference comes from
/// `tor-socksproto`, not from us:
///
/// - `BIND` (0x02) is *unrecognized*: the parser refuses it with
///   `Error::NotImplemented` before a `SocksRequest` exists, so there is
///   nothing to build a reply from and we close the socket. arti's own proxy
///   does the same, on the reasoning that a peer sending garbage probably is
///   not speaking SOCKS at all.
/// - `RESOLVE` (0xF0) *is* recognized — it is a Tor SOCKS extension — so it
///   reaches our command match and gets a proper `COMMAND_NOT_SUPPORTED`.
///   We decline it deliberately: nothing in the app uses it, and a subtly
///   wrong name-resolution path inside an anonymity system is worse than a
///   clean refusal.
#[tokio::test(flavor = "multi_thread")]
#[ignore = "requires the Tor network"]
async fn socks5_declines_commands_we_do_not_serve() {
    let dir = scratch("badcmd");
    let svc = TorService::start(
        &format!("{dir}/state"),
        &format!("{dir}/cache"),
        0,
        SocksPolicy::Any,
    )
    .await
    .expect("start");
    svc.bootstrap().await.expect("bootstrap");
    let port = svc.socks_port();

    async fn greet(port: u16) -> TcpStream {
        let mut sock = TcpStream::connect(("127.0.0.1", port))
            .await
            .expect("connect");
        sock.write_all(&[0x05, 0x01, 0x00]).await.expect("greeting");
        let mut g = [0u8; 2];
        sock.read_exact(&mut g).await.expect("greeting reply");
        assert_eq!(g, [0x05, 0x00]);
        sock
    }

    fn request(cmd: u8) -> Vec<u8> {
        let host = b"example.com";
        let mut r = vec![0x05, cmd, 0x00, 0x03, host.len() as u8];
        r.extend_from_slice(host);
        r.extend_from_slice(&80u16.to_be_bytes());
        r
    }

    // BIND: rejected during parsing, connection closed without a SOCKS reply.
    let mut sock = greet(port).await;
    sock.write_all(&request(0x02)).await.expect("bind request");
    let mut buf = Vec::new();
    let read = tokio::time::timeout(Duration::from_secs(10), sock.read_to_end(&mut buf))
        .await
        .expect("must not hang")
        .expect("read");
    assert_eq!(read, 0, "BIND must be closed, not answered: {buf:?}");

    // RESOLVE: recognized, so we owe the client a real refusal.
    let mut sock = greet(port).await;
    sock.write_all(&request(0xF0))
        .await
        .expect("resolve request");
    let mut head = [0u8; 4];
    tokio::time::timeout(Duration::from_secs(10), sock.read_exact(&mut head))
        .await
        .expect("must reply, not hang")
        .expect("reply");
    assert_eq!(head[0], 0x05, "reply version");
    assert_ne!(head[1], 0x00, "RESOLVE must not be reported as succeeded");

    svc.stop().await;
}
