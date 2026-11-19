//! Regtest integration tests for scan_once() and stop_scan().
//! Requires: SP_NETWORK_TESTS=1 and a live minta.pythcoiner.dev regtest instance.

fn should_run() -> bool {
    std::env::var("SP_NETWORK_TESTS").as_deref() == Ok("1")
}

const TEST_MNEMONIC: &str =
    "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about";
const MINTA_BASE: &str = "http://minta.pythcoiner.dev";

#[test]
#[ignore] // run with: SP_NETWORK_TESTS=1 cargo test -- --ignored
fn scan_once_receives_payment() {
    if !should_run() {
        eprintln!("[skip] set SP_NETWORK_TESTS=1 to run regtest integration tests");
        return;
    }

    let defaults = dart_bwk::api::regtest::get_regtest_defaults();
    assert!(defaults.is_ok, "minta unreachable: {}", defaults.error);

    let dir = tempfile::tempdir().unwrap();
    let account = dart_bwk::api::sp_account::SpAccount::create_from_mnemonic(
        "test-scan".to_string(),
        dart_bwk::api::types::SpNetwork::Regtest,
        TEST_MNEMONIC.to_string(),
        defaults.blindbit_url.clone(),
        defaults.electrum_url.clone(),
        dir.path().to_str().unwrap().to_string(),
        None,
        None,
        None,
    )
    .expect("create account");

    let sp_address = account.sp_address().expect("sp_address");
    assert!(!sp_address.is_empty());

    let client = reqwest::blocking::Client::new();

    // Poke minta faucet to send regtest coins to the SP address.
    let faucet_resp = client
        .post(format!("{MINTA_BASE}/api/faucet/sp"))
        .json(&serde_json::json!({ "address": sp_address, "amount": 10_000 }))
        .send()
        .expect("faucet request");
    assert!(
        faucet_resp.status().is_success(),
        "faucet failed: {}",
        faucet_resp.status()
    );

    // Mine one block so the payment is confirmed.
    let mine_resp = client
        .post(format!("{MINTA_BASE}/api/mine"))
        .json(&serde_json::json!({ "blocks": 1 }))
        .send()
        .expect("mine request");
    assert!(
        mine_resp.status().is_success(),
        "mine failed: {}",
        mine_resp.status()
    );

    // OneShot scan is synchronous: scan_once() blocks until the scan completes.
    assert!(
        !account.is_scanning().expect("is_scanning"),
        "not scanning before scan_once"
    );
    account.scan_once(None).expect("scan_once failed");
    assert!(
        !account.is_scanning().expect("is_scanning"),
        "not scanning after oneshot completes"
    );

    assert!(
        account.confirmed_balance().expect("confirmed_balance") > 0,
        "expected confirmed balance > 0 after scan, got 0"
    );
    assert!(
        account
            .last_scanned_height()
            .expect("last_scanned_height")
            .unwrap_or(0)
            > 0,
        "expected last_scanned_height > 0 after scan"
    );
}

#[test]
#[ignore] // run with: SP_NETWORK_TESTS=1 cargo test -- --ignored
fn stop_scan_no_panic() {
    if !should_run() {
        return;
    }

    let defaults = dart_bwk::api::regtest::get_regtest_defaults();
    assert!(defaults.is_ok, "minta unreachable: {}", defaults.error);

    let dir = tempfile::tempdir().unwrap();
    let account = dart_bwk::api::sp_account::SpAccount::create_from_mnemonic(
        "test-stop".to_string(),
        dart_bwk::api::types::SpNetwork::Regtest,
        TEST_MNEMONIC.to_string(),
        defaults.blindbit_url,
        defaults.electrum_url,
        dir.path().to_str().unwrap().to_string(),
        None,
        None,
        None,
    )
    .expect("create account");

    // stop_scan() is a no-op when no scan is running; must not panic.
    // It's async (flips an atomic cancel flag without touching the
    // inner mutex), so block on the future to drive it to completion.
    block_on(account.stop_scan()).expect("stop_scan");
    assert!(!account.is_scanning().expect("is_scanning"));
}

/// Minimal noop-waker block_on for the few async helpers exercised by the
/// regtest harness. We don't pull tokio into the test crate just for this.
fn block_on<F: std::future::Future>(mut fut: F) -> F::Output {
    use std::pin::Pin;
    use std::task::{Context, Poll, RawWaker, RawWakerVTable, Waker};
    fn clone(_: *const ()) -> RawWaker {
        RawWaker::new(std::ptr::null(), &VTABLE)
    }
    fn noop(_: *const ()) {}
    static VTABLE: RawWakerVTable = RawWakerVTable::new(clone, noop, noop, noop);
    let raw = RawWaker::new(std::ptr::null(), &VTABLE);
    // SAFETY: vtable is all no-ops; data pointer never dereferenced.
    let waker = unsafe { Waker::from_raw(raw) };
    let mut cx = Context::from_waker(&waker);
    // SAFETY: fut owned by this function, not moved across polls.
    let mut fut = unsafe { Pin::new_unchecked(&mut fut) };
    loop {
        match fut.as_mut().poll(&mut cx) {
            Poll::Ready(v) => return v,
            Poll::Pending => std::thread::sleep(std::time::Duration::from_millis(1)),
        }
    }
}

#[test]
#[ignore] // run with: SP_NETWORK_TESTS=1 cargo test -- --ignored
fn electrum_tx_push_no_scan_once() {
    if !should_run() {
        eprintln!("[skip] set SP_NETWORK_TESTS=1 to run regtest integration tests");
        return;
    }

    let defaults = dart_bwk::api::regtest::get_regtest_defaults();
    assert!(defaults.is_ok, "minta unreachable: {}", defaults.error);

    let dir = tempfile::tempdir().unwrap();

    let account = dart_bwk::api::sp_account::SpAccount::create_from_mnemonic(
        "test-electrum-push".to_string(),
        dart_bwk::api::types::SpNetwork::Regtest,
        TEST_MNEMONIC.to_string(),
        defaults.blindbit_url.clone(),
        defaults.electrum_url.clone(),
        dir.path().to_str().unwrap().to_string(),
        None,
        None,
        None,
    )
    .expect("create account with sub-accounts");

    let recv_addr = account
        .new_taproot_address()
        .expect("reveal taproot receive address");
    assert!(!recv_addr.is_empty(), "taproot address must not be empty");

    // NOTE: We cannot inject a real StreamSink in a unit test (requires FRB runtime),
    // so the ElectrumTx event is not observed here. We poll unified_balance as a
    // proxy, waiting up to 30 s for the sub-account to receive coins.

    let client = reqwest::blocking::Client::new();

    // Send regtest coins to the taproot sub-account address.
    let faucet_resp = client
        .post(format!("{MINTA_BASE}/api/faucet/address"))
        .json(&serde_json::json!({ "address": recv_addr, "amount": 10_000 }))
        .send()
        .expect("faucet request");
    assert!(
        faucet_resp.status().is_success(),
        "faucet failed: {}",
        faucet_resp.status()
    );

    // Mine a block to confirm the tx.
    let mine_resp = client
        .post(format!("{MINTA_BASE}/api/mine"))
        .json(&serde_json::json!({ "blocks": 1 }))
        .send()
        .expect("mine request");
    assert!(
        mine_resp.status().is_success(),
        "mine failed: {}",
        mine_resp.status()
    );

    // Poll unified_balance (no scan_once call!) until it shows > 0 or 30s pass.
    let deadline = std::time::Instant::now() + std::time::Duration::from_secs(30);
    loop {
        let bal = account.unified_balance().expect("unified_balance");
        if bal.total_unified_sat > 0 {
            // Also verify the coin list.
            assert!(
                account
                    .unified_coins()
                    .expect("unified_coins")
                    .iter()
                    .any(|c| matches!(c.source, dart_bwk::api::types::CoinSource::Taproot)),
                "unified_coins must contain a Taproot entry"
            );
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "timeout: unified_balance still 0 after 30 s (no scan_once called)"
        );
        std::thread::sleep(std::time::Duration::from_millis(500));
    }
}
