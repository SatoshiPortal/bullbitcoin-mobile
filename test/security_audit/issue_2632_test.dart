// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2632
// Finding: raw swap-provider exception text is copied into send state/UI.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2632 raw swap errors', () {
    test('chain-swap failure stores the raw exception string', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      expect(
        source,
        isNot(
          contains(
            'swapCreationException: SwapCreationException(e.toString())',
          ),
        ),
      );
    });

    test('send error state still accepts arbitrary raw error text', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final load = source.substring(
        source.indexOf('Future<void> loadWalletWithRatesAndFees()'),
        source.indexOf('/// Called when a payment request'),
      );
      expect(load, isNot(contains('error: e.toString()')));
      expect(load, contains('Something went wrong. Please try again.'));
      expect(source, isNot(contains('SwapCreationException(e.toString())')));
    });
  });
}
