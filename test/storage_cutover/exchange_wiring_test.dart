import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The composition contract of D81: one authority for the Exchange
/// credentials, wired in the shell. Set EXCHANGE_WIRING_ROOT to check another
/// checkout of the repository.
void main() {
  final root = Platform.environment['EXCHANGE_WIRING_ROOT'] ?? '.';
  String read(String path) => File('$root/$path').readAsStringSync();

  Iterable<File> sources(String directory) =>
      Directory('$root/$directory')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (file) =>
                file.path.endsWith('.dart') &&
                !file.path.contains('/.dart_tool/') &&
                !file.path.endsWith('.g.dart') &&
                !file.path.endsWith('.freezed.dart') &&
                !file.path.endsWith('.drift.dart'),
          );

  test('the foreground cutover imports the Exchange credentials', () {
    final init = read('lib/init.dart');
    expect(init, contains('ExchangeCredentialImport('));
    expect(init, contains('ExchangeCredentialStorage.open('));
  });

  test('the Exchange store is opened existing-only after admission', () {
    final init = read('lib/init.dart');
    expect(
      init.indexOf('ExchangeCredentialStorage.open('),
      greaterThan(init.indexOf('cutover.prepare()')),
    );
  });

  test('no production code writes or reads the legacy credential sources', () {
    final offenders = <String>[];
    for (final directory in ['lib', 'features', 'packages']) {
      for (final file in sources(directory)) {
        final path = file.path.substring(root.length + 1);
        // The import is the one reader of the keychain; Secrets owns it and
        // legacy_storage keeps the historical table declarations.
        if (path.startsWith('packages/secrets/') ||
            path.startsWith('packages/legacy_storage/') ||
            path.contains('/test/') ||
            path.endsWith('exchange_credential_import.dart')) {
          continue;
        }
        final text = file.readAsStringSync();
        if (text.contains('exchangeKeychain') ||
            text.contains('exchange_testnet_basic_auth_username') ||
            text.contains('exchange_testnet_basic_auth_password') ||
            text.contains('LegacyPreferencesDao')) {
          offenders.add(path);
        }
      }
    }
    expect(offenders, isEmpty);
  });
}
