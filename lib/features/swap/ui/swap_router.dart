import 'package:bb_mobile/features/swap/ui/swap_page.dart';
import 'package:go_router/go_router.dart';

enum SwapRoute {
  swap('/swap');

  final String path;

  const SwapRoute(this.path);
}

class SwapRouter {
  static final route = GoRoute(
    name: SwapRoute.swap.name,
    path: SwapRoute.swap.path,
    builder: (context, state) => const SwapFlow(),
  );
}
