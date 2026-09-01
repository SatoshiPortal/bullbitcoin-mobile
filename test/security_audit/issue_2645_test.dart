// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2645
// Finding: BIP85 selects the first default Bitcoin wallet without an active-network filter.
// Regression test for active-environment wallet selection.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2645 network-specific default wallet', () {
    test('derive-next resolves the default seed for the active environment', () {
      final source = File(
        'lib/core/bip85/domain/derive_next_bip85_mnemonic_from_default_wallet_usecase.dart',
      ).readAsStringSync();

      expect(source, contains('final settings = await _getSettings.execute()'));
      expect(
        source,
        contains('final seedResult = await _getDefaultSeed.execute('),
      );
      expect(source, contains('environment: settings.environment'));
    });
  });
}
