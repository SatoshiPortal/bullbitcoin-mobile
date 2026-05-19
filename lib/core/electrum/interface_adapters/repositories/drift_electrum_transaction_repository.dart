import 'package:bb_mobile/core/electrum/domain/repositories/electrum_transaction_repository.dart';
import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart';
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/transactions/adapters/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/domain/entity/bitcoin_transaction.dart';

class DriftElectrumTransactionRepository
    implements ElectrumTransactionRepository {
  final ElectrumRemoteDatasource _datasource;

  DriftElectrumTransactionRepository({
    required ElectrumRemoteDatasource datasource,
  }) : _datasource = datasource;

  @override
  Future<BitcoinTransaction> fetch({
    required String serverUrl,
    required String txid,
    required bool isTestnet,
  }) async {
    final model = await _datasource.fetch(serverUrl: serverUrl, txid: txid);
    final bitcoinTx = TransactionModelExtension.toEntity(model);
    return TransactionMapper.fromBitcoinTx(bitcoinTx, isTestnet: isTestnet);
  }
}
