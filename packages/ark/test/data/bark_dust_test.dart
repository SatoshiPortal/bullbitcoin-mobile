import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

// Real Dart adapter, scripted native records; no FFI, server or invoice decode.
final class _Wallet implements bark.Wallet {
  final int net;
  int invoiceCalls = 0;
  _Wallet(this.net);
  bark.FeeEstimate fee(List<String> ids) => bark.FeeEstimate(
    grossAmountSats: net + 10,
    feeSats: 10,
    netAmountSats: net,
    vtxosSpent: ids,
  );
  @override
  Future<bark.PaymentRequest> parsePaymentRequest({
    required String payment,
  }) async => bark.PaymentRequest(
    options: [
      bark.AvailablePaymentMethod(
        method: payment == 'ark'
            ? bark.ArkPaymentMethod(payment)
            : bark.BitcoinPaymentMethod(payment),
        errors: [],
        requiresAmount: true,
      ),
    ],
  );
  @override
  Future<bark.FeeEstimate> estimatePaymentFee({
    required bark.PaymentMethod method,
    required int amountSats,
  }) async => fee(['v']);
  @override
  Future<bark.FeeEstimate> estimateBoardFee({required int amountSats}) async =>
      fee([]);
  @override
  Future<bark.FeeEstimate> estimateRefreshFee({
    required List<String> vtxoIds,
  }) async => fee(vtxoIds);
  @override
  Future<bark.FeeEstimate> estimateLightningReceiveFee({
    required int amountSats,
  }) async => fee([]);
  @override
  Future<bark.LightningInvoice> bolt11Invoice({
    required int amountSats,
    required String? description,
    required String? token,
    required int? expirySecs,
  }) async {
    invoiceCalls++;
    throw const _InvoiceStageReached();
  }

  @override
  Future<int> nextRoundStartTime() async => 1795089600;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call');
}

final class _InvoiceStageReached implements Exception {
  const _InvoiceStageReached();
}

final class _Onchain implements bark.OnchainWallet {
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
    spendable: Sats.fromInt(1000),
    serverInfo: ArkServerInfo(publicKey: 'key', minimumBoard: Sats.fromInt(1)),
    vtxos: [
      ArkVtxo(
        id: 'v',
        amount: Sats.fromInt(1000),
        expiryHeight: 200,
        state: ArkVtxoState.spendable,
      ),
    ],
  );
  BarkNativeSession session(_Wallet wallet) => BarkNativeSession(
    wallet,
    _Onchain(),
    _Stages(),
    ArkAccountConfig(
      id: account,
      arkUrl: Uri.parse('http://localhost:3535'),
      primaryEsploraUrl: source,
    ),
  );
  final dust = isA<ArkBoundaryException>().having(
    (e) => e.failure,
    'fixed dust reason',
    isA<ArkValidationFailure>().having(
      (f) => f.reason,
      'reason',
      ArkFailureReason.dust,
    ),
  );
  for (final kind in ['board', 'renewal', 'ark', 'bitcoin']) {
    for (final net in [329, 330]) {
      test('$kind validates Ark output at dust boundary $net', () async {
        final native = session(_Wallet(net));
        final result = native.estimate(
          snapshot: snapshot,
          request: kind == 'board'
              ? ArkQuoteRequest.board(amount: Sats.fromInt(net + 10))
              : kind == 'renewal'
              ? ArkQuoteRequest.renewal(ids: ['v'])
              : ArkQuoteRequest.payment(
                  destination: ArkPaymentDestination(
                    kind: kind == 'ark'
                        ? ArkDestinationKind.ark
                        : ArkDestinationKind.bitcoin,
                    value: kind,
                  ),
                  amount: Sats.fromInt(net),
                ),
          id: 'quote',
          chainSource: source,
          configGeneration: 1,
          now: DateTime.utc(2026),
        );
        if (net < 330 && kind != 'bitcoin') {
          await expectLater(result, throwsA(dust));
        } else {
          expect((await result).net, Sats.fromInt(net));
        }
      });
    }
  }
  for (final net in [329, 330]) {
    test(
      'lightning receive guards net before invoice creation at $net',
      () async {
        final wallet = _Wallet(net);
        final result = session(wallet)
            .receive(ArkReceiveRequest.bolt11(amount: Sats.fromInt(net + 10)));
        // At the boundary the next native stage is reached, not a claim that a
        // scripted handle completed an actual invoice or native decode.
        await expectLater(
          result,
          throwsA(net < 330 ? dust : isA<_InvoiceStageReached>()),
        );
        expect(wallet.invoiceCalls, net < 330 ? 0 : 1);
      },
    );
  }
  test('next round start is the server time in unix seconds, as UTC', () async {
    expect(
      await session(_Wallet(1000)).nextRoundStart(),
      DateTime.utc(2026, 11, 19, 12),
    );
  });
}
