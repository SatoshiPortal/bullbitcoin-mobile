import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' hide ScriptType;

import '../wallet_signer_test_fixture.dart';

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

void main() {
  test(
    'signs Payjoin at the stored account with foreign final inputs',
    () async {
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
      const privateWallet = WalletModel.privateBdk(
        id: 'wallet',
        scriptType: ScriptType.bip84,
        mnemonic: 'test',
        account: 1,
        isTestnet: false,
      );
      when(() => seed.get('73c5da0a')).thenAnswer(
        (_) async => const SeedModel.mnemonic(mnemonicWords: ['test']),
      );
      // Private wallet models keep identity equality (they carry a mnemonic),
      // so match any model here and check the derived fields afterwards.
      registerFallbackValue(privateWallet as PrivateBdkWalletModel);
      when(
        () => wallet.signPsbt(
          'psbt',
          wallet: any(named: 'wallet'),
          allowFinalizedForeignInputs: true,
          checkSigningSession: any(named: 'checkSigningSession'),
        ),
      ).thenAnswer((_) async => (psbt: 'signed', isFinalized: true));
      final adapter = PayjoinWalletAdapter(
        wallet,
        metadata,
        WalletSigningMaterialResolver(
          seedDatasource: seed,
          session: WalletUnlockSession(),
        ),
      );

      final result = await adapter.signPsbt(
        walletId: 'wallet',
        network: BitcoinNetwork.mainnet,
        psbt: 'psbt',
      );

      expect(result, 'signed');
      final signedWith =
          verify(
                () => wallet.signPsbt(
                  'psbt',
                  wallet: captureAny(named: 'wallet'),
                  allowFinalizedForeignInputs: true,
                  checkSigningSession: any(named: 'checkSigningSession'),
                ),
              ).captured.single
              as PrivateBdkWalletModel;
      final expected = privateWallet;
      expect(signedWith.id, expected.id);
      expect(signedWith.scriptType, expected.scriptType);
      expect(signedWith.mnemonic, expected.mnemonic);
      expect(signedWith.passphrase, expected.passphrase);
      expect(signedWith.account, expected.account);
      expect(signedWith.isTestnet, expected.isTestnet);
    },
  );
}
