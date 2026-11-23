// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2645
// Finding: BIP85 selects the first default Bitcoin wallet without an active-network filter.
// Regression test for active-environment wallet selection.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2645 network-specific default wallet', () {
    test(
      'derive-next reads the default Bitcoin wallet on the active network',
      () {
        final source = File(
          'features/bip85/lib/src/domain/manage_bip85_usecase.dart',
        ).readAsStringSync();
        expect(source, contains('nextHex() => _forDefault('));
        expect(source, matches(RegExp(r'nextMnemonic\(\) =>\s*_forDefault\(')));
        final selection = source.substring(source.indexOf('_forDefault<T>'));
        expect(
          selection,
          contains('await _preferences.readActiveEnvironment()'),
        );
        for (final environment in ['mainnet', 'testnet', 'regtest']) {
          expect(
            selection,
            contains('Environment.$environment => BitcoinNetwork.$environment'),
          );
        }
        expect(
          selection,
          contains('await _inventory.walletsForNetwork(network)'),
        );
        expect(selection, contains('value.defaults.firstOrNull'));
      },
    );
  });
}
