// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2662
// Finding: custom server URLs are embedded in fee-fetch exception messages.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2662 custom URL logging', () {
    test(
      'fee datasource does not include the complete base URL in its exception',
      () {
        final source = File(
          'lib/core/fees/data/fees_datasource.dart',
        ).readAsStringSync();

        expect(source, isNot(contains('No mempool fee endpoint available at')));
        expect(source, contains('baseUrl = server.fullUrl'));
        expect(source, contains("'No mempool fee endpoint available'"));
      },
    );
  });
}
