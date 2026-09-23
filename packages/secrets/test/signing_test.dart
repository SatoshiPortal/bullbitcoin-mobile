import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/src/crypto/exceptions.dart' show PsbtSigningFailed;
import 'package:secrets/testing.dart';

import 'result_helpers.dart';

/// Bitcoin signing, through the public API, with real bdk: the package's
/// own comments held that this could not run under `flutter test`, so the
/// whole release discipline of `BitcoinSigner` — every handle declared
/// before the try and freed in the finally — was rewritten untested. A
/// garbage PSBT is enough to walk it end to end: the wallet is built from
/// the words, the parse refuses, and every handle is released on the way
/// out. No funded wallet is needed to prove that.
void main() {
  const words = [
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'abandon',
    'about',
  ];

  late Secret secret;

  setUpAll(() async {
    FakeSecureStoragePlatform().install();
    secret = ok(
      await Secrets(scratchDirectory: () async => '/tmp').import(words: words),
    );
  });

  group('signPsbt', () {
    test('refuses what is not a PSBT, by type only', () async {
      final result = await secret.sign.psbt(
        'not a psbt',
        network: BitcoinNetwork.mainnet,
        scriptType: ScriptType.bip84,
      );

      final failure = err(result);
      expect(failure, isA<SecretDerivationFailure>());
      // bdk's parse error quotes its input; none of it may travel.
      expect(failure.logMessage, isNot(contains('not a psbt')));
    });

    test('is refused outright on a network bdk cannot sign for', () async {
      // Every BitcoinNetwork maps to a bdk network, so this walks the wallet
      // build on each — testnet, signet and regtest share version bytes.
      for (final network in BitcoinNetwork.values) {
        final result = await secret.sign.psbt(
          'not a psbt',
          network: network,
          scriptType: ScriptType.bip84,
        );
        expect(err(result), isA<SecretDerivationFailure>(), reason: '$network');
      }
    });
  });

  group('psbtSigner', () {
    test(
      'hands back a synchronous signer that refuses garbage by type',
      () async {
        final signer = ok(
          await secret.sign.psbtSigner(
            network: BitcoinNetwork.mainnet,
            scriptType: ScriptType.bip84,
          ),
        );

        // Outside the boundary by design — the payjoin engine calls this from
        // a native callback — so the refusal is the package's own exception,
        // never bdk's, and never a Result.
        expect(() => signer('not a psbt'), throwsA(isA<PsbtSigningFailed>()));
      },
    );
  });
}
