import 'package:bb_mobile/core/router/app_routes.dart';
import 'package:bb_mobile/core/router/route_error_screen.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: AppRoutes.landing,
    routes: [
      // TODO: include base routes from features
    ],
    errorBuilder: (context, state) => const RouteErrorScreen(),
  );
}
