import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

import '../wallet_signer_test_fixture.dart';

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

void main() {
  test('rejects Payjoin signing for a higher-account wallet', () async {
    final seed = _MockSeedDatasource();
    final wallet = _MockBdkWalletDatasource();
    final metadata = _MockWalletMetadataDatasource();
    when(() => metadata.fetch('wallet')).thenAnswer(
      (_) async => WalletMetadataModel(
        id: 'wallet',
        network: Network.bitcoinMainnet,
        signers: [
          walletSignerModel(
            id: 'signer-0',
            descriptorKeyId: 'key-0',
            masterFingerprint: '73c5da0a',
            xpubFingerprint: 'deadbeef',
            xpub: 'xpub-test',
            derivationPath: "m/84'/0'/1'",
            descriptorPath: '/<0;1>/*',
            signer: Signer.local,
            signerDevice: null,
          ),
        ],
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        publicDescriptor: 'wpkh(xpub-test/<0;1>/*)',
        isDefault: false,
      ),
    );
    final adapter = PayjoinWalletAdapter(seed, wallet, metadata);

    await expectLater(
      adapter.signPsbt(
        walletId: 'wallet',
        network: BitcoinNetwork.mainnet,
        psbt: 'psbt',
      ),
      throwsA(isA<StateError>()),
    );
    verifyNever(() => seed.get(any()));
  });
}
