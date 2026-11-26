/// The test seam, as a module: what `package:secrets/testing.dart` exports.
///
/// Under the same rules as the four others — cross-module imports come
/// through this file — and the only module besides `data/` allowed to
/// touch the keystore plugin, because it *is* a keystore.
library;

export 'fake_secure_storage_platform.dart' show FakeSecureStoragePlatform;

export 'exchange_keychain_probe.dart' show ExchangeKeychainProbe;
export 'legacy_exchange_keychain_fixture.dart'
    show LegacyExchangeKeychainFixture;
export 'unlocked_session_authority.dart' show unlockedSessionAuthority;
