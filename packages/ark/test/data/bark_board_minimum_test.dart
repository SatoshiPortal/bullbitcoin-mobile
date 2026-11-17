import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

// Real adapter estimation with scripted records; no FFI or network call.
final class Wallet implements bark.Wallet {
  int estimates = 0;
  @override
  Future<bark.FeeEstimate> estimateBoardFee({required int amountSats}) async {
    estimates++;
    return bark.FeeEstimate(
      grossAmountSats: amountSats,
      feeSats: 330,
      netAmountSats: amountSats - 330,
      vtxosSpent: [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected wallet call');
}

final class Onchain implements bark.OnchainWallet {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected onchain call');
}

final class Stages implements ArkStageRunner {
  @override
  Future<T> run<T>(String name, Future<T> Function() action) => action();
}

final class Rig {
  final wallet = Wallet();
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  Future<ArkQuote> quote(
    int amount, {
    int minimum = 20000,
    bool server = true,
  }) =>
      BarkNativeSession(
        wallet,
        Onchain(),
        Stages(),
        ArkAccountConfig(
          id: account,
          arkUrl: Uri.parse('http://localhost:3535'),
          primaryEsploraUrl: Uri.parse('http://localhost:3000'),
        ),
      ).estimate(
        snapshot: ArkSnapshot(
          account: account,
          revision: 1,
          observedAt: DateTime.utc(2026),
          tipHeight: 100,
          recovery: ArkRecoveryStatus.complete,
          serverInfo: server
              ? ArkServerInfo(
                  publicKey: 'server',
                  minimumBoard: Sats.fromInt(minimum),
                )
              : null,
        ),
        request: ArkQuoteRequest.board(amount: Sats.fromInt(amount)),
        id: 'quote',
        chainSource: Uri.parse('http://localhost:3000'),
        configGeneration: 1,
        now: DateTime.utc(2026),
      );
}

void main() {
  test(
    'under-minimum Board returns its typed server minimum before estimating',
    () async {
      final r = Rig();
      await expectLater(
        r.quote(19999),
        throwsA(
          isA<ArkBoundaryException>().having(
            (e) => e.failure,
            'failure',
            isA<ArkValidationFailure>()
                .having(
                  (f) => f.reason,
                  'reason',
                  ArkFailureReason.belowMinimum,
                )
                .having((f) => f.minimum, 'minimum', Sats.fromInt(20000)),
          ),
        ),
      );
      expect(r.wallet.estimates, 0);
    },
  );
  test(
    'minimum value follows the observed server rather than a fixed amount',
    () async {
      final r = Rig();
      await expectLater(
        r.quote(20000, minimum: 25000),
        throwsA(
          isA<ArkBoundaryException>().having(
            (e) => e.failure,
            'failure',
            isA<ArkValidationFailure>().having(
              (f) => f.minimum,
              'minimum',
              Sats.fromInt(25000),
            ),
          ),
        ),
      );
      expect(r.wallet.estimates, 0);
    },
  );
  test(
    'the exact minimum is estimated normally with its separate offchain fee',
    () async {
      final r = Rig();
      final quote = await r.quote(20000);
      expect(quote.amount, Sats.fromInt(20000));
      expect(quote.fee, Sats.fromInt(330));
      expect(quote.net, Sats.fromInt(19670));
      expect(r.wallet.estimates, 1);
    },
  );
  test('absent server information does not invent a minimum', () async {
    final r = Rig();
    await expectLater(
      r.quote(10000, server: false),
      throwsA(
        isA<ArkBoundaryException>().having(
          (e) => e.failure,
          'failure',
          isA<ArkValidationFailure>()
              .having((f) => f.reason, 'reason', ArkFailureReason.validation)
              .having((f) => f.minimum, 'minimum', isNull),
        ),
      ),
    );
    expect(r.wallet.estimates, 0);
  });
}
