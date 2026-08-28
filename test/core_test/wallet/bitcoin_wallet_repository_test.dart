// Unit tests for the repository-boundary guarantees of
// `BitcoinWalletRepository.buildPsbt`:
//
//  1. D7 defense in depth — "a frozen coin must never be spendable".
//     BDK's documented semantics are the opposite: a manually added utxo
//     (`TxBuilder.addUtxos`) overrides the `unspendable` filter, and
//     `BdkWalletDatasource` deliberately preserves those raw semantics
//     (see bdk_wallet_datasource_test.dart, which asserts them). The
//     repository therefore reads the frozen store LIVE at build time and
//     enforces the invariant itself — merging the frozen set into the
//     `unspendable` list (automatic selection can't pick a frozen coin) and
//     rejecting any `selected` list containing a frozen coin (a frozen coin
//     can't be forced in as a mandatory input) — so it holds for ANY caller, with any
//     staleness of the caller's earlier utxo fetch, not only for callers
//     going through PrepareBitcoinSendUsecase's own frozen-set handling.
//     (Payjoin-derived exclusions remain at the usecase: they come from
//     another repository, which this repository must not depend on.)
//
//  2. RBF defaults to ENABLED when the caller omits the flag. The
//     previous `replaceByFee ?? false` was harmless while the datasource's
//     `setExactSequence` call discarded its result (a silent no-op), but
//     became wrong once that call was fixed: a null flag would have
//     started disabling RBF by default, diverging from both the
//     datasource's own default and BDK's default sequence (0xFFFFFFFD).
import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_wallet_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/frozen_wallet_utxo_datasource.dart';
import 'package:bb_mobile/core/wallet/data/datasources/wallet_metadata_datasource.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_transaction_recipient.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/no_spendable_utxo_exception.dart';
import 'package:bb_mobile/core/wallet/domain/selected_inputs_unavailable_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Sats;

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
  late _MockBdkWalletDatasource bdkDatasource;
  late _MockFrozenWalletUtxoDatasource frozenDatasource;
  late BitcoinWalletRepository repository;

  const metadata = WalletMetadataModel(
    id: _walletId,
    masterFingerprint: '73c5da0a',
    xpubFingerprint: 'deadbeef',
    isEncryptedVaultTested: false,
    isPhysicalBackupTested: false,
    xpub: 'tpub-test',
    externalPublicDescriptor: 'wpkh(external)',
    internalPublicDescriptor: 'wpkh(internal)',
    signer: Signer.local,
    isDefault: true,
  );

  setUpAll(() {
    registerFallbackValue(
      const WalletModel.publicBdk(
        id: _walletId,
        externalDescriptor: 'wpkh(external)',
        internalDescriptor: 'wpkh(internal)',
        isTestnet: true,
      ),
    );
    registerFallbackValue(const NetworkFee.relativeSatPerKwu(1000));
    registerFallbackValue(<BitcoinTransactionRecipientModel>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    metadataDatasource = _MockWalletMetadataDatasource();
    bdkDatasource = _MockBdkWalletDatasource();
    frozenDatasource = _MockFrozenWalletUtxoDatasource();
    repository = BitcoinWalletRepository(
      walletMetadataDatasource: metadataDatasource,
      seedDatasource: _MockSeedDatasource(),
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
        recipients: any(named: 'recipients'),
        networkFee: any(named: 'networkFee'),
        unspendable: any(named: 'unspendable'),
        selected: any(named: 'selected'),
        selectedOnly: any(named: 'selectedOnly'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenAnswer((_) async => 'psbt');
  });

  List<WalletUtxoModel>? capturedSelected() =>
      verify(
            () => bdkDatasource.buildPsbt(
              wallet: any(named: 'wallet'),
              recipients: any(named: 'recipients'),
              networkFee: any(named: 'networkFee'),
              unspendable: any(named: 'unspendable'),
              selected: captureAny(named: 'selected'),
              selectedOnly: any(named: 'selectedOnly'),
              replaceByFee: any(named: 'replaceByFee'),
            ),
          ).captured.single
          as List<WalletUtxoModel>?;

  List<({String txId, int vout})>? capturedUnspendable() =>
      verify(
            () => bdkDatasource.buildPsbt(
              wallet: any(named: 'wallet'),
              recipients: any(named: 'recipients'),
              networkFee: any(named: 'networkFee'),
              unspendable: captureAny(named: 'unspendable'),
              selected: any(named: 'selected'),
              selectedOnly: any(named: 'selectedOnly'),
              replaceByFee: any(named: 'replaceByFee'),
            ),
          ).captured.single
          as List<({String txId, int vout})>?;

  bool capturedReplaceByFee() =>
      verify(
            () => bdkDatasource.buildPsbt(
              wallet: any(named: 'wallet'),
              recipients: any(named: 'recipients'),
              networkFee: any(named: 'networkFee'),
              unspendable: any(named: 'unspendable'),
              selected: any(named: 'selected'),
              selectedOnly: any(named: 'selectedOnly'),
              replaceByFee: captureAny(named: 'replaceByFee'),
            ),
          ).captured.single
          as bool;

  Future<void> buildPsbt({
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool selectedOnly = false,
    bool? replaceByFee,
  }) => repository.buildPsbt(
    walletId: _walletId,
    recipients: [
      BitcoinTransactionRecipient.fixed(
        address: 'tb1-destination',
        amountSat: Sats.fromInt(25000),
      ),
    ],
    networkFee: const NetworkFee.relativeSatPerKwu(1000),
    unspendable: unspendable,
    selected: selected,
    selectedOnly: selectedOnly,
    replaceByFee: replaceByFee,
  );

  group('D7 — frozen store is read live at build time', () {
    test('a coin frozen in the store rejects the selection even when '
        'the caller passes NO unspendable list', () async {
      when(() => frozenDatasource.getAllFrozen()).thenAnswer(
        (_) async => [(walletId: _walletId, txId: 'tx-frozen', vout: 0)],
      );

      await expectLater(
        buildPsbt(
          selected: [
            _utxo(txId: 'tx-frozen', vout: 0),
            _utxo(txId: 'tx-free', vout: 1),
          ],
        ),
        throwsA(isA<NoSpendableUtxoException>()),
      );
      verifyNever(
        () => bdkDatasource.buildPsbt(
          wallet: any(named: 'wallet'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          unspendable: any(named: 'unspendable'),
          selected: any(named: 'selected'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      );
    });

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

  group('D7 — selected ∩ unspendable (caller-supplied) is rejected', () {
    test(
      'a selected coin that is also unspendable fails before the datasource',
      () async {
        await expectLater(
          buildPsbt(
            unspendable: const [(txId: 'tx-frozen', vout: 0)],
            selected: [
              _utxo(txId: 'tx-frozen', vout: 0),
              _utxo(txId: 'tx-free', vout: 1),
            ],
          ),
          throwsA(isA<NoSpendableUtxoException>()),
        );
        verifyNever(
          () => bdkDatasource.buildPsbt(
            wallet: any(named: 'wallet'),
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            unspendable: any(named: 'unspendable'),
            selected: any(named: 'selected'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        );
      },
    );

    test('same txId but different vout is NOT stripped', () async {
      await buildPsbt(
        unspendable: const [(txId: 'tx-shared', vout: 0)],
        selected: [_utxo(txId: 'tx-shared', vout: 1)],
      );

      final selected = capturedSelected();
      expect(selected, hasLength(1));
      expect(selected!.single.vout, 1);
    });

    test('selected-only build rejects a live-frozen selected coin', () async {
      when(() => frozenDatasource.getAllFrozen()).thenAnswer(
        (_) async => [(walletId: _walletId, txId: 'tx-frozen', vout: 0)],
      );

      await expectLater(
        buildPsbt(
          selected: [_utxo(txId: 'tx-frozen', vout: 0)],
          selectedOnly: true,
        ),
        throwsA(isA<SelectedInputsUnavailableException>()),
      );
      verifyNever(
        () => bdkDatasource.buildPsbt(
          wallet: any(named: 'wallet'),
          recipients: any(named: 'recipients'),
          networkFee: any(named: 'networkFee'),
          unspendable: any(named: 'unspendable'),
          selected: any(named: 'selected'),
          selectedOnly: any(named: 'selectedOnly'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      );
    });

    test(
      'empty frozen store and no unspendable leaves the selection untouched',
      () async {
        await buildPsbt(
          selected: [
            _utxo(txId: 'tx-a', vout: 0),
            _utxo(txId: 'tx-b', vout: 1),
          ],
        );

        expect(capturedSelected(), hasLength(2));
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

  test('checks all recipient addresses in one datasource call', () async {
    when(
      () => bdkDatasource.areAddressesMine(any(), wallet: any(named: 'wallet')),
    ).thenAnswer((_) async => true);

    expect(
      await repository.areAddressesOfWallet(const [
        'tb1qfirst',
        'tb1qsecond',
      ], walletId: _walletId),
      isTrue,
    );

    verify(() => metadataDatasource.fetch(_walletId)).called(1);
    verify(
      () => bdkDatasource.areAddressesMine(const [
        'tb1qfirst',
        'tb1qsecond',
      ], wallet: any(named: 'wallet')),
    ).called(1);
  });

  test('maps fixed and remainder recipients into datasource models', () async {
    await repository.buildPsbt(
      walletId: _walletId,
      recipients: [
        BitcoinTransactionRecipient.fixed(
          address: 'tb1qfixed',
          amountSat: Sats.fromInt(25000),
        ),
        BitcoinTransactionRecipient.remainder(address: 'tb1qremaining'),
      ],
      networkFee: const NetworkFee.relativeSatPerKwu(1000),
    );

    final recipients =
        verify(
              () => bdkDatasource.buildPsbt(
                wallet: any(named: 'wallet'),
                recipients: captureAny(named: 'recipients'),
                networkFee: any(named: 'networkFee'),
                unspendable: any(named: 'unspendable'),
                selected: any(named: 'selected'),
                selectedOnly: any(named: 'selectedOnly'),
                replaceByFee: any(named: 'replaceByFee'),
              ),
            ).captured.single
            as List<BitcoinTransactionRecipientModel>;
    expect(recipients, hasLength(2));
    expect(recipients[0].address, 'tb1qfixed');
    expect(recipients[0].amountSat, 25000);
    expect(recipients[1].address, 'tb1qremaining');
    expect(recipients[1].amountSat, isNull);
  });

  test('maps final datasource amounts back into Sats', () async {
    when(
      () => bdkDatasource.getRecipientAmounts('psbt', any(), isTestnet: true),
    ).thenAnswer((_) async => [25000, 74000]);
    final recipients = [
      BitcoinTransactionRecipient.fixed(
        address: 'tb1qfixed',
        amountSat: Sats.fromInt(25000),
      ),
      BitcoinTransactionRecipient.remainder(address: 'tb1qremaining'),
    ];

    final amounts = await repository.getRecipientAmounts(
      psbt: 'psbt',
      recipients: recipients,
      walletId: _walletId,
    );

    expect(amounts, [Sats.fromInt(25000), Sats.fromInt(74000)]);
    final models =
        verify(
              () => bdkDatasource.getRecipientAmounts(
                'psbt',
                captureAny(),
                isTestnet: true,
              ),
            ).captured.single
            as List<BitcoinTransactionRecipientModel>;
    expect(models.map((recipient) => recipient.amountSat), [25000, null]);
  });
}
