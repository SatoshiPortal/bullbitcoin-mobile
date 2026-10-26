# Bull Tor

Bull Mobile's Tor infrastructure publishes feature-facing operations through `tor.dart` and shell composition through `tor_adapter.dart`. The package owns the embedded Onion/Arti adapter and the independent external SOCKS verification path.

## Native support diagnostics

The foreground shell opts into native diagnostics with `TorLocator.registerDatasources(captureNativeLogs: true)`. Capture begins before the first embedded service starts and stays attached across service retries until the backend closes. Background composition passes `captureNativeTorLogs: false` to `AppLocator.setup`, preserving the foreground engine's process-wide native capture.

Native Error and Warn records route to `TorLogger.warning`. Info records from `onion`, `tor_hsclient` and `tor_circmgr`, including their Rust module descendants, route to `fine`. Other Info records and all Debug records route to the console-only `info` callback. The host supplies those callbacks through `createTorLogger`; none of these routes call `severe`, `shout` or a reporter SDK.

The native queue is bounded by the Onion package. The Dart bridge additionally limits persistent native output to 64 records and 16 KiB per one-minute budget window, with capacity reserved for warnings, plus one short loss/duplicate summary. Adjacent identical records are suppressed. A monotonic elapsed clock renews the budget on the next record; no background timer is installed. These are initial limits to validate against measured bootstrap and key-server traffic, not a promise that every native line is persisted. Other application diagnostics retain their existing logging policy.

Native messages are developer diagnostics, never localized user messages or stable error classifications. Onion applies safe logging and address redaction before crossing FFI; Bull Logger also sanitizes local output. No destination or foreign exception should be added by this adapter. RecoverBull connection decisions continue to use typed state/failures and its explicit retry/session ownership policy.

## Verification

`test/tor_log_bridge_test.dart` checks severity routing, namespace matching, duplicate suppression, warning capacity, UTF-8 byte limits, budget renewal and stream cancellation. The root `test/tor_runtime_adapters_test.dart` checks the actual host callback wiring against on-disk logs and a recording reporter. Run the repository's `make checks` for the full workspace verification.

The companion Onion example includes physical-device plugin checks for FFI redaction, isolated connection history and native Snowflake milestones. End-to-end RecoverBull and live Tor recovery require separate device checks; plugin plumbing alone does not establish connection reliability or latency.

## Startup resource policy

BULL sends only onion destinations through the embedded Tor client. Both direct and Snowflake startup explicitly disable Arti's speculative exit/DNS circuit predictor while retaining the onion-service pool, timeout learning and isolated application sessions. The SDK keeps its default prebuilding for other hosts. Listener destination policy remains `SocksPolicy.onionOnly`; disabling prediction alone does not enforce that policy. The standalone Tor release crate uses throughput optimization (`opt-level=3`), with LTO and stripping; debug builds are unaffected.

Startup checks the latest Arti readiness after the five-second hold and after the asynchronous listener check. A regression waits for fresh readiness within the original bounded startup deadline; repeated readiness changes do not renew it. Stopping cancels both waits. These checks establish current client readiness, not guaranteed reachability of a particular onion service; RecoverBull still validates its own server through its isolated route.
