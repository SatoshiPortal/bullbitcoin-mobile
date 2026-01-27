import 'package:bb_mobile/core/infra/di/core_dependencies.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transaction_details_screen.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transactions_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum TransactionsRoute {
  transactions('/transactions'),
  transactionDetails('/transaction/:txId'),
  swapTransactionDetails('/transaction/swap/:swapId'),
  payjoinTransactionDetails('/transaction/payjoin/:payjoinId'),
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
        create: (context) => sl<TransactionsCubit>()..loadTxs(),
        child: const TransactionsScreen(),
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
              sl<TransactionDetailsCubit>()
                ..initByWalletTxId(txId, walletId: walletId),
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
              sl<TransactionDetailsCubit>()
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
              sl<TransactionDetailsCubit>()..initByPayjoinId(payjoinId),
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
              sl<TransactionDetailsCubit>()..initByOrderId(orderId),
          child: const TransactionDetailsScreen(),
        );
      },
    ),
  ];
}
