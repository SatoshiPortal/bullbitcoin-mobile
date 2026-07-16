import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:flutter_test/flutter_test.dart';

PayjoinReceiver _receiver({
  required PayjoinStatus status,
  String? txId,
  String? proposalPsbt,
}) =>
    Payjoin.receiver(
          status: status,
          id: 'pj1',
          isTestnet: true,
          walletId: 'w1',
          pjUri: 'bitcoin:tb1qtest?pj=https://payjo.in',
          createdAt: DateTime(2026),
          expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
          txId: txId,
          proposalPsbt: proposalPsbt,
        )
        as PayjoinReceiver;

PayjoinSender _sender({
  required PayjoinStatus status,
  String? txId,
  String? proposalPsbt,
}) =>
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
          proposalPsbt: proposalPsbt,
        )
        as PayjoinSender;

void main() {
  group('Payjoin.isCompleted', () {
    test('true for a real payjoin completion', () {
      expect(_receiver(status: PayjoinStatus.completed).isCompleted, isTrue);
      expect(_sender(status: PayjoinStatus.completed).isCompleted, isTrue);
    });

    test('true for a plain-broadcast fallback completion too — both mean '
        '"money moved, nothing left to do here"', () {
      expect(_receiver(status: PayjoinStatus.aborted).isCompleted, isTrue);
      expect(_sender(status: PayjoinStatus.aborted).isCompleted, isTrue);
    });

    test('false while ongoing or expired', () {
      expect(_receiver(status: PayjoinStatus.requested).isCompleted, isFalse);
      expect(_receiver(status: PayjoinStatus.proposed).isCompleted, isFalse);
      expect(_receiver(status: PayjoinStatus.expired).isCompleted, isFalse);
    });
  });

  group('Payjoin.isOngoing', () {
    test('false once resolved via fallback, same as a real completion', () {
      expect(_receiver(status: PayjoinStatus.aborted).isOngoing, isFalse);
      expect(_sender(status: PayjoinStatus.aborted).isOngoing, isFalse);
    });
  });

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

    test('false when completed via the plain-broadcast fallback '
        '(PayjoinStatus.aborted, not completed)', () {
      expect(
        _receiver(status: PayjoinStatus.aborted).isRealPayjoinCompletion,
        isFalse,
      );
      expect(
        _sender(status: PayjoinStatus.aborted).isRealPayjoinCompletion,
        isFalse,
      );
    });

    test('true only when the status is completed — fallback is a distinct '
        'status, so this no longer needs to also check txId', () {
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

  group('Payjoin.canManuallyBroadcastOriginal', () {
    test('receiver: true while waiting (no proposal ever sent)', () {
      expect(
        _receiver(status: PayjoinStatus.requested).canManuallyBroadcastOriginal,
        isTrue,
      );
    });

    test('receiver: false once a proposal is sent — the sender owns it for '
        'as long as that takes, with no dead-end that would ever need a '
        'manual retry', () {
      expect(
        _receiver(
          status: PayjoinStatus.proposed,
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        ).canManuallyBroadcastOriginal,
        isFalse,
      );
      // Still false even once the receiver's OWN session expires waiting —
      // the broadcast watcher stays armed indefinitely on the sender's
      // behalf (see PayjoinRepositoryImpl._processExpiredPayjoin).
      expect(
        _receiver(
          status: PayjoinStatus.expired,
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        ).canManuallyBroadcastOriginal,
        isFalse,
      );
    });

    test('receiver: false once completed, real payjoin or fallback alike', () {
      expect(
        _receiver(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ).canManuallyBroadcastOriginal,
        isFalse,
      );
      expect(
        _receiver(status: PayjoinStatus.aborted).canManuallyBroadcastOriginal,
        isFalse,
      );
    });

    test('sender: true while waiting (no proposal ever received)', () {
      expect(
        _sender(status: PayjoinStatus.requested).canManuallyBroadcastOriginal,
        isTrue,
      );
    });

    test('sender: false while a proposal is being actively processed '
        '(received, not yet completed or expired)', () {
      expect(
        _sender(
          status: PayjoinStatus.proposed,
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        ).canManuallyBroadcastOriginal,
        isFalse,
      );
    });

    test('sender: false once completed, real payjoin or fallback alike', () {
      expect(
        _sender(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ).canManuallyBroadcastOriginal,
        isFalse,
      );
      expect(
        _sender(status: PayjoinStatus.aborted).canManuallyBroadcastOriginal,
        isFalse,
      );
    });

    test('sender: true once its OWN internal fallback also gave up '
        '(expired, proposalPsbt still set) — no dead-end left, a manual '
        'retry must still be possible', () {
      expect(
        _sender(
          status: PayjoinStatus.expired,
          proposalPsbt: 'cHNidP9wcm9wb3NhbA==',
        ).canManuallyBroadcastOriginal,
        isTrue,
      );
    });
  });
}
