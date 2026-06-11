import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';

class DriftElectrumTransactionRepository
    implements ElectrumTransactionRepository {
  final ElectrumRemoteDatasource _datasource;

  DriftElectrumTransactionRepository({
    required this._datasource,
  });

  @override
  Future<BitcoinTx> fetch({
    required String serverUrl,
    required String txid,
  }) async {
    final model = await _datasource.fetch(serverUrl: serverUrl, txid: txid);
    return TransactionModelExtension.toEntity(model);
  }
}
