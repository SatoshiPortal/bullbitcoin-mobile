import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_history_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:primitives/primitives.dart';

// This use case retrieves transactions by their transaction ID (txId).
// Two wallet transactions can exist for the same txId if the transaction was
// done between wallets in the app. One would be an incoming transaction and
// the other an outgoing transaction.
// Only one swap can exist for the same txId, since swaps are done between different networks
// and so they don't have the same txId for incoming and outgoing transactions.
// For payjoins, two transactions can exist for the same txId, just as with wallet transactions,
// there can be an incoming and an outgoing transaction for the same payjoin and so the same txId.
class GetTransactionsByTxIdUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final SwapHistoryRepository _boltzSwapRepository;
  final PayjoinSessions _payjoinSessions;
  final ExchangeOrderRepository _mainnetExchangeOrderRepository;
  final ExchangeOrderRepository _testnetExchangeOrderRepository;

  GetTransactionsByTxIdUsecase({
    required this._settingsRepository,
    required this._walletTransactionRepository,
    required this._boltzSwapRepository,
    required this._payjoinSessions,
    required this._mainnetExchangeOrderRepository,
    required this._testnetExchangeOrderRepository,
  });

  Future<List<Transaction>> execute(String txId) async {
    try {
      final settings = await _settingsRepository.fetch();
      final orderRepository = settings.environment.isTestnet
          ? _testnetExchangeOrderRepository
          : _mainnetExchangeOrderRepository;

      // Fetch wallet transactions, swap and payjoins by txId
      final (walletTransactions, swap, payjoinResult, order) = await (
        _walletTransactionRepository.getWalletTransactions(txId: txId),
        _boltzSwapRepository.getSwapByTxId(txId),
        _payjoinSessions.byTransactionId(txId),
        orderRepository.getOrderByTxId(txId),
      ).wait;
      final payjoins = switch (payjoinResult) {
        Ok(:final value) => value,
        Err() => <PayjoinSession>[],
      };

      if (walletTransactions.isNotEmpty) {
        return walletTransactions.map((walletTransaction) {
          // Both a send and a receive transaction can exist for the same txId,
          // so we take the one with the matching walletId.
          PayjoinSession? payjoin;
          try {
            payjoin = payjoins.firstWhere(
              (pj) => pj.walletId == walletTransaction.walletId,
            );
          } catch (_) {
            // If no payjoin is found for this wallet transaction, we set it to null.
            payjoin = null;
          }

          return Transaction(
            walletTransaction: walletTransaction,
            swap: swap,
            payjoin: payjoin,
            order: order,
          );
        }).toList();
      } else if (swap != null) {
        return [Transaction(swap: swap)];
      } else if (payjoins.isNotEmpty) {
        return payjoins.map((pj) => Transaction(payjoin: pj)).toList();
      } else if (order != null) {
        return [Transaction(order: order)];
      } else {
        throw TransactionNotFoundError();
      }
    } on TransactionNotFoundError {
      log.warning('No Transaction with txId $txId found.');
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
