import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/order_swaps.dart';
import 'package:sync/sync.dart';

import '../transactions.dart';
import 'domain/repositories/wallet_transaction_repository.dart';
import 'domain/usecases/label_exchange_orders_usecase.dart';
import 'domain/usecases/wallet_history_events.dart';
import 'domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'domain/usecases/watch_wallet_transaction_by_tx_id_usecase.dart';
import 'presentation/blocs/transactions_cubit.dart';
import 'transactions_locator.dart';
import 'ui/transaction_ui_actions.dart';
import 'ui/transactions_router.dart';

final class TransactionsFeature {
  final List<RouteBase> routes;

  final GetIt _services;

  TransactionsFeature._(this._services, List<RouteBase> routes)
    : routes = List.unmodifiable(routes);

  Widget scopeWalletHistory(String walletId, Widget child) => BlocProvider(
    key: ValueKey(walletId),
    create: (_) => _services<TransactionsCubit>(param1: walletId)..loadTxs(),
    child: child,
  );

  static TransactionsFeature mount(
    GetIt services, {
    required WalletInventory inventory,
    required Future<Result<Wallet, SyncFailure>> Function(WalletKey) loadWallet,
    required Future<Result<PublicWalletDescriptor, SyncFailure>> Function(
      WalletKey,
    )
    findDescriptor,
    required Future<Result<void, SyncFailure>> Function(PublicWalletDescriptor)
    synchronize,
    required WalletHistoryEvents events,
    required Stream<String> Function() syncStarted,
    required Stream<String> Function() syncFinished,
    required ReadOrderSwaps Function() orderSwaps,
    required TransactionUiActions actions,
    required Widget Function(Widget) scope,
  }) {
    services.registerFactory<ReadOrderSwaps>(orderSwaps);
    TransactionsLocator.registerHistory(
      services,
      inventory: inventory,
      loadWallet: loadWallet,
      findDescriptor: findDescriptor,
      synchronize: synchronize,
      events: events,
    );
    TransactionsLocator.registerAdapters(services);
    TransactionsLocator.registerUsecases(services);
    TransactionsLocator.registerBlocs(
      services,
      events,
      syncStarted,
      syncFinished,
    );
    services.registerLazySingleton<Transactions>(
      () => _Transactions(
        services<WalletTransactionRepository>(),
        services<WatchWalletTransactionByAddressUsecase>(),
        services<WatchWalletTransactionByTxIdUsecase>(),
        services<LabelExchangeOrdersUsecase>(),
      ),
    );
    final router = TransactionsRouter(services, actions);
    return TransactionsFeature._(services, [
      router.transactionsRoute(scope: scope),
      router.exchangeTransactionsRoute,
      router.exportTransactionsRoute,
      ...router.transactionDetailsRoutes,
    ]);
  }
}

final class _Transactions implements Transactions {
  final WalletTransactionRepository _wallet;
  final WatchWalletTransactionByAddressUsecase _byAddress;
  final WatchWalletTransactionByTxIdUsecase _byTxId;
  final LabelExchangeOrdersUsecase _labelOrders;

  const _Transactions(
    this._wallet,
    this._byAddress,
    this._byTxId,
    this._labelOrders,
  );

  @override
  Future<Result<WalletTransaction?, TransactionFailure>> getWalletTransaction(
    String txId, {
    required String walletId,
    bool sync = false,
  }) => _wallet.getWalletTransaction(txId, walletId: walletId, sync: sync);

  @override
  Future<Result<List<WalletTransaction>, TransactionFailure>>
  getWalletTransactions({required String walletId, bool sync = false}) =>
      _wallet.getWalletTransactions(walletId: walletId, sync: sync);

  @override
  Stream<WalletTransaction> watchWalletTransactionByAddress({
    required String walletId,
    required String toAddress,
  }) => _byAddress.execute(walletId: walletId, toAddress: toAddress);

  @override
  Stream<WalletTransaction> watchWalletTransactionByTxId({
    required String walletId,
    required String txId,
  }) => _byTxId.execute(walletId: walletId, txId: txId);

  @override
  Future<void> labelCompletedExchangeOrders(List<Order> orders) =>
      _labelOrders.execute(orders: orders, explicitCompletion: true);
}
