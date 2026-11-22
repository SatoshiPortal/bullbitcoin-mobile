import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_service.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Mnemonic;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import '../../integration_test/funded_testnet_wallet.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  test(
    'reuses the funded testnet account after an earlier group imports it',
    () async {
      FakeSecureStoragePlatform().install();
      final secrets = Secrets(scratchDirectory: () async => '/tmp');
      final mnemonic = Mnemonic(List<int>.filled(16, 0), Language.english);
      final imported = await secrets.import(
        words: mnemonic.words,
        language: Language.english,
      );
      final secret = (imported as Ok<Secret, SecretFailure>).value;
      final id = WalletMetadataService.encodeId(
        fingerprint: secret.id.hex,
        network: Network.bitcoinTestnet,
        scriptType: ScriptType.bip84,
      );
      final wallet = _MockWallet();
      final wallets = _MockWalletRepository();
      when(() => wallets.getWallet(id)).thenAnswer((_) async => Ok(wallet));

      expect(
        await openFundedTestnetWallet(
          mnemonic: mnemonic.sentence,
          secrets: secrets,
          wallets: wallets,
        ),
        same(wallet),
      );
      verify(() => wallets.getWallet(id)).called(1);
      verifyNoMoreInteractions(wallets);
    },
  );
}
