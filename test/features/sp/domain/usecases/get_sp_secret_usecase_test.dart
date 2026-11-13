import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    as wallet_model;
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _WalletRepository extends Mock implements WalletRepository {}

class _Wallet extends Mock implements wallet_model.Wallet {}

void main() {
  for (final language in bip39.Language.values) {
    for (final passphrase in ['', 'TREZOR']) {
      for (final network in [BitcoinNetwork.mainnet, BitcoinNetwork.signet]) {
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
            final mainnet = _Wallet();
            final testnet = _Wallet();
            when(
              () => mainnet.network,
            ).thenReturn(wallet_model.Network.bitcoinMainnet);
            when(
              () => testnet.network,
            ).thenReturn(wallet_model.Network.bitcoinTestnet);
            final selected = network == BitcoinNetwork.mainnet
                ? mainnet
                : testnet;
            when(
              () => selected.masterFingerprint,
            ).thenReturn(secret.info.id.hex);
            final repository = _WalletRepository();
            when(
              () =>
                  repository.getWallets(onlyDefaults: true, onlyBitcoin: true),
            ).thenAnswer((_) async => Ok([mainnet, testnet]));

            final result = await GetSpSecretUsecase(
              walletRepository: repository,
              secrets: secrets,
            ).execute(network);

            expect(result, isA<Ok<Secret, SpFailure>>());
            expect(
              (result as Ok<Secret, SpFailure>).value.info.id,
              secret.info.id,
            );
            verify(
              () =>
                  repository.getWallets(onlyDefaults: true, onlyBitcoin: true),
            ).called(1);
          },
        );
      }
    }
  }
}
