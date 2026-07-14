import 'dart:convert';

import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/utils/log_redaction.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('logSafeToken', () {
    const txid =
        '5f1fabc488e1df397e90114374277f2edfa7613fec96769f22d7aa828142709c';

    test('is 8 hex chars and never contains the input', () {
      final token = logSafeToken(txid);
      expect(token, hasLength(8));
      expect(token, matches(RegExp(r'^[0-9a-f]{8}$')));
      expect(txid, isNot(contains(token)));
    });

    test('is stable within a process run', () {
      expect(logSafeToken(txid), logSafeToken(txid));
    });

    test('differs across values', () {
      expect(logSafeToken(txid), isNot(logSafeToken('other')));
    });

    test('is salted: differs from the unsalted sha256 prefix', () {
      // Guards the anti-rainbow property: hashing the raw value without the
      // per-process salt must NOT reproduce the token, otherwise a log
      // reader could hash every on-chain txid and match.
      final unsalted = sha256
          .convert(utf8.encode(txid))
          .toString()
          .substring(0, 8);
      expect(logSafeToken(txid), isNot(unsalted));
    });

    test('handles null and empty without throwing', () {
      expect(logSafeToken(null), '<none>');
      expect(logSafeToken(''), '<none>');
    });
  });

  group('Payjoin.logRef', () {
    final receiver = Payjoin.receiver(
      id: 'ab12cd34ef56ab78',
      isTestnet: false,
      walletId: 'wallet-1',
      pjUri: 'bitcoin:bc1qexample?pj=https://payjo.in/abc',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    final sender = Payjoin.sender(
      uri:
          'bitcoin:bc1qcfmrdwhrl9fjkrlhu8czqaqjtx0gd360rq86kl'
          '?amount=0.00011&pjos=0&pj=HTTPS://PAYJO.IN/ALS0SPTQFH6XU',
      isTestnet: false,
      walletId: 'wallet-1',
      originalPsbt: 'cHNidP8BA==',
      originalTxId:
          '5f1fabc488e1df397e90114374277f2edfa7613fec96769f22d7aa828142709c',
      amountSat: 11000,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: DateTime.fromMillisecondsSinceEpoch(1000),
    );

    test('receiver id passes through unchanged (already opaque)', () {
      expect(receiver.logRef, 'ab12cd34ef56ab78');
    });

    test('sender logRef never exposes the BIP21 URI', () {
      final ref = sender.logRef;
      expect(ref, hasLength(16));
      expect(ref, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(ref, isNot(contains('bc1q')));
      expect(sender.id, contains('bc1q')); // the id itself IS the URI
    });

    test('sender logRef is stable across instances (resume correlation)', () {
      final resumed = Payjoin.sender(
        uri: (sender as PayjoinSender).uri,
        isTestnet: false,
        walletId: 'wallet-2',
        originalPsbt: 'other',
        originalTxId: 'other',
        amountSat: 1,
        createdAt: DateTime.fromMillisecondsSinceEpoch(5000),
        expiresAt: DateTime.fromMillisecondsSinceEpoch(6000),
      );
      expect(resumed.logRef, sender.logRef);
    });
  });
}
