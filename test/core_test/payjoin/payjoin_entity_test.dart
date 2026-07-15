import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:flutter_test/flutter_test.dart';

PayjoinReceiver _receiver({required PayjoinStatus status, String? txId}) =>
    Payjoin.receiver(
          status: status,
          id: 'pj1',
          isTestnet: true,
          walletId: 'w1',
          pjUri: 'bitcoin:tb1qtest?pj=https://payjo.in',
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          txId: txId,
        )
        as PayjoinReceiver;

PayjoinSender _sender({required PayjoinStatus status, String? txId}) =>
    Payjoin.sender(
          status: status,
          uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
          isTestnet: true,
          walletId: 'w1',
          originalPsbt: 'cHNidP8=',
          originalTxId: 'orig-txid',
          amountSat: 50000,
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          txId: txId,
        )
        as PayjoinSender;

void main() {
  group('Payjoin.isRealPayjoinCompletion', () {
    test('false while ongoing (requested/proposed), even with a txId set '
        '(the receiver anticipates its own txid before broadcast)', () {
      expect(
        _receiver(
          status: PayjoinStatus.requested,
          txId: 'anticipated-txid',
        ).isRealPayjoinCompletion,
        isFalse,
      );
      expect(
        _receiver(
          status: PayjoinStatus.proposed,
          txId: 'anticipated-txid',
        ).isRealPayjoinCompletion,
        isFalse,
      );
    });

    test('false when expired', () {
      expect(
        _receiver(
          status: PayjoinStatus.expired,
          txId: 'stale-txid',
        ).isRealPayjoinCompletion,
        isFalse,
      );
    });

    test('false when completed via the plain-broadcast fallback (no txid — '
        'tryBroadcastOriginalTransaction always clears it)', () {
      expect(
        _receiver(status: PayjoinStatus.completed).isRealPayjoinCompletion,
        isFalse,
      );
      expect(
        _sender(status: PayjoinStatus.completed).isRealPayjoinCompletion,
        isFalse,
      );
    });

    test('true only when completed AND a payjoin txid survived — the real '
        'payjoin transaction was broadcast', () {
      expect(
        _receiver(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ).isRealPayjoinCompletion,
        isTrue,
      );
      expect(
        _sender(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ).isRealPayjoinCompletion,
        isTrue,
      );
    });
  });
}
