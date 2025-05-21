import 'package:bb_mobile/features/buy/ui/buy_screen.dart';
import 'package:go_router/go_router.dart';

enum BuyRoute {
  buy('buy');

  final String path;

  const BuyRoute(this.path);
}

class BuyRouter {
  static final route = GoRoute(
    name: BuyRoute.buy.name,
    path: BuyRoute.buy.path,
    builder: (context, state) => const BuyScreen(),
  );
}
