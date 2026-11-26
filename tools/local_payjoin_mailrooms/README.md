# Local Payjoin mailrooms

This fixture runs two BIP77 mailrooms in a disposable network namespace. They are operated together for integration testing and do not provide production OHTTP operator separation.

Build before entering the isolated network, using the project's Rust toolchain:

```sh
cargo build --locked --manifest-path tools/local_payjoin_mailrooms/Cargo.toml
tools/local_payjoin_mailrooms/build-peer.sh /absolute/temporary/peer
```

Set `BULL_PAYJOIN_MAILROOMS` to the built `bull-regtest-mailrooms` executable and `BULL_PAYJOIN_TEST_PEER` to `/absolute/temporary/peer/bin/payjoin-cli`. With dependencies, the Linux app and the three pinned container images prepared, run `tools/local_payjoin_integration.sh` from the repository root. Both Rust binaries and the images must be available before the isolated runner starts; it does not pull images.

Mount a freshly generated certificate and private key at `/data/cert.pem`, `/data/cert.der` and `/data/key.pem` when starting the binary. The certificate must cover both `localhost` and `127.0.0.1` and have the critical constraint `CA:FALSE`. The fixture listens on ports 8040 and 8041 and stores ephemeral mailboxes under `/data`; use a fresh directory and remove it after every run. Supply the DER certificate and its SHA-256 digest to the app as `BULL_PAYJOIN_CERT_DER_BASE64` and `BULL_PAYJOIN_CERT_SHA256`. Wait for both HTTPS `/health` endpoints before starting the test.

The runner must use an isolated network with no external access and must remove the processes and temporary data after success or failure. Do not use these fixture certificates, services or storage in production.
