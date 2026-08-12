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
        final payjoin = File('lib/payjoin_setup.dart').readAsStringSync();
        final bdk = File(
          'lib/core/wallet/data/datasources/bdk_facade.dart',
        ).readAsStringSync();
        final lwk = File(
          'lib/core/wallet/data/datasources/lwk_facade.dart',
        ).readAsStringSync();
        final main = File('lib/main.dart').readAsStringSync();

        expect(sqlite, contains('getApplicationDocumentsDirectory'));
        expect(payjoin, contains('getApplicationDocumentsDirectory'));
        expect(bdk, contains('getApplicationDocumentsDirectory'));
        expect(lwk, contains('getApplicationDocumentsDirectory'));
        expect(main, contains('getApplicationDocumentsDirectory'));

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
  });
}
