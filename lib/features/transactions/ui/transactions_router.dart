import 'package:bb_mobile/features/transactions/domain/entities/transaction.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_details/transaction_details_cubit.dart';
import 'package:bb_mobile/features/transactions/presentation/blocs/transactions_cubit.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transaction_details_screen.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transactions_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum TransactionsRoute {
  transactions('transactions'),
  transactionDetails('details');

  const TransactionsRoute(this.path);

  final String path;
}

/// The router for the transactions feature.
class TransactionsRouter {
  static final route = GoRoute(
    name: TransactionsRoute.transactions.name,
    path: TransactionsRoute.transactions.path,
    builder: (context, state) {
      return BlocProvider(
        create: (context) => locator<TransactionsCubit>()..loadTxs(),
        child: const TransactionsScreen(),
      );
    },
    routes: [
      GoRoute(
        name: TransactionsRoute.transactionDetails.name,
        path: TransactionsRoute.transactionDetails.path,
        builder: (context, state) {
          final tx = state.extra! as Transaction;
          return BlocProvider(
            create: (context) => locator<TransactionDetailsCubit>()..init(tx),
            child: const TransactionDetailsScreen(),
          );
        },
      ),
    ],
  );
}
