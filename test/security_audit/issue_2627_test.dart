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
          'lib/features/send/presentation/bloc/send_cubit.dart',
        ).readAsStringSync();
        final broadcast = source.substring(
          source.indexOf('Future<void> broadcastTransaction'),
          source.indexOf('Future<void> onConfirmTransactionClicked'),
        );
        expect(broadcast, contains('await _broadcastBitcoinTxUsecase.execute'));
        expect(broadcast, contains('await _labelsFacade.store'));
        expect(broadcast, contains('step: SendStep.success'));
        expect(broadcast, contains('if (!isClosed)'));
        expect(source, contains('return super.close();'));
      },
    );
  });
}
