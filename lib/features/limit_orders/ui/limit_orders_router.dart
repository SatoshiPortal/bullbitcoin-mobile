import 'package:bull_exchange/bull_exchange.dart' show LimitOrdersNavigation;
import 'package:bb_mobile/features/limit_orders/public/limit_orders_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

final class LimitOrdersRouter {
  static final create = GoRoute(
    name: LimitOrdersNavigation.createName,
    path: LimitOrdersNavigation.createPath,
    builder: (context, state) =>
        locator<LimitOrdersFacade>().buildCreateScreen(),
  );
}
