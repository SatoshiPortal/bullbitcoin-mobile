import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late SqliteDatabase database;
  late ElectrumRemoteDatasource datasource;

  setUp(() {
    database = SqliteDatabase(NativeDatabase.memory());
    datasource = ElectrumRemoteDatasource(
      sqlite: database,
      socketConnector: const ElectrumSocketConnector(),
    );
  });

  tearDown(() => database.close());

  test('rejects an invalid proxy instead of connecting directly', () async {
    await expectLater(
      datasource.fetch(
        serverUrl: 'ssl://127.0.0.1:1',
        txid: '0' * 64,
        socks5: '127.0.0.1:not-a-port',
      ),
      throwsA(
        predicate<Object>(
          (error) => error.toString().contains('unusable SOCKS5 proxy'),
        ),
      ),
    );
  });
}
