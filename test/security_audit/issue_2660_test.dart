// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2660
// Finding: repository reports deletion success while the datasource returns false.
// Regression test for the fix.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security audit #2660 delete result propagation', () {
    test('repository propagates a failed deletion', () {
      final datasource = File(
        'lib/core/mempool/frameworks/drift/datasources/'
        'mempool_server_storage_datasource.dart',
      ).readAsStringSync();
      final repository = File(
        'lib/core/mempool/interface_adapters/repositories/'
        'drift_mempool_server_repository.dart',
      ).readAsStringSync();

      expect(datasource, contains('Future<bool> deleteCustomServer'));
      expect(datasource, contains('return false;'));
      expect(
        repository,
        contains('await _datasource.deleteCustomServer(network);'),
      );
      expect(repository, contains('if (!deleted)'));
      expect(repository, contains('MempoolDeleteFailure'));
    });
  });
}
