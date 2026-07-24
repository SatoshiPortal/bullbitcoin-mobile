import 'package:bb_mobile/core/electrum/domain/electrum_broadcast_error_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isTransientBroadcastError — permanent mempool/policy rejections', () {
    const permanentPhrases = <String>[
      'missingorspent',
      'missing or spent',
      'non-final',
      'non-BIP68-final',
      'txn-mempool-conflict',
      'already in block chain',
      'bad-txns',
      'mandatory-script-verify-flag',
      'non-mandatory-script-verify-flag',
      'dust',
    ];

    for (final phrase in permanentPhrases) {
      test('"$phrase" classifies as permanent (not transient)', () {
        expect(isTransientBroadcastError(Exception(phrase)), isFalse);
      });

      test('"$phrase" matches case-insensitively', () {
        expect(
          isTransientBroadcastError(Exception(phrase.toUpperCase())),
          isFalse,
        );
      });

      test('"$phrase" matches when embedded in a longer server message', () {
        expect(
          isTransientBroadcastError(
            Exception('the transaction was rejected: $phrase (code 64)'),
          ),
          isFalse,
        );
      });
    }
  });

  group('isTransientBroadcastError — transient / unknown errors', () {
    test('an unrelated Exception message is transient', () {
      expect(
        isTransientBroadcastError(Exception('connection refused')),
        isTrue,
      );
    });

    test('a timeout-style message is transient', () {
      expect(isTransientBroadcastError(Exception('timed out')), isTrue);
    });
  });

  group('isTransientBroadcastError — per-server fee-policy rejections are '
      'transient, not permanent', () {
    const feePolicyPhrases = <String>[
      'insufficient fee',
      'min relay fee not met',
    ];

    for (final phrase in feePolicyPhrases) {
      test('"$phrase" is transient so another server\'s fee floor can still '
          'accept the transaction', () {
        expect(isTransientBroadcastError(Exception(phrase)), isTrue);
      });

      test('"$phrase" is transient case-insensitively', () {
        expect(
          isTransientBroadcastError(Exception(phrase.toUpperCase())),
          isTrue,
        );
      });
    }
  });

  group('isTransientBroadcastError — Error subclasses are never transient', () {
    test('a StateError (programming bug) is not transient', () {
      expect(isTransientBroadcastError(StateError('bug')), isFalse);
    });

    test('an Error whose message happens to match a permanent phrase is still '
        'not transient (falls through the same permanent branch)', () {
      expect(isTransientBroadcastError(StateError('missingorspent')), isFalse);
    });
  });
}
