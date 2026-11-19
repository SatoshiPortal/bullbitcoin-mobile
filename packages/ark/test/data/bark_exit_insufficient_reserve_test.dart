import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import 'bark_board_minimum_test.dart' show Stages;

// Scripted public records exercise the real adapter comparison, never FFI.
final class Wallet implements bark.Wallet {
  int estimates = 0;
  @override
  Future<bark.EmergencyExitFeeEstimate> estimateEmergencyExitFee({
    required List<String> vtxoIds,
    required int? feeRateSatPerVb,
    required String? destination,
    required double? feeMargin,
  }) async {
    estimates++;
    expect(vtxoIds, ['v']);
    expect(feeRateSatPerVb, 2);
    expect(destination, 'bcrt1-return');
    return bark.EmergencyExitFeeEstimate(
      exitBroadcastFeeSats: 600,
      claimFeeSats: 300,
      totalFeeSats: 900,
      feeRateSatPerVb: 2,
      txsToBroadcast: 1,
      fundable: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected wallet call');
}

final class Onchain implements bark.OnchainWallet {
  final int confirmed;
  int syncs = 0, reads = 0;
  Onchain(this.confirmed);
  @override
  Future<int> sync_() async {
    syncs++;
    return 100;
  }

  @override
  Future<bark.OnchainBalance> balance() async {
    reads++;
    return bark.OnchainBalance(
      confirmedSats: confirmed,
      pendingSats: 100000,
      totalSats: confirmed + 100000,
    );
  }

  @override
  Future<List<bark.OnchainUtxo>> utxos() async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected onchain call');
}

Future<ArkQuote> quote(Wallet wallet, Onchain onchain) {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final config = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('http://localhost:3535'),
    primaryEsploraUrl: Uri.parse('http://localhost:3000'),
  );
  return BarkNativeSession(wallet, onchain, Stages(), config).estimate(
    snapshot: ArkSnapshot(
      account: account,
      revision: 1,
      observedAt: DateTime.utc(2026),
      tipHeight: 100,
      recovery: ArkRecoveryStatus.complete,
      vtxos: [
        ArkVtxo(
          id: 'v',
          amount: Sats.fromInt(2000),
          expiryHeight: 200,
          state: ArkVtxoState.spendable,
        ),
      ],
    ),
    request: ArkQuoteRequest.emergencyExit(
      ids: ['v'],
      destination: 'bcrt1-return',
      feeRate: FeeRate(2),
      maxClaimFee: Sats.fromInt(500),
    ),
    id: 'quote',
    chainSource: config.primaryEsploraUrl,
    configGeneration: 1,
    now: DateTime.utc(2026),
  );
}

void main() {
  test(
    'actual reserve comparison rejects below total fee despite pending funds',
    () async {
      final wallet = Wallet(), onchain = Onchain(899);
      await expectLater(
        quote(wallet, onchain),
        throwsA(
          isA<ArkBoundaryException>().having(
            (error) => error.failure,
            'typed failure',
            isA<ArkInsufficientFundsFailure>(),
          ),
        ),
      );
      expect([wallet.estimates, onchain.syncs, onchain.reads], [1, 1, 1]);
    },
  );
  for (final reserve in [900, 901]) {
    test(
      'actual quote accepts confirmed reserve $reserve at or above total fee',
      () async {
        final wallet = Wallet(), onchain = Onchain(reserve);
        final result = await quote(wallet, onchain);
        expect(result.kind, ArkOperationKind.emergencyExit);
        expect(result.amount, Sats.fromInt(2000));
        expect(result.fee, Sats.fromInt(900));
        expect(result.net, Sats.fromInt(1100));
        expect(result.confirmedReserveExposure, Sats.fromInt(reserve));
        expect(result.maxClaimFee, Sats.fromInt(500));
        expect(result.selectedIds, ['v']);
        expect([wallet.estimates, onchain.syncs, onchain.reads], [1, 1, 1]);
      },
    );
  }
}
