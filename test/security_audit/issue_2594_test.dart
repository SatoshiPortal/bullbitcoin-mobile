import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2594
// Finding: sendMax survives payment-request changes and is passed into final transaction construction.
// Regression test for the fix.
void main() {
  group('Security audit #2594 stale MAX state', () {
    test('request updates clear stale MAX outside selected-coin sweeps', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final requestHandlers = source.substring(
        source.indexOf('Future<void> onScannedPaymentRequest'),
        source.indexOf('Future<void> continueOnAddressConfirmed'),
      );
      expect(requestHandlers, contains('paymentRequest: paymentRequest'));
      expect(requestHandlers, contains('sendMax: state.isSweep'));
      expect(source, contains('drain: state.sendMax'));
      expect(
        source,
        contains(
          'final drain = state.lightningOrder != null ? false : state.sendMax;',
        ),
      );
    });
  });
}
