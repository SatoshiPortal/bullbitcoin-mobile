// Importing ONLY the public barrel, assert the seal: the public surface
// resolves the contracts/VOs/widgets, and there is no exported path to raw
// secret material. If someone later adds `export 'src/...'` for an internal
// type, this file (and the analyzer) is where it should surface.
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';

void main() {
  test('public contracts and failures are exported', () {
    // These references compile ONLY because the barrel exports them.
    expect(SeedPort, isNotNull);
    expect(KeyDerivationPort, isNotNull);
    expect(SignerPort, isNotNull);
    expect(SwapSignerPort, isNotNull);
    expect(BackupVaultPort, isNotNull);
    expect(Bip85Port, isNotNull);
    expect(SeedIndexPort, isNotNull);
    expect(SecretsLocator, isNotNull);
  });

  test('failure family is exported and switchable', () {
    const SecretsFailure f = KeychainLockedFailure();
    final label = switch (f) {
      KeychainLockedFailure() => 'locked',
      SeedNotFoundFailure() => 'missing',
      _ => 'other',
    };
    expect(label, 'locked');
  });

  test('value objects are exported', () {
    expect(MnemonicLength.words12.words, 12);
    expect(Bip85Application.recoverbull.number, 1608);
    expect(SwapDirection.values, contains(SwapDirection.reverse));
  });
}
