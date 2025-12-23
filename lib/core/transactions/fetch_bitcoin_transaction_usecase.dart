import 'package:bb_mobile/core/transactions/bitcoin_transaction_repository.dart';
import 'package:bb_mobile/core/utils/bitcoin_tx.dart';

class FetchBitcoinTransactionUsecase {
  final BitcoinTransactionRepository _transactionRepository;

  FetchBitcoinTransactionUsecase({
    required BitcoinTransactionRepository transactionRepository,
  }) : _transactionRepository = transactionRepository;

  Future<BitcoinTx> execute({required String txid}) async {
    return await _transactionRepository.fetch(txid: txid);
  }
}
