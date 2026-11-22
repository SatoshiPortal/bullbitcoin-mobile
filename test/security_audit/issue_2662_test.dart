// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2662
// Finding: custom server URLs are embedded in fee-fetch exception messages.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2662 custom URL logging', () {
    test(
      'fee URL selection stays outside the datasource exception boundary',
      () {
        final datasourceSource = File(
          'packages/fees/lib/src/data/mempool_fees_datasource.dart',
        ).readAsStringSync();
        final capabilitySource = File('packages/fees/lib/src/fees.dart')
            .readAsStringSync();

        expect(capabilitySource, contains('.servers.activeBase('));
        expect(capabilitySource, contains('baseUrl:'));
        expect(datasourceSource, isNot(contains('server.fullUrl')));
        expect(
          datasourceSource,
          isNot(contains('No mempool fee endpoint available at')),
        );
        expect(
          datasourceSource,
          contains("'No mempool fee endpoint available'"),
        );
      },
    );
  });
}
