import 'package:bb_mobile/features/transactions/presentation/blocs/export/export_transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/screens/export_transactions_screen.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transaction_details_screen.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transactions_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum TransactionsRoute {
  transactions('/transactions'),
  exportTransactions('/transactions/export'),
  transactionDetails('/transaction/:txId'),
  swapTransactionDetails('/transaction/swap/:swapId'),
  payjoinTransactionDetails('/transaction/payjoin/:payjoinId'),
  payjoinTransactionDetailsByTxId('/transaction/payjoin/tx/:txId'),
  orderSwapTransactionDetails('/transaction/order-swap/:localId'),
  orderTransactionDetails('/transaction/order/:orderId');

  const TransactionsRoute(this.path);

  final String path;
}

/// The router for the transactions feature.
class TransactionsRouter {
  static final transactionsRoute = GoRoute(
    name: TransactionsRoute.transactions.name,
    path: TransactionsRoute.transactions.path,
    builder: (context, state) {
      // final filterParam = state.uri.queryParameters['filter'];
      return BlocProvider(
        create: (context) => locator<TransactionsCubit>()..loadTxs(),
        child: const TransactionsScreen(),
      );
    },
  );

  static final exportTransactionsRoute = GoRoute(
    name: TransactionsRoute.exportTransactions.name,
    path: TransactionsRoute.exportTransactions.path,
    builder: (context, state) {
      return BlocProvider(
        create: (context) => locator<ExportTransactionsCubit>(),
        child: const ExportTransactionsScreen(),
      );
    },
  );

  static final transactionDetailsRoutes = [
    GoRoute(
      name: TransactionsRoute.transactionDetails.name,
      path: TransactionsRoute.transactionDetails.path,
      builder: (context, state) {
        final txId = state.pathParameters['txId']!;
        final walletId = state.uri.queryParameters['walletId']!;
        return BlocProvider(
          create: (context) =>
              locator<TransactionDetailsCubit>()
                ..initByWalletTxId(txId, walletId: walletId),
          child: const TransactionDetailsScreen(),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.payjoinTransactionDetailsByTxId.name,
      path: TransactionsRoute.payjoinTransactionDetailsByTxId.path,
      builder: (context, state) {
        final txId = state.pathParameters['txId']!;
        return BlocProvider(
          create: (context) =>
              locator<TransactionDetailsCubit>()..initByPayjoinTxId(txId),
          child: const TransactionDetailsScreen(),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.swapTransactionDetails.name,
      path: TransactionsRoute.swapTransactionDetails.path,
      builder: (context, state) {
        final swapId = state.pathParameters['swapId']!;
        final walletId = state.uri.queryParameters['walletId']!;
        return BlocProvider(
          create: (context) =>
              locator<TransactionDetailsCubit>()
                ..initBySwapId(swapId, walletId: walletId),
          child: const TransactionDetailsScreen(),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.payjoinTransactionDetails.name,
      path: TransactionsRoute.payjoinTransactionDetails.path,
      builder: (context, state) {
        final payjoinId = state.pathParameters['payjoinId']!;
        return BlocProvider(
          create: (context) =>
              locator<TransactionDetailsCubit>()..initByPayjoinId(payjoinId),
          child: const TransactionDetailsScreen(),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.orderSwapTransactionDetails.name,
      path: TransactionsRoute.orderSwapTransactionDetails.path,
      builder: (context, state) {
        final localId = state.pathParameters['localId']!;
        return BlocProvider(
          create: (context) =>
              locator<TransactionDetailsCubit>()
                ..initByOrderSwapLocalId(localId),
          child: const TransactionDetailsScreen(),
        );
      },
    ),
    GoRoute(
      name: TransactionsRoute.orderTransactionDetails.name,
      path: TransactionsRoute.orderTransactionDetails.path,
      builder: (context, state) {
        final orderId = state.pathParameters['orderId']!;
        return BlocProvider(
          create: (context) =>
              locator<TransactionDetailsCubit>()..initByOrderId(orderId),
          child: const TransactionDetailsScreen(),
        );
      },
    ),
  ];
}
