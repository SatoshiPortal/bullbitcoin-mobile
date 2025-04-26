import 'package:bb_mobile/core/storage/sqlite_datasource.dart';
import 'package:bb_mobile/core/transaction/data/electrum_service.dart';
import 'package:bb_mobile/core/transaction/data/models/transaction_db_extension.dart';
import 'package:bb_mobile/core/transaction/data/models/transaction_mapper.dart';
import 'package:bb_mobile/core/transaction/data/transaction_repository.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // final sqlite = locator<SqliteDatasource>();
  final electrum = ElectrumService(host: 'wes.bullbitcoin.com', port: 50002);
  const txid =
      'ff47a0a1dfdcf68327242d2cbfb229a5ba7e3e67572c2d4f390c51b1a89d56e5';

  setUpAll(() {
    locator.registerLazySingleton<SqliteDatasource>(() => SqliteDatasource());
  });

  setUp(() async => await locator<SqliteDatasource>().clearCacheTables());

  tearDownAll(() {});
  group('Sqlite Integration Tests', () {
    test('Fetch tx bytes from Electrum and store it into Sqlite', () async {
      // Ensure the tx does not exists in sqlite
      final sqliteTx = await TransactionDb.fetch(txid);
      expect(sqliteTx, isNull);

      // Fetch the transaction from electrum
      final txBytes = await electrum.getTransaction(txid);
      // Converts the bytes into entity
      final txEntity = await TransactionMapper.fromBytes(txBytes);
      // Converts entity to model
      final transactionModel = TransactionMapper.toModel(txEntity);
      // Store the transaction into sqlite
      await transactionModel.store();

      // Fetch the transaction locally from sqlite
      final sqliteFetched = await TransactionDb.fetch(txid);
      expect(sqliteFetched, isNotNull);
      expect(sqliteFetched!.txid, txid);
    });

    test('Ensure the repository works', () async {
      final transactionRepository = TransactionRepository();

      // Ensure the tx does not exists in sqlite
      var sqliteTx = await TransactionDb.fetch(txid);
      expect(sqliteTx, isNull);

      // Fetch a transaction and cache it in sqlite if not present
      final tx = await transactionRepository.fetch(txid: txid);
      expect(tx.txid, txid);

      // Ensure the tx is now stored in sqlite
      sqliteTx = await TransactionDb.fetch(txid);
      expect(sqliteTx, isNotNull);
      expect(tx.txid, sqliteTx!.txid);
    });
  });
}
