use std::io::{Read, Write};
use std::net::TcpListener;
use std::thread;
use std::time::{Duration, Instant};

use bark::WalletSeed;
use bitcoin::{Network, blockdata::constants::genesis_block};
use rust_lib_scuttle::api::wallet::{OpenMode, ScuttleNetwork, ScuttleWallet};

#[tokio::test]
async fn bridge_closes_and_reopens_existing_wallet() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().to_str().unwrap().to_owned();
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
                .set_write_timeout(Some(Duration::from_secs(2)))
                .unwrap();
            let read_deadline = Instant::now() + Duration::from_secs(2);
            let mut request = Vec::new();
            let mut buffer = [0; 512];
            while !request.ends_with(b"\r\n\r\n") {
                let remaining = read_deadline.saturating_duration_since(Instant::now());
                assert!(!remaining.is_zero(), "timed out reading HTTP headers");
                stream.set_read_timeout(Some(remaining)).unwrap();
                let size = stream.read(&mut buffer).unwrap();
                assert!(size > 0);
                request.extend_from_slice(&buffer[..size]);
                assert!(request.len() <= 8192);
            }
            assert!(request.starts_with(b"GET /block-height/0 "));
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
        assert_eq!(served, 2);
    });
    let open = |mode| {
        ScuttleWallet::open(
            ScuttleNetwork::Regtest,
            mode,
            path.clone(),
            "http://127.0.0.1:1".into(),
            format!("http://{address}"),
            vec![0; 64],
            true,
        )
    };
    let missing = match open(OpenMode::Existing).await {
        Ok(_) => panic!("unexpectedly opened a missing wallet"),
        Err(error) => error,
    };
    assert_eq!(missing, "Wallet data not found");
    assert!(!dir.path().join("db.sqlite").exists());
    let wallet = open(OpenMode::New).await.unwrap();
    assert!(wallet.confirmed_reserve().await.unwrap().is_empty());
    let first_reserve_address = wallet.reserve_address().await.unwrap();
    let review = wallet.exit_progress_review(2).await.unwrap();
    assert!(review.active_exits.is_empty());
    assert!(matches!(
        wallet.progress_exits(review).await,
        Err(error) if error == "Stale exit review"
    ));
    let expected = WalletSeed::new_from_seed(Network::Regtest, &[0; 64])
        .fingerprint()
        .to_string();
    assert_eq!(wallet.fingerprint().await.unwrap(), expected);
    let locked = match open(OpenMode::Existing).await {
        Ok(_) => panic!("unexpectedly opened a locked wallet"),
        Err(error) => error,
    };
    assert_eq!(locked, "Cannot lock wallet directory");
    {
        let (read, close) = tokio::join!(wallet.fingerprint(), wallet.close());
        close.unwrap();
        match read {
            Ok(value) => assert_eq!(value, expected),
            Err(error) => assert_eq!(error, "Wallet closed"),
        }
    }
    assert_eq!(wallet.fingerprint().await.unwrap_err(), "Wallet closed");
    wallet.close().await.unwrap();
    let duplicate = match open(OpenMode::New).await {
        Ok(_) => panic!("unexpectedly opened existing data as new"),
        Err(error) => error,
    };
    assert_eq!(duplicate, "Wallet data already exists");
    let wrong_network = ScuttleWallet::open(
        ScuttleNetwork::Testnet,
        OpenMode::Existing,
        path.clone(),
        "http://127.0.0.1:1".into(),
        format!("http://{address}"),
        vec![0; 64],
        true,
    )
    .await;
    assert!(matches!(wrong_network, Err(error) if error == "Cannot open wallet"));
    let reopened = open(OpenMode::Existing).await.unwrap();
    assert_eq!(reopened.fingerprint().await.unwrap(), expected);
    assert!(reopened.confirmed_reserve().await.unwrap().is_empty());
    assert_ne!(
        reopened.reserve_address().await.unwrap(),
        first_reserve_address
    );
    reopened.close().await.unwrap();
    server.join().unwrap();
}
