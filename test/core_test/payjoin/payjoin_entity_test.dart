import 'dart:typed_data';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:flutter_test/flutter_test.dart';

final _defaultOriginalTxBytes = Uint8List.fromList([1, 2, 3]);

PayjoinReceiver _receiver({
  required PayjoinStatus status,
  String? txId,
  String? proposalPsbt,
  // Defaults to a non-null value: once a request has been received the
  //  receiver holds the sender's original transaction, which
  //  canManuallyBroadcastOriginal requires. Pass Uint8List(0)-equivalent
  //  null via [noOriginalTxBytes] for the `started` (no request yet) case.
  Uint8List? originalTxBytes,
  bool noOriginalTxBytes = false,
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
          originalTxBytes: noOriginalTxBytes
              ? null
              : (originalTxBytes ?? _defaultOriginalTxBytes),
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
  group('Payjoin.isCompleted/isAborted/isExpired/isOngoing', () {
    Payjoin buildReceiver(PayjoinStatus status) => Payjoin.receiver(
      status: status,
      id: 'r1',
      isTestnet: true,
      walletId: 'w1',
      pjUri: 'bitcoin:addr?pj=https://payjo.in/x',
      createdAt: DateTime(2026),
      expiresAt: DateTime(2026, 1, 2),
    );

    test('completed', () {
      final p = buildReceiver(PayjoinStatus.completed);
      expect(p.isCompleted, isTrue);
      expect(p.isAborted, isFalse);
      expect(p.isExpired, isFalse);
      expect(p.isOngoing, isFalse);
    });

    test(
      'aborted — the payjoin did not happen, WE broadcast the original tx',
      () {
        final p = buildReceiver(PayjoinStatus.aborted);
        expect(p.isCompleted, isFalse);
        expect(p.isAborted, isTrue);
        expect(p.isExpired, isFalse);
        expect(
          p.isOngoing,
          isFalse,
          reason: 'aborted is terminal, exactly like completed/expired',
        );
      },
    );

    test('expired — nothing broadcast by us', () {
      final p = buildReceiver(PayjoinStatus.expired);
      expect(p.isCompleted, isFalse);
      expect(p.isAborted, isFalse);
      expect(p.isExpired, isTrue);
      expect(p.isOngoing, isFalse);
    });

    test('requested/proposed are ongoing', () {
      expect(buildReceiver(PayjoinStatus.requested).isOngoing, isTrue);
      expect(buildReceiver(PayjoinStatus.proposed).isOngoing, isTrue);
    });
  });

  group('Payjoin.canManuallyBroadcastOriginal', () {
    test('receiver: true while waiting (request received, no proposal '
        'sent)', () {
      expect(
        _receiver(status: PayjoinStatus.requested).canManuallyBroadcastOriginal,
        isTrue,
      );
    });

    test('receiver: false while still started — no original tx to broadcast '
        'yet (no request received)', () {
      expect(
        _receiver(
          status: PayjoinStatus.started,
          noOriginalTxBytes: true,
        ).canManuallyBroadcastOriginal,
        isFalse,
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
    });

    test('receiver: false once completed (real payjoin)', () {
      expect(
        _receiver(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ).canManuallyBroadcastOriginal,
        isFalse,
      );
    });

    test('receiver: false once aborted (fallback already broadcast)', () {
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

    test('sender: false once completed (real payjoin)', () {
      expect(
        _sender(
          status: PayjoinStatus.completed,
          txId: 'payjoin-txid',
        ).canManuallyBroadcastOriginal,
        isFalse,
      );
    });

    test('sender: false once aborted (fallback already broadcast)', () {
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

  group('Payjoin.logRef', () {
    test('a receiver id passes through unchanged', () {
      // A receiver id is already an opaque sha256 prefix of the pjUri, so it
      // is safe to log verbatim and stays stable across restarts.
      expect(_receiver(status: PayjoinStatus.requested).logRef, 'pj1');
    });

    test('a sender logRef is a 16-char lowercase hex hash and never leaks '
        'the BIP21 uri (which carries the address/amount/endpoint)', () {
      final sender = _sender(status: PayjoinStatus.requested);

      expect(sender.logRef, matches(RegExp(r'^[0-9a-f]{16}$')));
      // The raw address must never appear in the log-safe reference.
      expect(sender.logRef, isNot(contains('tb1qsender')));
      expect(sender.logRef, isNot(equals(sender.id)));
    });
  });
}
