import 'initialization_result.dart';

import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:electrum/electrum.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/init.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) {
    requireSuccessfulBullInitialization(await Bull.init());
  }

  final sqlite = locator<SqliteDatabase>();
  final electrum = locator<Electrum>();

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
      final result = await electrum.transactions.fetch(
        txid,
        network: BitcoinNetwork.mainnet,
      );
      expect(result, isA<Ok>());
      expect(result.fold((tx) => tx.txid, (_) => null), txid);

      // Ensure the tx is now stored in sqlite
      sqliteTx = await sqlite.managers.transactions
          .filter((e) => e.txid(txid))
          .getSingleOrNull();
      expect(sqliteTx?.txid, txid);
    });
  });
}
