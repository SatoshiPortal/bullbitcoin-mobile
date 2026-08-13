// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2595
// Finding: magic-routing replaces the invoice with an unverified server BIP21.
// Regression test for the fix. Rust signature verification remains upstream.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2595 magic-routing authentication', () {
    test('send flow checks the decoded magic BIP21 amount', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();

      expect(source, contains('if (invoice.magicBip21 != null)'));
      expect(source, contains('data: invoice.magicBip21!'));
      expect(source, contains('updatedRequest.amountSat != invoice.sats'));
      expect(source, contains('confirmedAmountSat: invoice.sats'));
    });

    test('the upstream repository remains outside this Dart-side fix', () {
      final source = File(
        'lib/core/swaps/data/repository/boltz_swap_repository.dart',
      ).readAsStringSync();

      expect(source, contains('magicBip21: bip21'));
    });
  });
}
