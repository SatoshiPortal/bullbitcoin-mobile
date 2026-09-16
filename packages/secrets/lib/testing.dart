/// Test support for consumers of `package:secrets`.
///
/// `Secrets` and `Secret` are `final`: nothing can implement or extend them, in production or in a test. That is deliberate — a double of the custody boundary is a hole in it — so the package offers the seam it uses itself instead: an in-memory `flutter_secure_storage`, installed at `FlutterSecureStoragePlatform.instance`. A test then runs the *real* `Secrets` — real key composition, real JSON, real identity derivation, real failure classification — against a store it controls and can inspect.
///
/// One instance is live at a time, process-wide; `flutter test` runs each file in its own isolate, so that is one per file. A stored secret costs one PBKDF2 pass to create (~150 ms on desktop); use the published BIP39 test vectors and create only what the test needs.
///
/// Import this in `test/` only. It is not part of the custody contract and is not exported by `package:secrets/secrets.dart`.
library;

export 'src/testing/fake_secure_storage_platform.dart'
    show FakeSecureStoragePlatform;
