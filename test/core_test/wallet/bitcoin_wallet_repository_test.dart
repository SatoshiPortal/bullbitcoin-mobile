import 'package:bb_mobile/features/wallet/data/ark_funding_signing_guard.dart';
import 'package:bb_mobile/features/wallet/data/sync_wallet_values_datasource.dart';
import 'package:sync/sync.dart'
    show
        BitcoinSpendStatus,
        SyncFailure,
        SyncStorageFailure,
        SyncProtectedInputsFailure,
        SyncSpendBlockedFailure,
        UnsignedSpend,
        WalletKey,
        WalletRevision;
import 'package:bb_mobile/features/wallet/domain/wallet_spend_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:primitives/primitives.dart' hide Network;

// Unit tests for the repository boundary of
// `BitcoinWalletRepository.buildPsbt`, over a mocked datasource:
//
//  1. Freezes and Payjoin reservations are enforced by sync's writer, which
//     reads them itself and checks the effective inputs of every build (see
//     packages/sync/test/spend). The repository forwards the caller's
//     exclusions and selection unchanged and names sync's refusals.
//
//  2. RBF defaults to ENABLED when the caller omits the flag, matching BDK's
//     default sequence (0xFFFFFFFD).
import 'dart:typed_data';

import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:bb_mobile/features/wallet/data/bdk_wallet_datasource.dart';
import 'package:bb_mobile/features/wallet/data/wallet_metadata_datasource.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_transaction_recipient_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_utxo_model.dart';
import 'package:bb_mobile/features/wallet/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletMetadataDatasource extends Mock
    implements WalletMetadataDatasource {}

class _MockBdkWalletDatasource extends Mock implements BdkWalletDatasource {}

class _MockValues extends Mock implements SyncWalletValuesDatasource {}

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

String _destination([bdk.Network network = bdk.Network.testnet, int fill = 1]) {
  final script = bdk.Script(
    rawOutputScript: Uint8List.fromList([0, 20, ...List.filled(20, fill)]),
  );
  final address = bdk.Address.fromScript(script: script, network: network);
  try {
    return address.toString();
  } finally {
    address.dispose();
    script.dispose();
  }
}

void main() {
  late _MockWalletMetadataDatasource metadataDatasource;
  late _MockBdkWalletDatasource bdkDatasource;
  late _MockValues values;
  late Result<UnsignedSpend, SyncFailure> built;
  late BitcoinWalletRepository repository;

  const metadata = WalletMetadataModel(
    networkCode: 'bitcoinTestnet',
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
    registerFallbackValue(WalletModel.fromMetadata(metadata));
    registerFallbackValue(const NetworkFee.relativeSatPerKwu(1000));
    registerFallbackValue(<BitcoinTransactionRecipientModel>[]);
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    FakeSecureStoragePlatform().install();
    metadataDatasource = _MockWalletMetadataDatasource();
    bdkDatasource = _MockBdkWalletDatasource();
    values = _MockValues();
    built = Ok(
      UnsignedSpend(
        revision: WalletRevision(
          key: WalletKey(id: _walletId, network: BitcoinNetwork.testnet),
          generation: 1,
          revision: 1,
        ),
        encoded: 'psbt',
        inputs: const [],
      ),
    );
    repository = BitcoinWalletRepository(
      arkFundingGuard: const ArkFundingSigningGuard(Err(SyncStorageFailure())),
      walletMetadataDatasource: metadataDatasource,
      // `Secrets` is final: the seam is the keystore below it, installed in `setUp`. No secret is stored — these cases never reach one.
      secrets: Secrets(scratchDirectory: () async => '/tmp'),
      bdkWalletDatasource: bdkDatasource,
      walletValuesDatasource: values,
    );

    when(() => metadataDatasource.fetch(_walletId))
        .thenAnswer((_) async => metadata);
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
    ).thenAnswer((_) async => built);
  });

  test(
    'rejects a destination from another network before native building',
    () async {
      await expectLater(
        repository.buildPsbt(
          walletId: _walletId,
          recipients: [
            BitcoinTransactionRecipient.fixed(
              address: _destination(bdk.Network.bitcoin),
              amountSat: Sats.fromInt(10000),
            ),
          ],
          networkFee: const NetworkFee.relativeSatPerKwu(1000),
        ),
        completion(
          isA<Err<String, WalletFailure>>().having(
            (result) => result.failure,
            'failure',
            isA<WalletAddressNetworkMismatchFailure>(),
          ),
        ),
      );
      verifyZeroInteractions(bdkDatasource);
    },
  );

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

  Future<Result<String, WalletFailure>> buildPsbt({
    List<({String txId, int vout})>? unspendable,
    List<WalletUtxo>? selected,
    bool selectedOnly = false,
    bool? replaceByFee,
  }) => repository.buildPsbt(
    walletId: _walletId,
    recipients: [
      BitcoinTransactionRecipient.fixed(
        address: _destination(),
        amountSat: Sats.fromInt(25000),
      ),
    ],
    networkFee: const NetworkFee.relativeSatPerKwu(1000),
    unspendable: unspendable,
    selected: selected,
    selectedOnly: selectedOnly,
    replaceByFee: replaceByFee,
  );

  group('protections are sync\'s', () {
    test(
      'the caller\'s exclusions and selection are forwarded unchanged',
      () async {
        await buildPsbt(
          unspendable: const [(txId: 'tx-caller', vout: 3)],
          selected: [_utxo(txId: 'tx-caller', vout: 3)],
        );

        final captured = verify(
          () => bdkDatasource.buildPsbt(
            wallet: any(named: 'wallet'),
            recipients: any(named: 'recipients'),
            networkFee: any(named: 'networkFee'),
            unspendable: captureAny(named: 'unspendable'),
            selected: captureAny(named: 'selected'),
            selectedOnly: any(named: 'selectedOnly'),
            replaceByFee: any(named: 'replaceByFee'),
          ),
        ).captured;
        expect(captured.first, [(txId: 'tx-caller', vout: 3)]);
        expect(
          (captured.last as List<WalletUtxoModel>).single.txId,
          'tx-caller',
        );
      },
    );

    test(
      'a protected selected coin reads as an unavailable selection',
      () async {
        built = Err(
          SyncProtectedInputsFailure(frozen: {(txId: 'tx-frozen', vout: 0)}),
        );
        expect(
          await buildPsbt(selected: [_utxo(txId: 'tx-frozen', vout: 0)]),
          isA<Err<String, WalletFailure>>().having(
            (error) => error.failure,
            'failure',
            isA<WalletSelectedInputsUnavailableFailure>(),
          ),
        );
      },
    );

    test('without a selection, no spendable input remains', () async {
      built = Err(SyncProtectedInputsFailure());
      expect(
        await buildPsbt(),
        isA<Err<String, WalletFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<WalletNoSpendableInputsFailure>(),
        ),
      );
    });

    test('the guard\'s refusal stays an exception the caller names', () async {
      built = const Err(SyncSpendBlockedFailure(BitcoinSpendStatus.pending));
      await expectLater(
        buildPsbt(),
        throwsA(
          isA<WalletSpendBlockedException>().having(
            (error) => error.status,
            'status',
            BitcoinSpendStatus.pending,
          ),
        ),
      );
    });

    test('an empty selected-only build is refused before sync', () async {
      expect(
        await buildPsbt(selected: const [], selectedOnly: true),
        isA<Err<String, WalletFailure>>().having(
          (error) => error.failure,
          'failure',
          isA<WalletSelectedInputsUnavailableFailure>(),
        ),
      );
      verifyZeroInteractions(bdkDatasource);
    });
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
    when(() => values.areAddressesMine(any(), wallet: any(named: 'wallet')))
        .thenAnswer((_) async => true);

    expect(
      await repository.areAddressesOfWallet(const [
        'tb1qfirst',
        'tb1qsecond',
      ], walletId: _walletId),
      isTrue,
    );

    verify(() => metadataDatasource.fetch(_walletId)).called(1);
    verify(
      () => values.areAddressesMine(const [
        'tb1qfirst',
        'tb1qsecond',
      ], wallet: any(named: 'wallet')),
    ).called(1);
  });

  test('maps fixed and remainder recipients into datasource models', () async {
    final fixed = _destination();
    final remaining = _destination(bdk.Network.testnet, 2);
    expect(
      await repository.buildPsbt(
        walletId: _walletId,
        recipients: [
          BitcoinTransactionRecipient.fixed(
            address: fixed,
            amountSat: Sats.fromInt(25000),
          ),
          BitcoinTransactionRecipient.remainder(address: remaining),
        ],
        networkFee: const NetworkFee.relativeSatPerKwu(1000),
      ),
      isA<Ok<String, WalletFailure>>(),
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
    expect(recipients[0].address, fixed);
    expect(recipients[0].amountSat, 25000);
    expect(recipients[1].address, remaining);
    expect(recipients[1].amountSat, isNull);
  });

  test('maps final datasource amounts back into Sats', () async {
    when(
      () => bdkDatasource.getRecipientAmounts(
        'psbt',
        any(),
        network: Network.bitcoinTestnet,
      ),
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
                network: Network.bitcoinTestnet,
              ),
            ).captured.single
            as List<BitcoinTransactionRecipientModel>;
    expect(models.map((recipient) => recipient.amountSat), [25000, null]);
  });
}
