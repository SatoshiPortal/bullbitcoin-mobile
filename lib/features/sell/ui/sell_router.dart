import 'package:bb_mobile/features/sell/ui/sell_screen.dart';
import 'package:go_router/go_router.dart';

enum SellRoute {
  sell('/sell');

  final String path;

  const SellRoute(this.path);
}

class SellRouter {
  static final route = GoRoute(
    name: SellRoute.sell.name,
    path: SellRoute.sell.path,
    builder: (context, state) => const SellScreen(),
  );
}
