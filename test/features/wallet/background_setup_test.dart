import 'dart:io';

import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/wallet/background_setup.dart';
import 'package:bb_mobile/features/wallet/data/payment_notifications.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory documents;
  late BackgroundTaskResources resources;
  String queuePath() =>
      '${documents.path}/wallet_transaction_sync_queue.sqlite';
  String storePath() =>
      '${documents.path}/${PaymentNotifications.outboxFilename}';

  setUp(() {
    documents = Directory.systemTemp.createTempSync('background-stores-');
    log = Logger.replace(directory: documents);
    resources = BackgroundTaskResources();
  });
  tearDown(() async {
    await resources.close();
    documents.deleteSync(recursive: true);
  });

  Future<void> expectRefused() async {
    expect(openBackgroundWalletSyncQueue(documents.path), isA<Err>());
    expect(
      await PaymentNotifications.initializeBackground(
        documents.path,
        null,
        resources,
      ),
      isNull,
    );
  }

  test('absent stores are refused, never created', () async {
    await expectRefused();
    expect(File(queuePath()).existsSync(), isFalse);
    expect(File(storePath()).existsSync(), isFalse);
  });

  for (final (name, version) in [('older', 0), ('future', 99)]) {
    test('$name stores are refused, never migrated', () async {
      for (final path in [queuePath(), storePath()]) {
        final database = sqlite3.open(path);
        database.execute('CREATE TABLE previous (id INTEGER)');
        database.execute('PRAGMA user_version = $version');
        database.dispose();
      }
      final before = [
        for (final path in [queuePath(), storePath()])
          File(path).readAsBytesSync(),
      ];

      await expectRefused();

      expect([
        for (final path in [queuePath(), storePath()])
          File(path).readAsBytesSync(),
      ], before);
    });
  }

  test('the queue the foreground created opens in the background', () async {
    switch (SqliteWalletSyncJobQueueRepository.openForeground(queuePath())) {
      case Ok(:final value):
        await value.close();
      case Err(:final failure):
        fail('$failure');
    }
    final opened = openBackgroundWalletSyncQueue(documents.path);
    if (opened case Ok(:final value)) await value.close();
    expect(opened, isA<Ok>());
  });
}
