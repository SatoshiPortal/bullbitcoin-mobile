import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/transactions/application/usecases/label_exchange_orders_usecase.dart';

export 'domain/entities/transaction_input.dart'
    show TransactionInput, BitcoinTransactionInput, LiquidTransactionInput;
export 'domain/entities/transaction_output.dart'
    show TransactionOutput, BitcoinTransactionOutput, LiquidTransactionOutput;
export 'domain/entities/wallet_transaction.dart'
    show
        WalletTransaction,
        $WalletTransactionCopyWith,
        WalletTransactionDirection,
        WalletTransactionStatus;

export 'domain/repositories/wallet_transaction_repository.dart'
    show WalletTransactionRepository;
export 'domain/usecases/get_wallet_transaction_usecase.dart'
    show GetWalletTransactionUsecase;
export 'domain/usecases/get_wallet_transactions_usecase.dart'
    show GetWalletTransactionsUsecase, GetWalletTransactionsException;
export 'domain/usecases/watch_wallet_transaction_by_address_usecase.dart'
    show WatchWalletTransactionByAddressUsecase;
export 'domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart'
    show WatchWalletTransactionByTxIdUsecase;

/// Public contract of the transactions feature for other features.
class TransactionsFacade {
  final LabelExchangeOrdersUsecase _labelExchangeOrdersUsecase;

  TransactionsFacade({required this._labelExchangeOrdersUsecase});

  /// Writes privileged exchange labels for orders that explicitly completed.
  /// History reads must never trigger this (issue #2624): only call it from
  /// an explicit order-completion event.
  Future<void> labelCompletedExchangeOrders(List<Order> orders) =>
      _labelExchangeOrdersUsecase.execute(
        orders: orders,
        explicitCompletion: true,
      );
}
