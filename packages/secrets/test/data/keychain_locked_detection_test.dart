import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';

void main() {
  group('isKeychainLockedError', () {
    test('detects iOS errSecInteractionNotAllowed', () {
      expect(
        isKeychainLockedError(
            PlatformException(code: '-25308', message: 'interactionNotAllowed')),
        isTrue,
      );
    });

    test('detects Android user-not-authenticated', () {
      expect(
        isKeychainLockedError(PlatformException(
            code: 'UserNotAuthenticated', message: 'user not authenticated')),
        isTrue,
      );
    });

    test('does NOT classify a generic Keystore corruption as locked', () {
      // The bare substring "keystore" must not match — a corrupt/missing entry
      // is a real loss, not a transient lock (would otherwise hide it behind an
      // endless "unlock and retry").
      expect(
        isKeychainLockedError(PlatformException(
            code: 'KeyStoreException',
            message: 'Failed to obtain X509 from keystore')),
        isFalse,
      );
    });

    test('passes through the package-internal KeychainLockedException', () {
      expect(isKeychainLockedError(const KeychainLockedException()), isTrue);
    });

    test('non-platform errors are not locked', () {
      expect(isKeychainLockedError(const FormatException('bad')), isFalse);
    });
  });
}
