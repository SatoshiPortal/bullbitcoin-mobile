import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/secrets_failure.dart';

void main() {
  group('SecretsFailure family', () {
    test('every variant is a SecretsFailure and a Failure', () {
      final variants = <SecretsFailure>[
        SeedNotFoundFailure(Fingerprint('deadbeef')),
        const KeychainLockedFailure(),
        const InvalidMnemonicFailure(),
        DuplicateSeedFailure(Fingerprint('deadbeef')),
        const NotAMnemonicSeedFailure(),
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

    test('DuplicateSeedFailure carries its fingerprint', () {
      final f = DuplicateSeedFailure(Fingerprint('0a1b2c3d'));
      expect(f.fingerprint.hex, '0a1b2c3d');
    });

    test('locked and not-found are DISTINCT types (never collapsed)', () {
      const SecretsFailure locked = KeychainLockedFailure();
      final SecretsFailure notFound = SeedNotFoundFailure(Fingerprint('deadbeef'));
      expect(locked, isNot(isA<SeedNotFoundFailure>()));
      expect(notFound, isNot(isA<KeychainLockedFailure>()));
      // The fund-critical guard is an unmissable flat switch.
      String classify(SecretsFailure f) => switch (f) {
            KeychainLockedFailure() => 'retry-after-unlock',
            SeedNotFoundFailure() => 'maybe-recover',
            _ => 'other',
          };
      expect(classify(locked), 'retry-after-unlock');
      expect(classify(notFound), 'maybe-recover');
    });

    test('failures carry a fingerprint where relevant', () {
      final f = SeedNotFoundFailure(Fingerprint('0a1b2c3d'));
      expect(f.fingerprint.hex, '0a1b2c3d');
    });
  });
}
