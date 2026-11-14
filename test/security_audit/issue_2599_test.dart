import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Security audit reproducer for https://github.com/SatoshiPortal/bullbitcoin-mobile/issues/2599
// Finding: wallet databases, Payjoin state, and logs are stored in iOS Documents without backup exclusion.
// Regression test for the fix.
void main() {
  group('Security audit #2599 iOS backup exposure', () {
    test('sensitive files use Documents and backup exclusion is configured', () {
      final initialization = File('lib/init.dart').readAsStringSync();
      final bdk = File(
        'lib/core/wallet/data/datasources/bdk_facade.dart',
      ).readAsStringSync();
      final lwk = File(
        'lib/core/wallet/data/datasources/lwk_facade.dart',
      ).readAsStringSync();

      expect(initialization, contains('getApplicationDocumentsDirectory'));
      // The main database is opened by LocalData at the path the shell builds.
      expect(
        initialization,
        matches(
          RegExp(
            r"p\.join\(\s*bullDirectory\.path,\s*'\$\{SqliteDatabase\.name\}\.sqlite',?\s*\)",
          ),
        ),
      );
      expect(bdk, contains('getApplicationDocumentsDirectory'));
      expect(lwk, contains('getApplicationDocumentsDirectory'));

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
    });

    test('foreground Payjoin storage uses the Documents directory', () {
      final source = File('lib/init.dart').readAsStringSync();
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

    test('the background handler opens no database', () {
      final source = File(
        'lib/core/background_tasks/handler.dart',
      ).readAsStringSync();
      for (final opener in [
        'SqliteDatabase',
        'payjoin',
        'getApplicationDocumentsDirectory',
        'AppLocator',
        'package:secrets',
      ]) {
        expect(source, isNot(contains(opener)), reason: opener);
      }
    });
  });
}
