import 'dart:convert';

import 'package:bb_mobile/core/electrum/data/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/electrum/data/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/transaction/data/transaction_repository.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final sqlite = locator<SqliteDatabase>();
  final electrumDatasource = ElectrumRemoteDatasource(
    server: const ElectrumServerModel(
      url: ApiServiceConstants.bbElectrumUrl,
      isTestnet: false,
      isLiquid: false,
    ),
  );
  final transactionRepository = TransactionRepository(
    electrumRemoteDatasource: electrumDatasource,
  );

  const txid =
      'ff47a0a1dfdcf68327242d2cbfb229a5ba7e3e67572c2d4f390c51b1a89d56e5';

  setUp(() async => await sqlite.clearCacheTables());

  tearDownAll(() {});
  group('Sqlite Integration Tests', () {
    test('Fetch tx bytes from Electrum and store it into Sqlite', () async {
      // Ensure the tx does not exists in sqlite
      final sqliteTx =
          await sqlite.managers.transactions
              .filter((e) => e.txid(txid))
              .getSingleOrNull();
      expect(sqliteTx, isNull);

      // Fetch the transaction from electrum
      final txBytes = await electrumDatasource.getTransaction(txid);
      // Converts the bytes into entity
      final txEntity = await RawBitcoinTxEntity.fromBytes(txBytes);

      // Store the transaction into sqlite
      await sqlite.managers.transactions.create(
        (t) => t(
          txid: txEntity.txid,
          version: txEntity.version,
          size: txEntity.size.toString(),
          vsize: txEntity.vsize.toString(),
          locktime: txEntity.locktime,
          vin: json.encode(txEntity.vin.map((e) => e.toJson()).toList()),
          vout: json.encode(txEntity.vout.map((e) => e.toJson()).toList()),
        ),
      );

      // Fetch the transaction locally from sqlite
      final sqliteFetched =
          await sqlite.managers.transactions
              .filter((e) => e.txid(txid))
              .getSingleOrNull();
      expect(sqliteFetched, isNotNull);
      expect(sqliteFetched!.txid, txid);
    });

    test('Ensure the repository works', () async {
      // Ensure the tx does not exists in sqlite
      var sqliteTx =
          await sqlite.managers.transactions
              .filter((e) => e.txid(txid))
              .getSingleOrNull();
      expect(sqliteTx, isNull);

      // Fetch a transaction and cache it in sqlite if not present
      final tx = await transactionRepository.fetch(txid: txid);
      expect(tx.txid, txid);

      // Ensure the tx is now stored in sqlite
      sqliteTx =
          await sqlite.managers.transactions
              .filter((e) => e.txid(txid))
              .getSingleOrNull();
      expect(sqliteTx, isNotNull);
      expect(tx.txid, sqliteTx!.txid);
    });
  });
}
