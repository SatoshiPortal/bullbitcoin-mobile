import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

// Real Dart adapter, scripted native records; no FFI, server or chain.
final class _Wallet implements bark.Wallet {
  /// The fast rate Bark picks when it is given none.
  final int fastRate;
  final calls = <int?>[];
  _Wallet({this.fastRate = 5});

  @override
  Future<List<bark.ExitVtxo>> getExitVtxos() async => [
    bark.ExitVtxo(
      vtxoId: 'v',
      amountSats: 50000,
      isClaimable: false,
      state: bark.ClaimableExitState(
        tipHeight: 100,
        claimableSince: bark.BlockRef(height: 99, hash: 'c' * 64),
        lastScannedBlock: null,
      ),
    ),
  ];

  @override
  Future<bark.EmergencyExitFeeEstimate> estimateEmergencyExitFee({
    required List<String> vtxoIds,
    required int? feeRateSatPerVb,
    required String? destination,
    required double? feeMargin,
  }) async {
    calls.add(feeRateSatPerVb);
    final rate = feeRateSatPerVb ?? fastRate;
    // The claim is cheaper when Bark prices it at its regular rate.
    final claimRate = feeRateSatPerVb ?? 2;
    return bark.EmergencyExitFeeEstimate(
      exitBroadcastFeeSats: 100 * rate,
      claimFeeSats: 10 * claimRate,
      totalFeeSats: 100 * rate + 10 * claimRate,
      feeRateSatPerVb: rate,
      txsToBroadcast: 2,
      fundable: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call');
}

final class _Onchain implements bark.OnchainWallet {
  final int confirmed;
  final int pending;
  _Onchain(this.confirmed, {this.pending = 0});
  @override
  Future<int> sync_() async => 0;
  @override
  Future<bark.OnchainBalance> balance() async => bark.OnchainBalance(
    confirmedSats: confirmed,
    pendingSats: pending,
    totalSats: confirmed + pending,
  );
  @override
  Future<List<bark.OnchainUtxo>> utxos() async => [
    bark.LocalOnchainUtxo(
      outpoint: bark.OutPoint(txid: 'reserve', vout: 0),
      amountSats: confirmed,
      confirmationHeight: 90,
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected onchain call');
}

final class _Stages implements ArkStageRunner {
  @override
  Future<T> run<T>(String name, Future<T> Function() action) => action();
}

void main() {
  final source = Uri.parse('http://localhost:3000');
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final snapshot = ArkSnapshot(
    account: account,
    revision: 1,
    observedAt: DateTime.utc(2026),
    tipHeight: 100,
    spendable: Sats.fromInt(50000),
    vtxos: [
      ArkVtxo(
        id: 'v',
        amount: Sats.fromInt(50000),
        expiryHeight: 200,
        state: ArkVtxoState.spendable,
      ),
    ],
  );
  BarkNativeSession session(
    _Wallet wallet, {
    int reserve = 100000,
    int pending = 0,
  }) => BarkNativeSession(
    wallet,
    _Onchain(reserve, pending: pending),
    _Stages(),
    ArkAccountConfig(
      id: account,
      arkUrl: Uri.parse('http://localhost:3535'),
      primaryEsploraUrl: source,
    ),
  );
  Future<ArkQuote> quote(_Wallet wallet, ArkQuoteRequest request) =>
      session(wallet).estimate(
        snapshot: snapshot,
        request: request,
        id: 'quote',
        chainSource: source,
        configGeneration: 1,
        now: DateTime.utc(2026),
      );

  test('an automatic exit quote records the rate Bark picked', () async {
    final wallet = _Wallet();
    final exit = await quote(
      wallet,
      ArkQuoteRequest.emergencyExit(ids: ['v'], destination: 'bcrt1qdest'),
    );
    // Asked once for Bark's pick, then priced both legs at that rate.
    expect(wallet.calls, [null, 5]);
    expect(exit.feeRate?.satsPerVbyte, 5);
    expect(exit.fee, Sats.fromInt(500));
    expect(exit.claimFee, Sats.fromInt(50));
    // Only the claim fee comes out of the exited amount.
    expect(exit.net, Sats.fromInt(50000 - 50));
    expect(exit.maxClaimFee, Sats.fromInt(100));
  });

  test('a replay with the recorded rate and ceiling prices the same', () async {
    final first = await quote(
      _Wallet(),
      ArkQuoteRequest.emergencyExit(ids: ['v'], destination: 'bcrt1qdest'),
    );
    // The chain moved: Bark would now pick 9 sat/vB on its own.
    final wallet = _Wallet(fastRate: 9);
    final replay = await quote(
      wallet,
      ArkQuoteRequest.emergencyExit(
        ids: ['v'],
        destination: 'bcrt1qdest',
        feeRate: first.feeRate,
        maxClaimFee: first.maxClaimFee,
      ),
    );
    expect(wallet.calls, [5]);
    expect(replay.fee, first.fee);
    expect(replay.claimFee, first.claimFee);
    expect(replay.net, first.net);
    expect(replay.maxClaimFee, first.maxClaimFee);
  });

  test('an estimate without a destination has none to confirm', () async {
    final exit = await quote(
      _Wallet(),
      ArkQuoteRequest.emergencyExit(ids: ['v']),
    );
    expect(exit.destination, isNull);
    expect(exit.claimFee, Sats.fromInt(50));
  });

  test(
    'a reserve below the broadcast fee still quotes, recording it',
    () async {
      final exit = await session(_Wallet(), reserve: 499).estimate(
        snapshot: snapshot,
        request: ArkQuoteRequest.emergencyExit(
          ids: ['v'],
          destination: 'bcrt1qdest',
        ),
        id: 'quote',
        chainSource: source,
        configGeneration: 1,
        now: DateTime.utc(2026),
      );
      // The host tops up the 1 sat shortfall before starting the exit.
      expect(exit.fee, Sats.fromInt(500));
      expect(exit.confirmedReserveExposure, Sats.fromInt(499));
    },
  );

  test(
    'progress short of confirmed reserve waits, saying by how much',
    () async {
      // Fee 500 at Bark's rate; 499 confirmed and 300 on its way.
      await expectLater(
        session(_Wallet(), reserve: 499, pending: 300).estimate(
          snapshot: snapshot,
          request: ArkQuoteRequest.exitProgress(),
          id: 'quote',
          chainSource: source,
          configGeneration: 1,
          now: DateTime.utc(2026),
        ),
        throwsA(
          isA<ArkBoundaryException>().having(
            (e) => e.failure,
            'failure',
            isA<ArkExitFeesShortFailure>()
                .having((f) => f.missing, 'missing', Sats.fromInt(1))
                .having((f) => f.incoming, 'incoming', Sats.fromInt(300)),
          ),
        ),
      );
    },
  );
}
