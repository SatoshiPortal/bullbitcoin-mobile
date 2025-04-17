import 'package:bb_mobile/core/transaction/data/drift_datasource.dart';
import 'package:bb_mobile/core/transaction/data/electrum_service.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';

class TransactionRepository {
  final _drift = DriftDatasource();
  final _electrum = ElectrumService(host: 'blockstream.info', port: 700);

  TransactionRepository();

  Future<Tx> fetchTransaction({required String txid}) async {
    var tx = await _drift.fetchTransaction(txid);

    if (tx == null) {
      tx = await _electrum.getTransaction(txid);
      await _drift.storeTransaction(tx);
    }

    return tx;
  }
}
