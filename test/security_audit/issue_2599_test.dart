import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/background_wallet_storage_guard.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2599
// Finding: wallet databases, Payjoin state, and logs are stored in iOS Documents without backup exclusion.
// Regression test for the fix.
void main() {
  group('Security audit #2599 iOS backup exposure', () {
    test(
      'sensitive files use Documents and backup exclusion is configured',
      () {
        final sqlite = File(
          'packages/legacy_storage/lib/src/app_database/sqlite_database.dart',
        ).readAsStringSync();
        final initialization = File('lib/init.dart').readAsStringSync();
        final walletComposition = File(
          'lib/features/wallet/wallet_locator.dart',
        ).readAsStringSync();
        final writer = File(
          'packages/sync/lib/src/data/write/native_write_session.dart',
        ).readAsStringSync();
        expect(sqlite, contains('getApplicationDocumentsDirectory'));
        expect(initialization, contains('getApplicationDocumentsDirectory'));
        expect(walletComposition, contains('getApplicationDocumentsDirectory'));
        expect(writer, contains('nativeWalletStoragePath(documentsDirectory'));

        final nativeAndDart = <String>[];
        for (final root in [Directory('lib'), Directory('ios')]) {
          if (!root.existsSync()) continue;
          nativeAndDart.addAll(
            root
                .listSync(recursive: true)
                .whereType<File>()
                .where(
                  (file) =>
                      file.path.endsWith('.dart') ||
                      file.path.endsWith('.swift') ||
                      file.path.endsWith('.m') ||
                      file.path.endsWith('.h'),
                )
                .map((file) => file.readAsStringSync()),
          );
        }
        expect(
          nativeAndDart.join('\n'),
          contains('NSURLIsExcludedFromBackupKey'),
        );
      },
    );

    test(
      'background stores use Documents without opening Payjoin or custody',
      () {
        final source = [
          'lib/background_bootstrap.dart',
          'packages/background_tasks/lib/src/wallet_task_setup.dart',
        ].map((path) => File(path).readAsStringSync()).join('\n');
        expect(source, contains('await getApplicationDocumentsDirectory()'));
        expect(source, contains('openExisting(documents.path)'));
        expect(
          source,
          contains("_queueFilename = 'wallet_transaction_sync_queue.sqlite'"),
        );
        expect(
          source,
          contains('openBackgroundWalletSyncQueue(documents.path)'),
        );
        expect(source, contains('p.join(documents, _queueFilename)'));
        expect(
          source,
          matches(RegExp(r'openNotifications\(\s*documents\.path,')),
        );
        final notifications = File(
          'packages/notifications/lib/src/payment_notification_store.dart',
        ).readAsStringSync();
        expect(
          notifications,
          matches(
            RegExp(
              r'openExistingNotificationStore\(\s*p\.join\(documents, paymentNotificationOutboxFilename\)',
            ),
          ),
        );
        expect(source, isNot(contains('AppLocator.setup(')));
        expect(source, isNot(contains('payjoinDatabaseFilename')));
        expect(source, isNot(contains('package:secrets/secrets.dart')));
        final admission = source.indexOf(
          'final admitted = await cutover.admit()',
        );
        expect(admission, greaterThanOrEqualTo(0));
        expect(
          source.indexOf('BackgroundTaskRunner.forTask(', admission),
          greaterThan(admission),
        );
        final schemaGate = source.indexOf('SqliteDatabase.isAtCurrentSchema()');
        expect(schemaGate, greaterThanOrEqualTo(0));
        expect(
          source.indexOf('final sqlite = await LegacySourceStore(', schemaGate),
          greaterThan(schemaGate),
        );
        expect(source, contains(').open(admission)'));
        expect(source, isNot(contains('cutover.prepare()')));
        expect(source, isNot(contains('SqliteDatabase();')));
      },
    );

    for (final (role, path) in [('foreground', 'lib/init.dart')]) {
      test(
        '$role Payjoin retains the Documents source and opens its owner',
        () {
          final source = File(path).readAsStringSync();
          expect(
            source,
            matches(
              RegExp(
                r'final\s+bullDirectory\s*=\s*await\s+getApplicationDocumentsDirectory\(\)',
              ),
            ),
          );
          expect(
            source,
            matches(
              RegExp(
                r'File standalone\(String name\) => File\(p\.join\(bullDirectory\.path, name\)\);',
              ),
            ),
          );
          expect(
            source,
            allOf(
              contains("p.join(support.path, 'databases',"),
              matches(
                RegExp(
                  r'PayjoinCutover\(\s*file: destination\(owner\),\s*standalone: standalone\(',
                ),
              ),
            ),
          );
        },
      );
    }
  });
}
