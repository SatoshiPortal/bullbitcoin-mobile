// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2616
// Finding: opening the PushTx URL is reported as a successful broadcast.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2616 NFC broadcast status', () {
    test(
      'launch result is checked and external opening is not broadcast success',
      () {
        final source = File(
          'lib/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart',
        ).readAsStringSync();
        expect(source, contains('final launched = await launchUrl('));
        expect(source, contains('if (!launched)'));
        expect(
          source,
          isNot(contains('emit(state.copyWith(isBroadcasted: true));')),
        );
      },
    );
  });
}
