// SMOKE TEST of the PUBLIC surface only — NOT the seal enforcement.
//
// This file merely confirms the documented public types ARE exported (they
// compile when imported from the barrel). It can NOT prove the inverse — that
// an INTERNAL type is NOT exported — because a runtime test cannot assert the
// absence of an export. The real seal enforcement lives in `tool/seal_check.sh`
// (run via `make seal-check` in CI), which scans for stray `export 'src/...'`
// lines and confines flutter_secure_storage imports. Treat this file as a
// quick public-API regression check, not the boundary guarantee.
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
