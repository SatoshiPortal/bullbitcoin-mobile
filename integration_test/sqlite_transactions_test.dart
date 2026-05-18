import 'package:bb_mobile/core/electrum/application/usecases/fetch_electrum_transaction_usecase.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final sqlite = locator<SqliteDatabase>();
  final fetchUsecase = locator<FetchElectrumTransactionUsecase>();

  const txid =
      'ff47a0a1dfdcf68327242d2cbfb229a5ba7e3e67572c2d4f390c51b1a89d56e5';

  setUp(() async => await sqlite.clearCacheTables());

  tearDownAll(() {});
  group('Sqlite Integration Tests', () {
    test('Ensure the repository works', () async {
      // Ensure the tx does not exists in sqlite
      var sqliteTx = await sqlite.managers.transactions
          .filter((e) => e.txid(txid))
          .getSingleOrNull();
      expect(sqliteTx, isNull);

      // Fetch a transaction and cache it in sqlite if not present
      final tx = await fetchUsecase.execute(txid: txid);
      expect(tx.txid, txid);

      // Ensure the tx is now stored in sqlite
      sqliteTx = await sqlite.managers.transactions
          .filter((e) => e.txid(tx.txid))
          .getSingleOrNull();
      expect(sqliteTx, isNotNull);
      expect(tx.txid, sqliteTx!.txid);
    });
  });
}
