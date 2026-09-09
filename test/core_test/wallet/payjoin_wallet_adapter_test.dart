import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
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

import 'wallet_signer_test_fixture.dart';

class _SeedDatasource extends Mock implements SeedDatasource {}

class _BdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _WalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';
const _descriptor = 'wpkh([73c5da0a/84h/1h/0h]tpub-test/<0;1>/*)';

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
            account: 0,
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
    addTearDown(signingMaterial.close);
    adapter = PayjoinWalletAdapter(bdk, metadata, signingMaterial);

    when(() => metadata.fetch(_walletId)).thenAnswer(
      (_) async => WalletMetadataModel(
        id: _walletId,
        network: Network.bitcoinTestnet,
        signers: [
          walletSignerModel(
            id: 'signer-0',
            descriptorKeyId: 'key-0',
            masterFingerprint: '73c5da0a',
            xpubFingerprint: 'deadbeef',
            xpub: 'tpub-test',
            derivationPath: "m/84'/1'/0'",
            descriptorPath: '/<0;1>/*',
            signer: Signer.local,
            signerDevice: null,
          ),
        ],
        isEncryptedVaultTested: false,
        isPhysicalBackupTested: false,
        publicDescriptor: _descriptor,
        isDefault: false,
        provenance: WalletProvenance.defaultSeedPassphrase,
      ),
    );
  });

  void unlock() {
    expect(
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
      ),
      isTrue,
    );
  }

  for (final reopen in [false, true]) {
    test('retained processor refuses after lock (reopen: $reopen)', () async {
      unlock();
      var signatures = 0;
      when(() => bdk.createPsbtSigner(wallet: any(named: 'wallet'))).thenAnswer(
        (_) async => (_) {
          signatures++;
          return 'signed';
        },
      );
      final sign = await adapter.createPsbtProcessor(
        walletId: _walletId,
        network: BitcoinNetwork.testnet,
      );
      expect(sign('before lock'), 'signed');
      expect(signatures, 1);
      signingMaterial.clearPrivateCapabilityForBackground();
      if (reopen) unlock();
      expect(
        () => sign('after lock'),
        throwsA(isA<PassphraseWalletLockedException>()),
      );
      expect(signatures, 1);
      verifyNever(() => seeds.get(any()));
    });
  }

  test('lock during native processor creation rejects the result', () async {
    unlock();
    final entered = Completer<void>();
    final ready = Completer<String Function(String)>();
    when(() => bdk.createPsbtSigner(wallet: any(named: 'wallet'))).thenAnswer((
      _,
    ) {
      entered.complete();
      return ready.future;
    });
    final pending = adapter.createPsbtProcessor(
      walletId: _walletId,
      network: BitcoinNetwork.testnet,
    );
    final rejected = expectLater(
      pending,
      throwsA(isA<PassphraseWalletLockedException>()),
    );
    await entered.future;
    signingMaterial.clearPrivateCapability();
    unlock();
    ready.complete((_) => 'must not escape');
    await rejected;
    verifyNever(() => seeds.get(any()));
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
    verifyNever(
      () => bdk.signPsbt(
        any(),
        wallet: any(named: 'wallet'),
        allowFinalizedForeignInputs: any(named: 'allowFinalizedForeignInputs'),
        checkSigningSession: any(named: 'checkSigningSession'),
      ),
    );
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
        () => bdk.signPsbt(
          'unsigned',
          wallet: any(named: 'wallet'),
          allowFinalizedForeignInputs: true,
          checkSigningSession: any(named: 'checkSigningSession'),
        ),
      ).thenAnswer((_) async => (psbt: 'signed', isFinalized: true));

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
