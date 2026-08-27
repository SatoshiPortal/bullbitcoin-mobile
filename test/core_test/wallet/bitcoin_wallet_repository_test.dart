import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/tables/wallet_signer_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'wallet_signer_test_fixture.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockSeedDatasource extends Mock implements SeedDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockFrozenWalletUtxoDatasource extends Mock
    implements FrozenWalletUtxoDatasource {}

// Encodes as a bitcoin testnet BIP84 origin so
// WalletMetadataModelExtension.isBitcoin decodes to true.
const _walletId = 'wpkh([73c5da0a/84h/1h/0h])';

WalletUtxo _utxo({required String txId, required int vout}) =>
    WalletUtxo.bitcoin(
      walletId: _walletId,
      txId: txId,
      vout: vout,
      scriptPubkey: Uint8List(0),
      amountSat: BigInt.from(100000),
      address: 'tb1-test-address',
    );

void main() {
  late _MockWalletMetadataDatasource metadataDatasource;
  late _MockSeedDatasource seedDatasource;
  late _MockBdkWalletDatasource bdkDatasource;
  late _MockFrozenWalletUtxoDatasource frozenDatasource;
  late BitcoinWalletRepository repository;

  final metadata = WalletMetadataModel(
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
    publicDescriptor: 'wpkh([73c5da0a/84h/1h/0h]tpub-test/<0;1>/*)',
    isDefault: true,
  );

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        descriptor: 'wpkh([73c5da0a/84h/1h/0h]tpub-test/<0;1>/*)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(const NetworkFee.relativeSatPerKwu(1000));
  });

  setUp(() {
    metadataDatasource = _MockWalletMetadataDatasource();
    seedDatasource = _MockSeedDatasource();
    bdkDatasource = _MockBdkWalletDatasource();
    frozenDatasource = _MockFrozenWalletUtxoDatasource();
    repository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      seedDatasource: seedDatasource,
      bdkWalletDatasource: bdkDatasource,
      frozenWalletUtxoDatasource: frozenDatasource,
    );

    when(
      () => metadataDatasource.fetch(_walletId),
    ).thenAnswer((_) async => metadata);
    // Frozen store is empty by default; individual tests override it.
    when(() => frozenDatasource.getAllFrozen()).thenAnswer((_) async => []);
    when(
      () => bdkDatasource.buildPsbt(
        wallet: any(named: 'wallet'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
        policyPath: any(named: 'policyPath'),
      ),
    ).thenAnswer((_) async => 'psbt');
  });

  ({
    List<WalletUtxoModel>? selected,
    List<({String txId, int vout})>? unspendable,
  })
  capturedSelection() {
    final captured = verify(
      () => bdkDatasource.buildPsbt(
        wallet: any(named: 'wallet'),
        address: any(named: 'address'),
        amountSat: any(named: 'amountSat'),
        networkFee: any(named: 'networkFee'),
        drain: any(named: 'drain'),
        unspendable: captureAny(named: 'unspendable'),
        selected: captureAny(named: 'selected'),
        replaceByFee: any(named: 'replaceByFee'),
        policyPath: any(named: 'policyPath'),
      ),
    ).captured;
    return (
      unspendable: captured[0] as List<({String txId, int vout})>?,
      selected: captured[1] as List<WalletUtxoModel>?,
    );
  }

  List<({String txId, int vout})>? capturedUnspendable() =>
      verify(
            () => bdkDatasource.buildPsbt(
              wallet: any(named: 'wallet'),
              address: any(named: 'address'),
              amountSat: any(named: 'amountSat'),
              networkFee: any(named: 'networkFee'),
              drain: any(named: 'drain'),
              unspendable: captureAny(named: 'unspendable'),
              selected: any(named: 'selected'),
              replaceByFee: any(named: 'replaceByFee'),
              policyPath: any(named: 'policyPath'),
            ),
          ).captured.single
          as List<({String txId, int vout})>?;

  bool capturedReplaceByFee() =>
      verify(
            () => bdkDatasource.buildPsbt(
              wallet: any(named: 'wallet'),
              address: any(named: 'address'),
              amountSat: any(named: 'amountSat'),
              networkFee: any(named: 'networkFee'),
              drain: any(named: 'drain'),
              unspendable: any(named: 'unspendable'),
              selected: any(named: 'selected'),
              replaceByFee: captureAny(named: 'replaceByFee'),
              policyPath: any(named: 'policyPath'),
            ),
          ).captured.single
          as bool;

  Future<void> buildPsbt({
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool? replaceByFee,
  }) => repository.buildPsbt(
    walletId: _walletId,
    address: 'tb1-destination',
    amountSat: 25000,
    networkFee: const NetworkFee.relativeSatPerKwu(1000),
    unspendable: unspendable,
    selected: selected,
    replaceByFee: replaceByFee,
  );

  group('frozen coins', () {
    test(
      'keeps manual selection strict and forwards frozen exclusions',
      () async {
        when(() => frozenDatasource.getAllFrozen()).thenAnswer(
          (_) async => [(walletId: _walletId, txId: 'tx-frozen', vout: 0)],
        );

        await buildPsbt(
          selected: [
            _utxo(txId: 'tx-frozen', vout: 0),
            _utxo(txId: 'tx-free', vout: 1),
          ],
        );

        final captured = capturedSelection();
        expect(captured.selected, hasLength(2));
        expect(captured.unspendable, contains((txId: 'tx-frozen', vout: 0)));
      },
    );

    test('frozen outpoints are merged into the unspendable list passed down, '
        'so automatic selection cannot pick them either', () async {
      when(() => frozenDatasource.getAllFrozen()).thenAnswer(
        (_) async => [(walletId: _walletId, txId: 'tx-frozen', vout: 0)],
      );

      await buildPsbt(unspendable: const [(txId: 'tx-caller', vout: 3)]);

      final unspendable = capturedUnspendable();
      expect(
        unspendable,
        containsAll(<({String txId, int vout})>[
          (txId: 'tx-frozen', vout: 0),
          (txId: 'tx-caller', vout: 3),
        ]),
      );
      expect(unspendable, hasLength(2));
    });

    test(
      'duplicate outpoints (frozen AND caller-supplied) are deduped',
      () async {
        when(() => frozenDatasource.getAllFrozen()).thenAnswer(
          (_) async => [(walletId: _walletId, txId: 'tx-both', vout: 0)],
        );

        await buildPsbt(unspendable: const [(txId: 'tx-both', vout: 0)]);

        expect(capturedUnspendable(), hasLength(1));
      },
    );
  });

  group('replaceByFee default', () {
    test('omitted flag defaults to RBF ENABLED (true)', () async {
      await buildPsbt();

      expect(capturedReplaceByFee(), isTrue);
    });

    test('explicit false is forwarded unchanged', () async {
      await buildPsbt(replaceByFee: false);

      expect(capturedReplaceByFee(), isFalse);
    });
  });
}
