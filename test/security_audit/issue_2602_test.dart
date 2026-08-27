// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2602
// Finding: swap-provider failures were awaited without an error path.
// Regression test for the Result-based Exchange quote flow.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2602 provider outage handling', () {
    test('quote failure is surfaced and stops swap creation', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final start = source.indexOf('Future<bool> loadSendSwapQuote({');
      final end = source.indexOf('\n  Future<bool> hasBalance()', start);
      final method = source.substring(start, end);

      expect(method, contains('_getSendSwapQuoteUsecase.execute'));
      expect(method, contains('case Err(:final failure):'));
      expect(method, contains('emit(state.copyWith(failure: failure))'));
      expect(method, contains('return false;'));
    });

    test('the Lightning send path stops when quote loading fails', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final start = source.indexOf('if (state.paymentRequest!.isBolt11) {');
      final end = source.indexOf("if (state.paymentRequest!.isBip21) {", start);
      final path = source.substring(start, end);

      expect(path, contains('if (!await loadSendSwapQuote('));
      expect(path, contains('creatingSwap: false'));
      expect(path, contains('return;'));
    });
  });
}
