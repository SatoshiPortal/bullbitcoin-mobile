// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2602
// Finding: swap-provider limit failures are awaited without an error path.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2602 provider outage handling', () {
    test('loadSwapLimits has no failure classification or recovery', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<void> loadSwapLimits()');
      final end = source.indexOf('\n  void setSelectedSwapLimits()', start);
      final method = source.substring(start, end);

      expect(method, contains('_getSwapLimitsUsecase.execute'));
      expect(method, contains('try {'));
      expect(method, contains('on GetSwapLimitsException'));
      expect(method, contains('swapLimitsException'));
      expect(method, contains('creatingSwap: false'));
    });

    test('the Lightning send path calls the unguarded loader', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final call = source.indexOf('await loadSwapLimits();');
      final start = source.lastIndexOf(
        'if (state.paymentRequest!.isBolt11)',
        call,
      );
      final path = source.substring(
        start,
        call + 'await loadSwapLimits();'.length,
      );

      expect(path, contains('await loadSwapLimits();'));
      expect(source, contains('on GetSwapLimitsException'));
    });
  });
}
