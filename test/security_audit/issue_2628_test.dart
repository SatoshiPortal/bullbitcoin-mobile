// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2628
// Finding: MAX confirmation keeps the full spendable balance instead of the net recipient amount.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2628 MAX confirmation', () {
    test(
      'confirmed amount is the full spendable balance, fee not subtracted',
      () {
        final source = File(
          'lib/features/send/presentation/bloc/send_cubit.dart',
        ).readAsStringSync();

        // Toggling MAX fills the amount with the entire spendable balance.
        expect(source, contains('validatedAmount = spendableSat.toString();'));

        // Confirming copies that full amount verbatim — the recipient of a
        // drain transaction actually receives balance minus the network fee.
        expect(source, contains('confirmedAmountSat: maxAmountSat,'));
      },
    );
  });
}
