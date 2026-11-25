use std::io::{Read, Write};
use std::net::TcpListener;
use std::thread;
use std::time::{Duration, Instant};

use bark::lock_manager::PidLockError;
use bark::{Config, OpenWalletArgs, Wallet, WalletSeed};
use bitcoin::{Network, blockdata::constants::genesis_block};

#[tokio::test]
async fn opens_closes_and_reopens_with_datadir_lock() {
    let datadir = tempfile::tempdir().unwrap();
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    listener.set_nonblocking(true).unwrap();
    let server = thread::spawn(move || {
        let deadline = Instant::now() + Duration::from_secs(30);
        let mut served = 0;
        while served < 2 && Instant::now() < deadline {
            let (mut stream, _) = match listener.accept() {
                Ok(connection) => connection,
                Err(error) if error.kind() == std::io::ErrorKind::WouldBlock => {
                    thread::sleep(Duration::from_millis(10));
                    continue;
                }
                Err(error) => panic!("accept failed: {error}"),
            };
            stream
                .set_read_timeout(Some(Duration::from_secs(2)))
                .unwrap();
            stream
                .set_write_timeout(Some(Duration::from_secs(2)))
                .unwrap();
            let mut request = Vec::new();
            let mut buffer = [0; 512];
            let read_deadline = Instant::now() + Duration::from_secs(2);
            while !request.ends_with(b"\r\n\r\n") {
                let remaining = read_deadline.saturating_duration_since(Instant::now());
                assert!(!remaining.is_zero(), "timed out reading HTTP headers");
                stream.set_read_timeout(Some(remaining)).unwrap();
                let size = stream.read(&mut buffer).unwrap();
                assert!(size > 0, "connection closed before HTTP headers");
                request.extend_from_slice(&buffer[..size]);
                assert!(request.len() <= 8192, "HTTP headers too large");
            }
            assert!(
                std::str::from_utf8(&request)
                    .unwrap()
                    .starts_with("GET /block-height/0 ")
            );
            let body = genesis_block(Network::Regtest).block_hash().to_string();
            write!(
                stream,
                "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
                body.len(),
                body
            )
            .unwrap();
            served += 1;
        }
        assert_eq!(served, 2, "timed out waiting for genesis requests");
    });

    // Public deterministic test fixture, not a funded or production seed.
    let seed = || WalletSeed::new_from_seed(Network::Regtest, &[0; 64]);
    let fingerprint = seed().fingerprint();
    let config = Config {
        server_address: "http://127.0.0.1:1".into(),
        esplora_address: Some(format!("http://{address}")),
        ..Config::network_default(Network::Regtest)
    };
    let args = || OpenWalletArgs {
        datadir: Some(datadir.path().to_owned()),
        run_daemon: false,
        create_without_server: true,
        skip_recovery: true,
        ..Default::default()
    };

    let wallet = Wallet::open(Network::Regtest, seed(), config.clone(), args())
        .await
        .unwrap();
    assert_eq!(wallet.fingerprint(), fingerprint);
    let error = match Wallet::open(Network::Regtest, seed(), config.clone(), args()).await {
        Ok(_) => panic!("a second open unexpectedly succeeded"),
        Err(error) => error,
    };
    assert!(
        error.chain().any(|cause| matches!(
            cause.downcast_ref::<PidLockError>(),
            Some(PidLockError::AlreadyHeld { .. })
        )),
        "unexpected error: {error:#}"
    );
    drop(wallet);
    let reopened = Wallet::open(
        Network::Regtest,
        seed(),
        config,
        OpenWalletArgs {
            create_if_not_exists: false,
            ..args()
        },
    )
    .await
    .unwrap();
    assert_eq!(reopened.fingerprint(), fingerprint);
    drop(reopened);
    server.join().unwrap();
}
