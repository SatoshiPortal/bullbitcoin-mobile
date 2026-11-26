import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'domain/usecases/cancel_limit_order_usecase.dart';
import 'domain/usecases/get_limit_order_usecase.dart';
import 'limit_orders_navigation.dart';
import 'presentation/limit_order_details_bloc.dart';
import 'presentation/limit_orders_list_bloc.dart';
import 'ui/screens/limit_order_details_screen.dart';
import 'ui/widgets/limit_orders_dashboard_card.dart';

GoRoute limitOrderDetailsRoute(Exchange Function() exchange) => GoRoute(
  name: LimitOrdersNavigation.detailsName,
  path: LimitOrdersNavigation.detailsPath,
  builder: (context, state) {
    final id = state.pathParameters['orderId'];
    if (id == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) {
        final capability = exchange();
        return LimitDetailsBloc(
          session: capability.currentSession,
          orderId: id,
          accessChanges: capability.watchAccess(),
          getOrder: GetLimitOrderUsecase(capability),
          cancelOrder: CancelLimitOrderUsecase(capability),
        );
      },
      child: const LimitOrderDetailsScreen(),
    );
  },
);

class LimitOrdersManagementCard extends StatelessWidget {
  final Exchange Function() exchange;
  final Stream<void> refreshRequests;

  const LimitOrdersManagementCard({
    required this.exchange,
    required this.refreshRequests,
    super.key,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) {
      final capability = exchange();
      return LimitOrdersListBloc(
        calls: limitOrdersListCallsOf(capability, capability.currentSession),
        notifications: capability.notifications,
        refreshRequests: refreshRequests,
      );
    },
    child: const LimitOrdersDashboardCard(),
  );
}
