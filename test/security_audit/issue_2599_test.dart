import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2599
// Finding: wallet databases, Payjoin state, and logs are stored in iOS Documents without backup exclusion.
// Regression test for the fix.
void main() {
  group('Security audit #2599 iOS backup exposure', () {
    test(
      'sensitive files use Documents and backup exclusion is configured',
      () {
        final sqlite = File(
          'lib/core/storage/sqlite_database.dart',
        ).readAsStringSync();
        final initialization = File('lib/init.dart').readAsStringSync();
        final walletComposition = File(
          'lib/features/wallet/wallet_locator.dart',
        ).readAsStringSync();
        final writer = File(
          'packages/transaction_sync/lib/src/write/native_write_session.dart',
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

    for (final (role, path) in [
      ('foreground', 'lib/init.dart'),
      ('background', 'lib/core/background_tasks/handler.dart'),
    ]) {
      test('$role Payjoin storage uses the Documents directory', () {
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
              r'p\.join\(\s*bullDirectory\.path,\s*payjoinDatabaseFilename,?\s*\)',
            ),
          ),
        );
      });
    }
  });
}
