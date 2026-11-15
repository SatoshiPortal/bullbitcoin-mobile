import 'package:bb_mobile/features/transactions/presentation/blocs/transaction_explorer/transaction_explorer_cubit.dart';
import 'package:bb_mobile/features/transactions/public/transaction_explorer_route.dart';
import 'package:bb_mobile/features/transactions/ui/screens/transaction_explorer_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class TransactionExplorerRouter {
  static final route = GoRoute(
    name: TransactionExplorerRoute.transactionExplorer.name,
    path: TransactionExplorerRoute.transactionExplorer.path,
    builder: (context, state) {
      final args = state.extra;
      if (args is! TransactionExplorerArgs) {
        return const TransactionExplorerUnavailableScreen();
      }
      return BlocProvider(
        create: (_) => GetIt.I<TransactionExplorerCubit>(param1: args)..load(),
        child: const TransactionExplorerScreen(),
      );
    },
  );
}
