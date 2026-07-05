import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/adapters/flutter_secure_storage_adapter.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';

// END-TO-END lock translation (audit M4). The other suites fake the
// SecureKeyValueStorePort and throw an ALREADY-translated KeychainLockedException,
// so the real `FlutterSecureStorageAdapter._guard` → `isKeychainLockedError`
// chain — where a RAW platform error becomes a KeychainLockedException — was
// never exercised. These tests drive a raw PlatformException through the real
// adapter (over the mocked plugin method channel) and assert that wiring:
// locked → KeychainLockedException, non-lock → rethrown unchanged (never
// misclassified as locked, which would mask a real loss behind "unlock & retry").
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void mockThrow(PlatformException e) =>
      messenger.setMockMethodCallHandler(channel, (_) async => throw e);

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  // `.standard()` builds the plugin internally, so the test needs no direct
  // `flutter_secure_storage` import (which the seal confines to the adapter).
  final adapter = FlutterSecureStorageAdapter.standard();

  group('FlutterSecureStorageAdapter raw-error → KeychainLockedException', () {
    test('iOS errSecInteractionNotAllowed (-25308) on read', () {
      mockThrow(PlatformException(code: '-25308'));
      expect(adapter.read('seed_x'), throwsA(isA<KeychainLockedException>()));
    });

    test('Android user-not-authenticated on write', () {
      mockThrow(PlatformException(
          code: 'Exception', message: 'User not authenticated'));
      expect(
          adapter.write('seed_x', 'v'), throwsA(isA<KeychainLockedException>()));
    });

    test('keystore-is-locked message on containsKey', () {
      mockThrow(PlatformException(
          code: 'Exception', message: 'Keystore is locked'));
      expect(
          adapter.containsKey('seed_x'), throwsA(isA<KeychainLockedException>()));
    });

    test('a NON-lock platform error is rethrown, NOT misclassified as locked',
        () {
      // A corrupt/missing entry must NOT read as "locked" — that would hide a
      // real loss behind an endless unlock-and-retry (locked ≠ missing).
      mockThrow(PlatformException(code: 'Exception', message: 'corrupt entry'));
      expect(
        adapter.read('seed_x'),
        throwsA(allOf(
          isA<PlatformException>(),
          isNot(isA<KeychainLockedException>()),
        )),
      );
    });
  });
}
