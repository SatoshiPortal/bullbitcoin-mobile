import 'package:bb_mobile/core/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core/payjoin/domain/entity/payjoin.dart';
import 'package:bb_mobile/core/payjoin/domain/repositories/payjoin_repository.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_transaction.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_transaction_repository.dart';
import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';

class GetSwapCounterpartTransactionUsecase {
  final SettingsRepository _settingsRepository;
  final WalletTransactionRepository _walletTransactionRepository;
  final SwapRepository _mainnetSwapRepository;
  final SwapRepository _testnetSwapRepository;
  final PayjoinRepository _payjoinRepository;
  final ExchangeOrderRepository _mainnetOrderRepository;
  final ExchangeOrderRepository _testnetOrderRepository;

  GetSwapCounterpartTransactionUsecase({
    required SettingsRepository settingsRepository,
    required WalletTransactionRepository walletTransactionRepository,
    required SwapRepository mainnetSwapRepository,
    required SwapRepository testnetSwapRepository,
    required PayjoinRepository payjoinRepository,
    required ExchangeOrderRepository mainnetOrderRepository,
    required ExchangeOrderRepository testnetOrderRepository,
  }) : _settingsRepository = settingsRepository,
       _walletTransactionRepository = walletTransactionRepository,
       _mainnetSwapRepository = mainnetSwapRepository,
       _testnetSwapRepository = testnetSwapRepository,
       _payjoinRepository = payjoinRepository,
       _mainnetOrderRepository = mainnetOrderRepository,
       _testnetOrderRepository = testnetOrderRepository;

  Future<Transaction?> execute(Transaction chainSwapTransaction) async {
    try {
      if (!chainSwapTransaction.isChainSwap) {
        // Currently only chain swap transactions can have a counterpart transaction,
        // since Lightning swaps come and go to external lightning wallets, but on-chain swaps
        // can be between a Bitcoin and a Liquid wallet in the app itself.
        return null;
      }

      final swap = chainSwapTransaction.swap! as ChainSwap;
      final walletId = chainSwapTransaction.walletId;
      final counterpartyWalletId =
          walletId == swap.sendWalletId
              ? swap.receiveWalletId
              : swap.sendWalletId;
      final counterpartyTxId =
          walletId == swap.sendWalletId ? swap.receiveTxId : swap.sendTxId;

      if (counterpartyWalletId == null || counterpartyTxId == null) {
        // If either the counterparty wallet ID or transaction ID is null,
        // we cannot find a counterpart transaction or the counterparty wallet
        // is not from the app itself.
        return null;
      }

      // Fetch settings to determine environment for swap repository
      final settings = await _settingsRepository.fetch();
      final isTestnet = settings.environment.isTestnet;
      final swapRepository =
          isTestnet ? _testnetSwapRepository : _mainnetSwapRepository;
      final orderRepository =
          isTestnet ? _testnetOrderRepository : _mainnetOrderRepository;

      // Get the wallet transactions, swap and payjoins with the counterparty txId
      final (
        walletTransactionsWithCounterpartyTxId,
        swapWithCounterpartyTxId,
        payjoinsWithCounterpartyTxId,
        orderWithCounterpartyTxId,
      ) = await (
            _walletTransactionRepository.getWalletTransactions(
              txId: counterpartyTxId,
            ),
            swapRepository.getSwapByTxId(counterpartyTxId),
            _payjoinRepository.getPayjoinsByTxId(counterpartyTxId),
            orderRepository.getOrderByTxId(counterpartyTxId),
          ).wait;

      // Compose the counterpart transaction from the fetched data
      if (walletTransactionsWithCounterpartyTxId.isNotEmpty) {
        WalletTransaction? walletTransactionWithCounterpartyWallet;
        try {
          // Find the wallet transaction that matches the counterparty wallet ID
          walletTransactionWithCounterpartyWallet =
              walletTransactionsWithCounterpartyTxId.firstWhere(
                (tx) => tx.walletId == counterpartyWalletId,
              );
        } catch (e) {
          // If no transaction is found, return null
          return null;
        }

        Payjoin? payjoinWithCounterpartyWallet;
        try {
          // Find the payjoin that matches the counterparty wallet ID
          payjoinWithCounterpartyWallet = payjoinsWithCounterpartyTxId
              .firstWhere((pj) => pj.walletId == counterpartyWalletId);
        } catch (e) {
          // If no payjoin is found, it will be null
          payjoinWithCounterpartyWallet = null;
        }

        return Transaction(
          walletTransaction: walletTransactionWithCounterpartyWallet,
          swap: swapWithCounterpartyTxId,
          payjoin: payjoinWithCounterpartyWallet,
          order: orderWithCounterpartyTxId,
        );
      } else if (swapWithCounterpartyTxId != null) {
        return Transaction(swap: swap);
      } else {
        // No swap found, so not a swap transaction and so no counterpart transaction.
        return null;
      }
    } catch (e) {
      throw GetSwapCounterpartTransactionException('$e');
    }
  }
}

class GetSwapCounterpartTransactionException implements Exception {
  final String message;

  GetSwapCounterpartTransactionException(this.message);
}
