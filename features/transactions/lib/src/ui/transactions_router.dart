import 'package:transactions/src/presentation/blocs/export/export_transactions_cubit.dart';
import 'package:transactions/src/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:transactions/src/presentation/blocs/transaction_status/transaction_status_cubit.dart';
import 'package:transactions/src/presentation/blocs/transactions_cubit.dart';
import 'package:transactions/src/ui/widgets/settlement_sync_poller.dart';
import 'package:transactions/src/ui/screens/export_transactions_screen.dart';
import 'package:transactions/src/ui/screens/transaction_details_screen.dart';
import 'package:transactions/src/ui/screens/transactions_screen.dart';
import 'package:get_it/get_it.dart';

import 'transaction_ui_actions.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widgets.dart' show Widget, SizedBox;
import 'package:go_router/go_router.dart';

import 'transactions_navigation.dart';

/// The router for the transactions feature.
class TransactionsRouter {
  final GetIt locator;
  final TransactionUiActions actions;
  final SettlementPoll pollSettlement;

  const TransactionsRouter(this.locator, this.actions, this.pollSettlement);

  /// The details screen with its own status cubit, next to the details cubit
  /// [create] starts.
  Widget _details(TransactionDetailsCubit Function() create) =>
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => create()),
          BlocProvider(
            create: (context) =>
                locator<TransactionStatusCubit>()..loadPreference(),
          ),
        ],
        child: TransactionDetailsScreen(
          actions: actions,
          pollSettlement: pollSettlement,
        ),
      );

  GoRoute transactionsRoute({required Widget Function(Widget) scope}) =>
      GoRoute(
        name: TransactionsRoute.transactions.name,
        path: TransactionsRoute.transactions.path,
        builder: (context, state) {
          // final filterParam = state.uri.queryParameters['filter'];
          return scope(
            BlocProvider(
              create: (context) => locator<TransactionsCubit>()..loadTxs(),
              child: TransactionsScreen(refreshWallets: actions.refreshWallets),
            ),
          );
        },
      );

  GoRoute get exchangeTransactionsRoute => GoRoute(
    name: TransactionsRoute.exchangeTransactions.name,
    path: TransactionsRoute.exchangeTransactions.path,
    builder: (context, state) => BlocProvider(
      create: (context) => locator<TransactionsCubit>(param2: true)..loadTxs(),
      child: TransactionsScreen(refreshWallets: actions.refreshWallets),
    ),
  );

  GoRoute get exportTransactionsRoute => GoRoute(
    name: TransactionsRoute.exportTransactions.name,
    path: TransactionsRoute.exportTransactions.path,
    builder: (context, state) {
      return BlocProvider(
        create: (context) => locator<ExportTransactionsCubit>(),
        child: const ExportTransactionsScreen(),
      );
    },
  );

  List<GoRoute> get transactionDetailsRoutes => [
    GoRoute(
      name: TransactionsRoute.transactionDetails.name,
      path: TransactionsRoute.transactionDetails.path,
      builder: (context, state) {
        final txId = state.pathParameters['txId'];
        final walletId = state.uri.queryParameters['walletId'];
        if (txId == null || walletId == null) return const SizedBox.shrink();
        return _details(
          () =>
              locator<TransactionDetailsCubit>()
                ..initByWalletTxId(txId, walletId: walletId),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.payjoinTransactionDetailsByTxId.name,
      path: TransactionsRoute.payjoinTransactionDetailsByTxId.path,
      builder: (context, state) {
        final txId = state.pathParameters['txId'];
        if (txId == null) return const SizedBox.shrink();
        return _details(
          () => locator<TransactionDetailsCubit>()..initByPayjoinTxId(txId),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.swapTransactionDetails.name,
      path: TransactionsRoute.swapTransactionDetails.path,
      builder: (context, state) {
        final swapId = state.pathParameters['swapId'];
        final walletId = state.uri.queryParameters['walletId'];
        if (swapId == null || walletId == null) return const SizedBox.shrink();
        return _details(
          () =>
              locator<TransactionDetailsCubit>()
                ..initBySwapId(swapId, walletId: walletId),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.payjoinTransactionDetails.name,
      path: TransactionsRoute.payjoinTransactionDetails.path,
      builder: (context, state) {
        final payjoinId = state.pathParameters['payjoinId'];
        if (payjoinId == null) return const SizedBox.shrink();
        return _details(
          () => locator<TransactionDetailsCubit>()..initByPayjoinId(payjoinId),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.orderSwapTransactionDetails.name,
      path: TransactionsRoute.orderSwapTransactionDetails.path,
      builder: (context, state) {
        final localId = state.pathParameters['localId'];
        if (localId == null) return const SizedBox.shrink();
        return _details(
          () =>
              locator<TransactionDetailsCubit>()
                ..initByOrderSwapLocalId(localId),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.orderTransactionDetails.name,
      path: TransactionsRoute.orderTransactionDetails.path,
      builder: (context, state) {
        final orderId = state.pathParameters['orderId'];
        if (orderId == null) return const SizedBox.shrink();
        return _details(
          () => locator<TransactionDetailsCubit>()..initByOrderId(orderId),
        );
      },
    ),
  ];
}
