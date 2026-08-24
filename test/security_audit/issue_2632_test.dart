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

    test('raw diagnostics stay behind a generic localized failure', () {
      final cubitSource = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();
      final l10nSource = File(
        'lib/features/send/presentation/send_failure_l10n.dart',
      ).readAsStringSync();
      final load = cubitSource.substring(
        cubitSource.indexOf('Future<void> loadWalletWithRatesAndFees()'),
        cubitSource.indexOf('/// Called when a payment request'),
      );
      expect(load, isNot(contains('error: e.toString()')));
      expect(load, contains('SendUnexpectedFailure(e.toString())'));
      expect(
        l10nSource,
        contains(
          'SendUnexpectedFailure() => context.loc.oopsSomethingWentWrong',
        ),
      );
      expect(
        cubitSource,
        isNot(contains('SwapCreationException(e.toString())')),
      );
    });
  });
}
