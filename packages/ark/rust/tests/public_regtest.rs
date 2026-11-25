//! Opt-in public regtest smoke, not a funded or end-to-end test.
//!
//! Run only with `SCUTTLE_PUBLIC_REGTEST=1` and `cargo test --test
//! public_regtest -- --ignored`. The endpoints are deliberately fixed.

use std::io::Read;
use std::str::FromStr;
use std::time::Duration;

use bark::payment_request::ArkAddressType;
use rust_lib_scuttle::api::wallet::{OpenMode, ScuttleNetwork, ScuttleWallet};
use zeroize::Zeroizing;

const ARK: &str = "https://scuttle-regtest-ark.vibecode.casa";
const ESPLORA: &str = "https://scuttle-regtest-esplora.vibecode.casa";

#[tokio::test]
#[ignore = "contacts the public regtest services; requires SCUTTLE_PUBLIC_REGTEST=1"]
async fn bridge_opens_and_derives_mailbox_address() {
    assert_eq!(
        std::env::var("SCUTTLE_PUBLIC_REGTEST").as_deref(),
        Ok("1"),
        "explicit opt-in required"
    );
    let dir = tempfile::tempdir().expect("temporary directory");
    let mut seed = Zeroizing::new(vec![0u8; 64]);
    std::fs::File::open("/dev/urandom")
        .and_then(|mut f| f.read_exact(&mut seed))
        .expect("OS randomness unavailable");

    tokio::time::timeout(Duration::from_secs(45), async {
        // The pinned wallet checks Esplora's height-zero hash against the
        // Bitcoin regtest genesis during open. A reachable Ark is mandatory.
        let wallet = ScuttleWallet::open(
            ScuttleNetwork::Regtest,
            OpenMode::New,
            dir.path().to_str().expect("UTF-8 temporary path").into(),
            ARK.into(),
            ESPLORA.into(),
            seed.to_vec(),
            false,
        )
        .await
        .expect("bridge open failed");
        let address = wallet
            .new_ark_address()
            .await
            .expect("address creation failed");
        let parsed = ArkAddressType::from_str(&address).expect("invalid Ark address");
        match parsed {
            ArkAddressType::Bark(address) => {
                assert!(address.is_testnet(), "address is not for a test network");
                assert!(
                    address
                        .delivery()
                        .iter()
                        .any(|delivery| !delivery.is_unknown()),
                    "address has no server mailbox"
                );
            }
            ArkAddressType::Arkade(_) => panic!("unexpected address format"),
        }
        wallet.close().await.expect("bridge close failed");
    })
    .await
    .expect("public regtest smoke timed out");
}
