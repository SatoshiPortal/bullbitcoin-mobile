import 'package:bull_ark/ark_wallet_setup.dart';
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
import 'package:bb_mobile/features/send/domain/wallet_spend_failure.dart';
import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
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

import 'package:fees/fees.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:bb_mobile/core/storage/tables/wallet_metadata_table.dart';
import 'package:sync/sync.dart' as sync;
import 'package:sync/testing.dart';
import 'package:bb_mobile/features/wallet/data/wallet_registrations.dart';
import 'package:bb_mobile/features/wallet/data/models/wallet_metadata_model.dart';
import 'package:bb_mobile/features/send/data/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/features/coins/domain/wallet_utxo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRegistrations extends Mock implements WalletRegistrations {}

class _Spender extends Mock implements WalletSpender {}

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
  late _MockWalletRegistrations metadataDatasource;
  late _Spender spender;
  late sync.Wallet wallet;
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
    registerFallbackValue(const NetworkFee.relativeSatPerKwu(1000));
    registerFallbackValue(<String>[]);
  });

  setUpAll(() {
    registerFallbackValue(
      WalletKey(id: _walletId, network: BitcoinNetwork.testnet),
    );
    registerFallbackValue(
      sync.BitcoinSpendRequest(
        recipients: [sync.SpendRecipient('address', amountSat: 1)],
        fee: sync.SpendAbsoluteFee(1),
      ),
    );
  });

  setUp(() async {
    FakeSecureStoragePlatform().install();
    metadataDatasource = _MockWalletRegistrations();
    spender = _Spender();
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
    wallet = await testWallet(
      key: WalletKey(id: _walletId, network: BitcoinNetwork.testnet),
      spender: spender,
    );
    repository = BitcoinWalletRepository(
      arkFundingGuard: const ArkFundingSigningGuard(Err(SyncStorageFailure())),
      walletRegistrations: metadataDatasource,
      // `Secrets` is final: the seam is the keystore below it, installed in `setUp`. No secret is stored — these cases never reach one.
      secrets: Secrets(scratchDirectory: () async => '/tmp'),
      wallet: (_) async => Ok(wallet),
      walletValuesDatasource: values,
    );

    when(() => metadataDatasource.fetch(_walletId))
        .thenAnswer((_) async => metadata);
    when(() => spender.build(any(), any(), any()))
        .thenAnswer((_) async => built);
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
      verifyZeroInteractions(spender);
    },
  );

  bool capturedReplaceByFee() =>
      (verify(() => spender.build(any(), any(), captureAny())).captured.single
              as sync.BitcoinSpendRequest)
          .replaceable;

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

        final request =
            verify(() => spender.build(any(), any(), captureAny()))
                    .captured
                    .single
                as sync.BitcoinSpendRequest;
        expect(request.exclude, {(txId: 'tx-caller', vout: 3)});
        expect(request.selected, [(txId: 'tx-caller', vout: 3)]);
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
      verifyZeroInteractions(spender);
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
    when(() => values.areAddressesMine(any(), key: any(named: 'key')))
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
      ], key: any(named: 'key')),
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
        (verify(() => spender.build(any(), any(), captureAny())).captured.single
                as sync.BitcoinSpendRequest)
            .recipients;
    expect(recipients, hasLength(2));
    expect(recipients[0].address, fixed);
    expect(recipients[0].amountSat, 25000);
    expect(recipients[1].address, remaining);
    expect(recipients[1].amountSat, isNull);
  });
  test('maps PSBT recipient amounts to Sats', () async {
    // One 100000-sat output pays the 0x22 witness program.
    const psbt =
        'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
        'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
        'MzMzMzMzMzMzMzMzMzMzMzMAAA==';
    final address = _destination(bdk.Network.testnet, 0x22);
    final amounts = await repository.getRecipientAmounts(
      psbt: psbt,
      recipients: [
        BitcoinTransactionRecipient.fixed(
          address: address,
          amountSat: Sats.fromInt(25000),
        ),
        BitcoinTransactionRecipient.remainder(address: address),
      ],
      walletId: _walletId,
    );
    expect(amounts, [Sats.fromInt(25000), Sats.fromInt(75000)]);
  });
}
