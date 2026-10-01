import 'package:bb_mobile/features/autobuy/public/autobuy_facade.dart';
import 'package:bb_mobile/locator.dart';
import 'package:go_router/go_router.dart';

enum AutoBuyRoute {
  autoBuy('/auto-buy');

  final String path;

  const AutoBuyRoute(this.path);
}

class AutoBuyRouter {
  static final route = GoRoute(
    name: AutoBuyRoute.autoBuy.name,
    path: AutoBuyRoute.autoBuy.path,
    builder: (context, state) => locator<AutoBuyFacade>().buildScreen(),
  );
}
