import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/get_paid/presentation/get_paid_transaction_history_cubit.dart';
import 'package:bb_mobile/features/get_paid/public/get_paid_routes.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_dashboard_screen.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_transaction_detail_screen.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_transaction_history_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The Get Paid hub route. Registered inside the root [ShellRoute] alongside the
/// wallet and exchange tabs so it shares the bottom navigation bar.
class GetPaidRouter {
  const GetPaidRouter._();

  static final route = GoRoute(
    name: GetPaidDashboardRoute.getPaidHome.name,
    path: GetPaidDashboardRoute.getPaidHome.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<GetPaidDashboardCubit>(),
      child: const GetPaidDashboardScreen(),
    ),
    routes: [
      GoRoute(
        name: GetPaidDashboardRoute.getPaidTransactions.name,
        path: GetPaidDashboardRoute.getPaidTransactions.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<GetPaidTransactionHistoryCubit>(),
          child: const GetPaidTransactionHistoryScreen(),
        ),
        routes: [
          GoRoute(
            name: GetPaidDashboardRoute.getPaidTransactionDetail.name,
            path: GetPaidDashboardRoute.getPaidTransactionDetail.path,
            redirect: (context, state) => state.extra is GetPaidTransaction
                ? null
                : '${GetPaidDashboardRoute.getPaidHome.path}/'
                      '${GetPaidDashboardRoute.getPaidTransactions.path}',
            builder: (context, state) => GetPaidTransactionDetailScreen(
              transaction: state.extra! as GetPaidTransaction,
            ),
          ),
        ],
      ),
    ],
  );
}
