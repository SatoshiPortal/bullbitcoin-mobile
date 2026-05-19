import 'package:bb_mobile/core/electrum/application/usecases/fetch_electrum_transaction_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fetch_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/transactions/data/mappers/transaction_mapper.dart';
import 'package:bb_mobile/core/transactions/domain/entity/transaction.dart';
import 'package:bb_mobile/core/transactions/domain/error/transaction_error.dart';
import 'package:bb_mobile/core/transactions/domain/ports/transaction_port.dart';

/// Adapter implementing [TransactionPort] for the Electrum module.
///
/// Resolves the current environment, delegates fetching to the electrum
/// usecase, maps the resulting util [BitcoinTx] into a [Transaction] domain
/// entity, and translates electrum-local exceptions into [TransactionError]
/// so the transactions module never sees electrum's error types.
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
    try {
      final bitcoinTx = await _fetchUsecase.execute(
        txid: txid,
        isTestnet: environment.isTestnet,
      );
      return TransactionMapper.fromBitcoinTx(
        bitcoinTx,
        isTestnet: environment.isTestnet,
      );
    } on ElectrumNoServersException catch (e) {
      throw TransactionError.noServersAvailable(network: e.network);
    } on ElectrumFetchFailedException catch (e) {
      throw TransactionError.fetchFailed(txid: e.txid, message: e.toString());
    }
  }
}
