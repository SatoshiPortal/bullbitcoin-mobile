import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

void main() {
  for (final language in bip39.Language.values) {
    for (final passphrase in ['', 'TREZOR']) {
      for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.testnet]) {
        test(
          '${language.name} with passphrase ${passphrase.isNotEmpty} uses the $network default',
          () async {
            FakeSecureStoragePlatform().install();
            final secrets = Secrets(scratchDirectory: () async => '/tmp');
            final words = bip39.Mnemonic(List.filled(16, 0), language).words;
            final imported = await secrets.import(
              words: words,
              language: language,
              passphrase: passphrase,
            );
            final secret = (imported as Ok<Secret, SecretFailure>).value;
            final result = await GetSpSecretUsecase(
              readDefaultFingerprint: (requested) async {
                expect(requested, network);
                return Ok(secret.id);
              },
              secrets: secrets,
            ).execute(network);

            expect(result, isA<Ok<Secret, SilentFailure>>());
            expect(
              (result as Ok<Secret, SilentFailure>).value.info.id,
              secret.info.id,
            );
          },
        );
      }
    }
  }

  for (final network in [BitcoinNetwork.signet, BitcoinNetwork.regtest]) {
    test('$network is rejected before looking up wallets', () async {
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');

      final result = await GetSpSecretUsecase(
        readDefaultFingerprint: (_) => throw StateError('inventory called'),
        secrets: secrets,
      ).execute(network);

      expect(result, isA<Err<Secret, SilentFailure>>());
      expect(
        (result as Err<Secret, SilentFailure>).failure,
        isA<SilentUnsupportedNetwork>(),
      );
    });
  }
}
