import 'package:bb_mobile/core/electrum/application/usecases/fetch_electrum_transaction_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/transactions/adapters/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/application/transaction_port.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';

/// Adapter that implements [TransactionPort] using the Electrum module.
///
/// Lives in the electrum module because it is the electrum module providing
/// an implementation of an external port — same pattern as
/// [EnvironmentAdapter] implementing [EnvironmentPort].
class ElectrumTransactionPortAdapter implements TransactionPort {
  final FetchElectrumTransactionUsecase _fetchUsecase;
  final EnvironmentPort _environmentPort;

  const ElectrumTransactionPortAdapter({
    required FetchElectrumTransactionUsecase fetchUsecase,
    required EnvironmentPort environmentPort,
  }) : _fetchUsecase = fetchUsecase,
       _environmentPort = environmentPort;

  @override
  Future<Transaction> fetch({required String txid}) async {
    final environment = await _environmentPort.getEnvironment();
    final bitcoinTx = await _fetchUsecase.execute(txid: txid);
    return TransactionMapper.fromBitcoinTx(
      bitcoinTx,
      isTestnet: environment.isTestnet,
    );
  }
}
