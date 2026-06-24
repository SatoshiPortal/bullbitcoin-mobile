import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/secrets_failure.dart';

void main() {
  group('SecretsFailure family', () {
    test('every variant is a SecretsFailure and a Failure', () {
      final variants = <SecretsFailure>[
        SecretNotFoundFailure(Fingerprint('deadbeef')),
        const KeychainLockedFailure(),
        const InvalidMnemonicFailure(),
        DuplicateSecretFailure(Fingerprint('deadbeef')),
        const NotAMnemonicFailure(),
        const DerivationFailure(),
        const SigningFailure(),
        const VaultFailure(),
        const SecretsUnexpectedFailure(),
      ];
      for (final v in variants) {
        expect(v, isA<Failure>());
        expect(v, isA<SecretsFailure>());
      }
    });

    test('DuplicateSecretFailure carries its fingerprint', () {
      final f = DuplicateSecretFailure(Fingerprint('0a1b2c3d'));
      expect(f.fingerprint.hex, '0a1b2c3d');
    });

    test('locked and not-found are DISTINCT types (never collapsed)', () {
      const SecretsFailure locked = KeychainLockedFailure();
      final SecretsFailure notFound = SecretNotFoundFailure(Fingerprint('deadbeef'));
      expect(locked, isNot(isA<SecretNotFoundFailure>()));
      expect(notFound, isNot(isA<KeychainLockedFailure>()));
      // The fund-critical guard is an unmissable flat switch.
      String classify(SecretsFailure f) => switch (f) {
            KeychainLockedFailure() => 'retry-after-unlock',
            SecretNotFoundFailure() => 'maybe-recover',
            _ => 'other',
          };
      expect(classify(locked), 'retry-after-unlock');
      expect(classify(notFound), 'maybe-recover');
    });

    test('failures carry a fingerprint where relevant', () {
      final f = SecretNotFoundFailure(Fingerprint('0a1b2c3d'));
      expect(f.fingerprint.hex, '0a1b2c3d');
    });
  });
}
