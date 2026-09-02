import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/payjoin_wallet_adapter.dart';
import 'package:bb_mobile/core/wallet/data/wallet_signing_material_resolver.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/services/wallet_unlock_session.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinNetwork;

class _SeedDatasource extends Mock implements SeedDatasource {}

class _BdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _WalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';

void main() {
  late _SeedDatasource seeds;
  late _BdkWalletDatasource bdk;
  late _WalletMetadataDatasource metadata;
  late WalletSigningMaterialResolver signingMaterial;
  late PayjoinWalletAdapter adapter;

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.privateBdk(
            id: 'fallback',
            scriptType: ScriptType.bip84,
            mnemonic: 'abandon',
            isTestnet: true,
          )
          as PrivateBdkWalletModel,
    );
  });

  setUp(() {
    seeds = _SeedDatasource();
    bdk = _BdkWalletDatasource();
    metadata = _WalletMetadataDatasource();
    signingMaterial = WalletSigningMaterialResolver(
      seedDatasource: seeds,
      session: WalletUnlockSession(),
    );
    adapter = PayjoinWalletAdapter(bdk, metadata, signingMaterial);

    when(() => metadata.fetch(_walletId)).thenAnswer(
      (_) async => const WalletMetadataModel(
        id: _walletId,
        masterFingerprint: '73c5da0a',
        xpubFingerprint: 'deadbeef',
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        xpub: 'tpub-test',
        externalPublicDescriptor: 'wpkh(external)',
        internalPublicDescriptor: 'wpkh(internal)',
        signer: Signer.local,
        isDefault: false,
        provenance: WalletProvenance.defaultSeedPassphrase,
      ),
    );
  });

  test('requires the volatile unlock session', () async {
    await expectLater(
      adapter.signPsbt(
        walletId: _walletId,
        network: BitcoinNetwork.testnet,
        psbt: 'unsigned',
      ),
      throwsA(isA<PassphraseWalletLockedException>()),
    );

    verifyNever(() => seeds.get(any()));
    verifyNever(() => bdk.signPsbt(any(), wallet: any(named: 'wallet')));
  });

  test(
    'signs from the volatile session without reading persistent seeds',
    () async {
      signingMaterial.loadPrivateCapabilityIfCurrent(
        generation: signingMaterial.beginPrivateCapabilityMount(),
        walletId: _walletId,
        seed:
            Seed.mnemonic(
                  mnemonicWords: const ['abandon'],
                  passphrase: 'secret',
                  bytes: Uint8List.fromList([1]),
                  masterFingerprint: '73c5da0a',
                )
                as MnemonicSeed,
      );
      when(
        () => bdk.signPsbt('unsigned', wallet: any(named: 'wallet')),
      ).thenAnswer((_) async => 'signed');

      final result = await adapter.signPsbt(
        walletId: _walletId,
        network: BitcoinNetwork.testnet,
        psbt: 'unsigned',
      );

      expect(result, 'signed');
      verifyNever(() => seeds.get(any()));
    },
  );
}
