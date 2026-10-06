import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

enum LimitOrdersRoute {
  create('/limit-orders/create'),
  details('/limit-orders/:orderId');

  final String path;

  const LimitOrdersRoute(this.path);
}

final class LimitOrdersRouter {
  static final routes = [
    GoRoute(
      name: LimitOrdersRoute.create.name,
      path: LimitOrdersRoute.create.path,
      builder: (context, state) =>
          locator<LimitOrdersFacade>().buildCreateScreen(),
    ),
    GoRoute(
      name: LimitOrdersRoute.details.name,
      path: LimitOrdersRoute.details.path,
      builder: (context, state) => locator<LimitOrdersFacade>()
          .buildDetailsScreen(state.pathParameters['orderId']!),
    ),
  ];
}
