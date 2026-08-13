// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2595
// Finding: magic-routing replaced the invoice with an unverified server BIP21.
// New sends use Exchange orders and must never consume Boltz magic-routing data.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2595 magic-routing authentication', () {
    test('send flow does not consume Boltz magic-routing data', () {
      final source = File(
        'lib/features/send/presentation/bloc/send_cubit.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('magicBip21')));
      expect(source, contains('_createSendSwapUsecase.execute('));
    });

    test('legacy recovery still stores upstream magic-routing data', () {
      final source = File(
        'lib/core/swaps/data/repository/boltz_swap_repository.dart',
      ).readAsStringSync();

      expect(source, contains('magicBip21: bip21'));
    });
  });
}
