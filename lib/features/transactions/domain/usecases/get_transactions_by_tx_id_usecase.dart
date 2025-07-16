import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_error.dart';

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
  final BoltzSwapRepository _mainnetBoltzSwapRepository;
  final BoltzSwapRepository _testnetBoltzSwapRepository;
  final PayjoinRepository _payjoinRepository;
  final ExchangeOrderRepository _mainnetOrderRepository;
  final ExchangeOrderRepository _testnetOrderRepository;

  GetTransactionsByTxIdUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
    required BoltzSwapRepository mainnetBoltzSwapRepository,
    required BoltzSwapRepository testnetBoltzSwapRepository,
    required PayjoinRepository payjoinRepository,
    required ExchangeOrderRepository mainnetOrderRepository,
    required ExchangeOrderRepository testnetOrderRepository,
  }) : _settingsRepository = settingsRepository,
       _walletTransactionRepository = walletTransactionRepository,
       _mainnetBoltzSwapRepository = mainnetBoltzSwapRepository,
       _testnetBoltzSwapRepository = testnetBoltzSwapRepository,
       _payjoinRepository = payjoinRepository,
       _mainnetOrderRepository = mainnetOrderRepository,
       _testnetOrderRepository = testnetOrderRepository;

  Future<List<Transaction>> execute(String txId) async {
    try {
      // Fetch settings to determine environment for swap repository
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final swapRepository =
          isTestnet ? _testnetBoltzSwapRepository : _mainnetBoltzSwapRepository;
      final orderRepository =
          isTestnet ? _testnetOrderRepository : _mainnetOrderRepository;
      // Fetch wallet transactions, swap and payjoins by txId
      final (walletTransactions, swap, payjoins, order) =
          await (
            _walletTransactionRepository.getWalletTransactions(txId: txId),
            swapRepository.getSwapByTxId(txId),
            _payjoinRepository.getPayjoinsByTxId(txId),
            orderRepository.getOrderByTxId(txId),
          ).wait;

      if (walletTransactions.isNotEmpty) {
        return walletTransactions.map((walletTransaction) {
          // Both a send and a receive transaction can exist for the same txId,
          // so we take the one with the matching walletId.
          Payjoin? payjoin;
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
        throw const TransactionError.notFound();
      }
    } on TransactionNotFoundError {
      log.warning('No Transaction with txId $txId found.');
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
