import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/adapters/fss_secret_store_adapter.dart';
import 'package:secrets/src/data/adapters/secret_guard.dart';
import 'package:secrets/src/data/datasources/keychain_locked_exception.dart';
import 'package:secrets/src/domain/ports/secure_key_value_store_port.dart';
import 'package:secrets/src/domain/secrets_failure.dart';

/// A store whose read throws an UNRECOGNIZED PlatformException (neither a known
/// lock signal nor a not-found). Exercises the read path's failure typing.
class _ThrowingKvStore implements SecureKeyValueStorePort {
  _ThrowingKvStore(this._error);
  final Object _error;
  @override
  Future<String?> read(String key) async => throw _error;
  @override
  Future<void> write(String key, String value) async => throw _error;
  @override
  Future<void> delete(String key) async {}
  @override
  Future<Map<String, String>> readAll() async => {};
  @override
  Future<bool> containsKey(String key) async => false;
  @override
  Future<void> deleteAll() async {}
}

void main() {
  group('isKeychainLockedError', () {
    // Table-driven over EVERY needle the matcher recognizes, asserting each
    // (matched in either the code or the message field) classifies as locked.
    const needles = [
      '-25308',
      'interactionnotallowed',
      'interaction_not_allowed',
      'usernotauthenticated',
      'user not authenticated',
      'keychain is locked',
      'keystore is locked',
      'keystore not initialized',
    ];
    for (final needle in needles) {
      test('classifies "$needle" in the CODE as locked', () {
        expect(
          isKeychainLockedError(PlatformException(code: needle)),
          isTrue,
        );
      });
      test('classifies "$needle" in the MESSAGE as locked', () {
        expect(
          isKeychainLockedError(
              PlatformException(code: 'X', message: 'failed: $needle here')),
          isTrue,
        );
      });
    }

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

    // Detection is separator-INSENSITIVE (normalize strips punctuation/casing),
    // so the same locked signal is caught regardless of the platform's spelling.
    for (final variant in [
      'user_not_authenticated', // snake_case (the M4 example)
      'USER-NOT-AUTHENTICATED', // SCREAMING-KEBAB
      'User Not Authenticated', // Title Case with spaces
      'userNotAuthenticated', // camelCase
    ]) {
      test('classifies separator variant "$variant" as locked', () {
        expect(isKeychainLockedError(PlatformException(code: variant)), isTrue);
      });
    }

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

  group('read path: an UNKNOWN PlatformException never becomes SeedNotFound', () {
    test('a generic PlatformException surfaces as a typed failure, not '
        'not-found', () async {
      // The locked≠missing invariant in reverse: a read failing with an
      // unrecognized platform error must NOT be mistaken for "no such seed"
      // (which would let the UI tell a user with funds that their wallet is
      // gone). It must surface as a real/transient failure.
      final store = FssSecretStoreAdapter(
        _ThrowingKvStore(
            PlatformException(code: 'SomethingWeird', message: 'unexpected')),
        initialRetryDelay: Duration.zero,
      );
      final guard = SecretGuard(store);
      final res = await guard.run<void>(
        () async => store.useAndForget('seed_x', (_) async => const Ok(null)),
        fingerprint: Fingerprint('deadbeef'),
        onError: SecretsUnexpectedFailure.new,
      );
      final failure = (res as Err<void, SecretsFailure>).failure;
      expect(failure, isNot(isA<SecretNotFoundFailure>()));
      expect(failure, isA<SecretsUnexpectedFailure>());
    });
  });
}
