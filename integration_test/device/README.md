# Notification tests on Android

These standalone suites use synthetic credentials and controlled WebSocket peers. They do not initialize the installed wallet, read its exchange credentials, or spend funds. The root integration-test aggregator intentionally does not include this directory because it uses a different Flutter test binding.

Reserve the device before using ADB. Use the debug beta application so the normal application remains available. Restore the original Wi-Fi, mobile-data, and screen-timeout settings afterward, remove the temporary test application, and verify that the device is locked before releasing it.

The basic suite can drive Flutter lifecycle events itself:

```sh
fvm flutter test --no-pub --flavor beta --device-id DEVICE integration_test/device/exchange_notifications_test.dart --reporter expanded
```

The complete matrix needs a host driving real Android events and a controlled peer reachable over Wi-Fi:

```sh
fvm dart run integration_test/device/notification_network_server.dart
fvm flutter test --no-pub --flavor beta --device-id DEVICE --no-uninstall --dart-define=WS_EXTERNAL_LIFECYCLE=true --dart-define=WS_NETWORK_BASE_URL=http://HOST:8766/network integration_test/device/all_test.dart --reporter expanded
```

Use a reachable LAN address for `HOST`. The controlled peer exposes connection counts at `/state`; the Wi-Fi case should accept exactly two sockets, one before the outage and one after recovery. It emits one synthetic balance notification per connection.

Host actions follow markers printed by the tests:

| Marker | Host action |
| --- | --- |
| `WS_INIT_READY:INDEX` | Press Home to obtain fresh native lifecycle events after Flutter resets its binding between tests. |
| `WS_INIT_GATED:INDEX` | Resume the test activity before the case starts. |
| `WS_ANDROID_READY_BACKGROUND` | Press Home. |
| `WS_ANDROID_BACKGROUND_GATED` | Resume the test activity. |
| `WS_FOCUS_READY:shade` | Expand Android's notification panel. |
| `WS_FOCUS_GATED:shade` | Collapse the panel. |
| `WS_CASE_READY:ID:home` | Press Home. |
| `WS_CASE_READY:ID:lock` | Put the device to sleep and verify the keyguard is locked. |
| `WS_CASE_GATED:ID` | Unlock if necessary and resume the test activity. |
| `WS_NETWORK_READY` | Disable mobile data and Wi-Fi on the reserved device. |
| `WS_NETWORK_RESTORE` | Restore its original network settings. |

The matrix covers transient focus loss, repeated Home and screen-lock cycles, pending credentials and HTTP upgrades, authentication changes, peer disconnects, environment switching, programmer-error cleanup, refused upgrades, the native connection timeout, DNS retry spacing and background cancellation, and recovery from a real Wi-Fi outage. Lifecycle actions have a 45-second host-response limit. The network test allows up to 90 seconds for Android to detect the broken socket and up to 90 seconds for recovery; the production ping interval is retained.

Each matrix case checks its exported logs for severe errors, credential leakage, and raw notification payloads. Expected DNS and connection failures remain visible as warnings. A real notification-panel event is tested separately from the basic suite's simulated `inactive` event.
