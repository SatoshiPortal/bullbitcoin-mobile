# Exchange credential probes on physical Android devices

These standalone tests use the real secure-storage driver, Dio, WebSocket and WebView plugins. Synthetic records are restricted to `__credential_refactor_probe__*`; setup and teardown remove only those records. They do not initialize wallets or submit exchange orders. The simulated storage refusal checks error propagation; it does not claim to reproduce an Android keychain failure.

The optional live probe reads the existing **testnet/preprod** credential through the production locator and checks account, order-history and recipient reads. It never changes the live credential. Enable it only on a device already signed in to preprod. Assertions compare booleans so failures cannot print live credentials or account responses.

1. Reserve the physical device and verify its installed application ID, signer, configuration and available space. Use the project's pinned SDK and the host's configured Android SDK, JDK and ADB server. Preserve the existing debug application's data.
2. Run `make exchange-credentials-device-build` for synthetic probes, or `make exchange-credentials-device-build EXCHANGE_DEVICE_LIVE=true` to include the read-only preprod probe. The output is `build/app/outputs/flutter-apk/app-arm64-v8a-production-debug.apk`, for `android-arm64` only.
3. Verify the APK's application ID is `com.bullbitcoin.mobile.debug` and its signer matches the installed debug application. Install in place with `adb -s <serial> install -t -r <apk>`, explicitly selecting the shared ADB server when applicable. Stop on installation failure; do not uninstall or clear data to recover automatically.
4. Launch the debug main activity and forward its reported Dart VM service port to an available localhost port. Run `make exchange-credentials-device-test DEVICE=<serial> VM_SERVICE_URL=<forwarded-service-uri>`. The SDK integration driver connects directly to that VM service; it does not install, uninstall or stop the application. Avoid `flutter test` here: its integration runner uninstalls by default and its install fallback can also uninstall an existing app.
5. Stop the test application, then restore the normal debug application with the same signer and an in-place install, verify the existing session and normal account/wallet screens, then lock the reserved device before releasing it. Remove the task's own ADB port forwarding.

These files stay below `integration_test/device/` so the ordinary top-level integration aggregator does not discover device/session-dependent probes.

The loopback HTTP/WebSocket probes use Dart I/O, without changing platform network-security settings ([Flutter network policy](https://docs.flutter.dev/release/breaking-changes/network-policy-ios-android), checked 2026-10-20). Native instrumentation reporting is disabled for this VM-service-driven harness.
