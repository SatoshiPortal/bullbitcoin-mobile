import 'dart:io';
import 'dart:isolate';

import 'package:ark/ark.dart';
import 'package:ark/src/data/bark_sql_schema.dart';
import 'package:primitives/primitives.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

String sourceFixture() {
  final uri = Isolate.resolvePackageUriSync(Uri.parse('package:ark/ark.dart'));
  if (uri == null) throw StateError('Missing package URI');
  return File.fromUri(uri.resolve('../test/fixtures/bark_schema42.sql'))
      .readAsStringSync();
}

final account = ArkAccountId(
  parent: Fingerprint('12345678'),
  network: BitcoinNetwork.regtest,
  serverIdentity: 'fixture-server',
);
final schema = BarkSqlSchema(account, '1234abcd', '02${'ab' * 32}');
void seed(Database db) {
  db.execute(sourceFixture());
  db.execute('INSERT INTO migrations(value) VALUES(42)');
  db.execute(
    'INSERT INTO bark_properties(id,network,fingerprint,server_pubkey) VALUES(?,?,?,?)',
    [
      '1',
      'regtest',
      schema.expectedNativeFingerprint,
      schema.expectedServerPubkey,
    ],
  );
}

T got<T>(Result<T, ArkWalletFailure> result) {
  expect(result, isA<Ok<T, ArkWalletFailure>>());
  return (result as Ok<T, ArkWalletFailure>).value;
}
