import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

class GetTransactionsByTxIdUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;
  final PayjoinRepository _payjoinRepository;

  GetTransactionsByTxIdUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required PayjoinRepository payjoinRepository,
  }) : _settingsRepository = settingsRepository,
       _walletTransactionRepository = walletTransactionRepository,
       _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _payjoinRepository = payjoinRepository;

  Future<List<Transaction>> execute(String txId) async {
    try {
      // Fetch settings to determine environment
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final swapRepository =
          isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;
      // Fetch wallet transaction by txId
      final (walletTransactions, swap, payjoins) =
          await (
            _walletTransactionRepository.getWalletTransactions(txId: txId),
            swapRepository.getSwapByTxId(txId),
            _payjoinRepository.getPayjoinsByTxId(txId),
          ).wait;

      if (walletTransactions.isNotEmpty) {
        return walletTransactions.map((walletTransaction) {
          final payjoin =
              payjoins
                  .where((pj) => pj.walletId == walletTransaction.walletId)
                  .firstOrNull;

          return Transaction.broadcasted(
            walletTransaction: walletTransaction,
            swap: swap,
            payjoin: payjoin,
          );
        }).toList();
      } else if (swap != null) {
        return [Transaction.ongoingSwap(swap: swap)];
      } else if (payjoins.isNotEmpty) {
        return payjoins
            .map((pj) => Transaction.ongoingPayjoin(payjoin: pj))
            .toList();
      } else {
        return []; // No transaction found
      }
    } catch (e) {
      throw GetTransactionsByTxIdException('$e');
    }
  }
}

class GetTransactionsByTxIdException implements Exception {
  final String message;

  GetTransactionsByTxIdException(this.message);

  @override
  String toString() => '[GetTransactionByTxIdUsecase]: $message';
}
