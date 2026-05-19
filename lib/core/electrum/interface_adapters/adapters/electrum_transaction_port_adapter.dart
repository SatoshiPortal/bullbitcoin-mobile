import 'package:bb_mobile/core/electrum/application/usecases/fetch_electrum_transaction_usecase.dart';
import 'package:bb_mobile/core/transactions/application/transaction_port.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';

/// Adapter that implements [TransactionPort] using the Electrum module.
///
/// Lives in the electrum module because the electrum module provides
/// an implementation of an external port — same pattern as
/// `EnvironmentAdapter` implementing `EnvironmentPort`.
class ElectrumTransactionPortAdapter implements TransactionPort {
  final FetchElectrumTransactionUsecase _fetchUsecase;

  const ElectrumTransactionPortAdapter({
    required FetchElectrumTransactionUsecase fetchUsecase,
  }) : _fetchUsecase = fetchUsecase;

  @override
  Future<Transaction> fetch({required String txid}) {
    return _fetchUsecase.execute(txid: txid);
  }
}
