import 'package:electrum/src/domain/repositories/electrum_transaction_repository.dart';
import 'package:electrum/src/domain/value_objects/electrum_connection.dart';
import 'package:electrum/src/data/datasources/electrum_remote_datasource.dart';
import 'package:electrum/src/data/transaction_model_mapper.dart';
import 'package:sync/sync.dart' show BitcoinTx;

class DriftElectrumTransactionRepository
    implements ElectrumTransactionRepository {
  final ElectrumRemoteDatasource _datasource;

  DriftElectrumTransactionRepository({required this._datasource});

  @override
  Future<BitcoinTx> fetch({
    required ElectrumConnection connection,
    required String txid,
  }) async {
    final model = await _datasource.fetch(connection: connection, txid: txid);
    return TransactionModelExtension.toEntity(model);
  }
}
