import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:background_tasks/background_tasks.dart';
import 'package:bb_mobile/features/wallet/data/payment_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:transaction_sync/transaction_sync.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final storageFailure in [true, false]) {
    test(
      'notification startup failure permits wallet sync (storage=$storageFailure)',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        FlutterLocalNotificationsPlatform.instance = _Android();
        final directory = Directory.systemTemp.createTempSync(
          'notification-startup-',
        );
        await initializeLogging(directory: directory);
        addTearDown(() async {
          await log.flush();
          directory.deleteSync(recursive: true);
        });
        final resources = BackgroundTaskResources();
        addTearDown(resources.close);
        final documents = storageFailure
            ? '${directory.path}/file'
            : directory.path;
        if (storageFailure) {
          File(documents).writeAsStringSync('not a directory');
        }
        final notifications = await PaymentNotifications.initializeBackground(
          documents,
          null,
          resources,
        );
        final queue = SqliteWalletSyncJobQueue(
          databasePath: '${directory.path}/queue',
        );
        resources.onClose(queue.close);
        final writer = _Writer();
        final task = WalletTransactionSyncBackgroundTask(
          writer: writer,
          revisions: _Revisions(),
          keys: [key],
          queue: queue,
          notifications: notifications,
          copy: (count, chain) => (title: 'Payment', body: '$count'),
        );
        expect((await task.executeAll()).shouldRetry, isFalse);
        expect(writer.calls, 1);
        await log.flush();
        final messages = (await log.readLogs()).join('\n');
        expect(messages, contains('Background notifications unavailable'));
        expect(messages, isNot(contains(documents)));
      },
    );
  }
}

final key = WalletKey(id: 'test', network: BitcoinNetwork.testnet);
WalletRevision get stamp =>
    WalletRevision(key: key, generation: 1, revision: 1);

class _Android extends AndroidFlutterLocalNotificationsPlugin {
  @override
  Future<bool> initialize({
    required AndroidInitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => false;
}

final class _Writer implements BackgroundWalletSync {
  int calls = 0;
  @override
  Future<Result<BackgroundSyncOutcome, BackgroundSyncFailure>> synchronize(
    WalletKey key, {
    required bool allowInitialScan,
    required bool discover,
  }) async {
    calls++;
    return Ok(
      BackgroundSyncOutcome(
        revision: stamp,
        incomingTxids: const [],
        completedAt: DateTime.utc(2026),
      ),
    );
  }
}

final class _Revisions implements WalletRevisionReaderPort {
  @override
  Future<Result<WalletRevisionState, TransactionSyncFailure>> read(
    WalletKey key,
  ) async =>
      Ok(WalletRevisionState(stamp: stamp, lifecycle: WalletLifecycle.active));
  @override
  Stream<WalletRevisionState> watch(WalletKey key) => const Stream.empty();
}
