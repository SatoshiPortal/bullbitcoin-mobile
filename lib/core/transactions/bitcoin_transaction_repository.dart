import 'package:bb_mobile/core/electrum/frameworks/drift/datasources/electrum_remote_datasource.dart'
    show ElectrumRemoteDatasource;
import 'package:bb_mobile/core/storage/tables/transactions_table.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';

class BitcoinTransactionRepository {
  final ElectrumRemoteDatasource _electrumRemoteDatasource;

  BitcoinTransactionRepository({
    required ElectrumRemoteDatasource electrumRemoteDatasource,
  }) : _electrumRemoteDatasource = electrumRemoteDatasource;

  Future<BitcoinTx> fetch({required String txid}) async {
    final txModel = await _electrumRemoteDatasource.fetch(txid: txid);
    return TransactionModelExtension.toEntity(txModel);
  }
}
