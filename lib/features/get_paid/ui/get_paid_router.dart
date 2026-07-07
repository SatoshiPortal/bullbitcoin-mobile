import 'package:bb_mobile/features/get_paid/presentation/get_paid_dashboard_cubit.dart';
import 'package:bb_mobile/features/get_paid/ui/screens/get_paid_dashboard_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum GetPaidDashboardRoute {
  getPaidHome('/get-paid');

  final String path;

  const GetPaidDashboardRoute(this.path);
}

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
  );
}
