import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/transaction/domain/entities/transaction.dart';
import 'package:bb_mobile/core/transaction/domain/repositories/transaction_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';

class GetTransactionsUsecase {
  final TransactionRepository _transactionRepository;
  final SwapRepository _testnetSwapRepository;
  final SwapRepository _mainnetSwapRepository;
  final WalletRepository _walletRepository;

  GetTransactionsUsecase({
    required TransactionRepository transactionRepository,
    required SwapRepository testnetSwapRepository,
    required SwapRepository mainnetSwapRepository,
    required WalletRepository walletRepository,
  })  : _transactionRepository = transactionRepository,
        _testnetSwapRepository = testnetSwapRepository,
        _mainnetSwapRepository = mainnetSwapRepository,
        _walletRepository = walletRepository;

  Future<List<Transaction>> execute({required String walletId}) async {
    try {
      final transactions = await _transactionRepository.getTransactions(
        walletId: walletId,
      );
      final allTransactions = <Transaction>[];
      final wallet = await _walletRepository.getWallet(walletId);

      final network = wallet.network;
      final swapRepository =
          network.isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;

      for (final baseWalletTx in transactions) {
        final swapTx = await swapRepository.getSwapWalletTx(
          baseWalletTx: baseWalletTx,
          network: network,
        );
        // TODO: check if transaction is a payjoin
        if (swapTx != null) {
          allTransactions.add(swapTx);
        } else {
          allTransactions.add(
            OnchainTransactionFactory.fromWalletTx(
              baseWalletTx,
              network,
            ),
          );
        }
      }

      return allTransactions;
    } catch (e) {
      throw GetTransactionsException(e.toString());
    }
  }
}

class GetTransactionsException implements Exception {
  final String message;

  GetTransactionsException(this.message);
}
