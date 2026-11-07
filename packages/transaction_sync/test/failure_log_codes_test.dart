import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  test('every failure category survives persisted-log redaction', () async {
    final directory = Directory.systemTemp.createTempSync('failure-codes-');
    log = Logger.replace(directory: directory);
    addTearDown(() async {
      await log.flush();
      directory.deleteSync(recursive: true);
    });
    const failures = <TransactionSyncFailure>[
      TransactionSyncBusyFailure(),
      TransactionSyncNotFoundFailure(),
      TransactionSyncUnsupportedNetworkFailure(),
      TransactionSyncUnsupportedNetworkFailure(authorization: true),
      TransactionSyncInvalidCatalogFailure(),
      TransactionSyncStorageFailure(),
      TransactionSyncConnectionFailure(),
      TransactionSyncNeedsRepairFailure(),
      TransactionSyncRestartRequiredFailure(),
      TransactionSyncInitialScanRequiredFailure(),
    ];
    for (final failure in failures) {
      log.warning('Wallet sync unavailable category=${failure.logCode}');
    }
    final lines = await log.readLogs();
    final categories = lines
        .where((line) => line.contains('category='))
        .map((line) => line.split('category=').last.split('\t').first)
        .toSet();
    expect(categories, {
      'busy',
      'not_found',
      'unsupported_network',
      'authorization',
      'invalid_catalog',
      'storage',
      'connection',
      'needs_repair',
      'restart_required',
      'initial_scan_required',
    });
    expect(lines.join(), isNot(contains('[REDACTED]')));
  });
}
