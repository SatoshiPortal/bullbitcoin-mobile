import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2627
// Finding: broadcast awaits network I/O and emits/bookkeeps afterward without a closed-cubit guard.
// Regression test for the fix.
void main() {
  group('Security audit #2627 close during broadcast', () {
    test(
      'broadcast continuation emits and performs bookkeeping after await',
      () {
        final source = File(
          'features/send/lib/src/payment/presentation/bloc/send_cubit.dart',
        ).readAsStringSync();
        final broadcast = source.substring(
          source.indexOf('Future<void> broadcastTransaction'),
          source.indexOf('Future<bool> _validateSelectedInputsForBroadcast'),
        );
        expect(broadcast, contains('await _spend.broadcastBitcoin('));
        expect(broadcast, contains('await _spend.resumeBitcoinPayin('));
        expect(broadcast, contains('txId = receipt.txid;'));
        expect(
          broadcast,
          matches(
            RegExp(
              r'await _storeSendTransactionLabel\.execute\(\s*transactionId: txId,',
            ),
          ),
        );
        expect(
          broadcast,
          matches(
            RegExp(
              r'if \(!isClosed\) \{\s*emit\(\s*state\.copyWith\(\s*'
              r'broadcastingTransaction: false,\s*step: SendStep\.success,',
            ),
          ),
        );
        expect(source, contains('return super.close();'));
      },
    );
  });
}
