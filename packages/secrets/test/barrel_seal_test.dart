// SMOKE TEST of the PUBLIC surface only — NOT the seal enforcement.
//
// This file merely confirms the documented public types ARE exported (they
// compile when imported from the barrel). It can NOT prove the inverse — that
// an INTERNAL type is NOT exported — because a runtime test cannot assert the
// absence of an export. The real seal enforcement lives in `tool/seal_check.sh`
// (run via `make seal-check` in CI), which default-deny-checks every `export
// 'src/...'` against an allow-list and confines flutter_secure_storage imports.
// Treat this file as a quick public-API regression check, not the boundary
// guarantee. The internal capability ports (KeyDerivationPort, SignerPort, …)
// and SecretsLocator are deliberately NOT imported here — they are no longer
// exported, and referencing them would fail to compile.
import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/secrets.dart';

void main() {
  test('public entry + handle hierarchy are exported', () {
    expect(Secrets, isNotNull);
    expect(Secret, isNotNull);
    expect(MnemonicSecret, isNotNull);
    expect(SeedSecret, isNotNull);
    expect(SecretIndexPort, isNotNull); // the one injected contract (app implements)
  });

  test('sealed display widgets are exported', () {
    expect(SecretRevealer, isNotNull);
    expect(SecretRevealerStrings, isNotNull);
    expect(VerifyBackupView, isNotNull);
    expect(Bip85MnemonicView, isNotNull);
    expect(Bip85HexView, isNotNull);
  });

  test('failure family is exported and switchable', () {
    const SecretsFailure f = KeychainLockedFailure();
    final label = switch (f) {
      KeychainLockedFailure() => 'locked',
      SecretNotFoundFailure() => 'missing',
      _ => 'other',
    };
    expect(label, 'locked');
  });

  test('typed error family is exported and is an ArgumentError', () {
    final SecretsError e = InvalidPsbtError('x');
    expect(e, isA<ArgumentError>());
  });

  test('value objects + re-exported primitives are reachable via the barrel', () {
    expect(MnemonicLength.words12.words, 12);
    expect(MnemonicLanguage.english, isNotNull);
    expect(SecretKind.values, contains(SecretKind.seed));
    expect(Bip85Application.recoverbull.number, 1608);
    expect(ChainDirection.values, contains(ChainDirection.btcToLbtc));
    // Swap-creation requests are caller-knowable value objects on the barrel.
    const req = ReverseSwapRequest(requestedReceiveSat: 1000);
    expect(req, isA<SwapRequest>());
    // primitives re-exported so consumers need only one import:
    expect(BitcoinNetwork.signet.coinType, 1);
    expect(LiquidNetwork.mainnet.coinType, 1776);
    expect(ScriptType.bip84.purpose, 84);
  });
}
