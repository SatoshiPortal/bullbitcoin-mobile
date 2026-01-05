import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/models/electrum_server_model.dart';
import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/core/transactions/bitcoin_transaction_repository.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

Future<void> main({bool isInitialized = false}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final sqlite = sl<SqliteDatabase>();
  final electrumDatasource = ElectrumRemoteDatasource(
    server: ElectrumServerModel(
      url: ApiServiceConstants.bbElectrumUrl,
      network: ElectrumServerNetwork.bitcoinMainnet,
    ),
    sqlite: sqlite,
  );
  final transactionRepository = BitcoinTransactionRepository(
    electrumRemoteDatasource: electrumDatasource,
  );

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
      final tx = await transactionRepository.fetch(txid: txid);
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
