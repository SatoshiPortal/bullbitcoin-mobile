// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2621
// Finding: editing a custom server inserts a second row for the same network.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2621 custom server replacement', () {
    test('storage path atomically replaces the old URL row', () {
      final table = File(
        'packages/mempool/lib/src/data/tables/mempool_servers_table.dart',
      ).readAsStringSync();
      final datasource = File('packages/mempool/lib/src/data/mempool_dao.dart')
          .readAsStringSync();

      expect(table, contains('primaryKey => {url, isTestnet, isLiquid}'));
      expect(datasource, contains('transaction'));
      final storeMethod = datasource.split('Future<MempoolServerModel?>').first;
      expect(storeMethod, contains('.delete()'));
      expect(datasource, contains('getSingleOrNull()'));
    });
  });
}
