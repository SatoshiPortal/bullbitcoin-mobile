import 'package:bb_mobile/features/home/presentation/home_screen.dart';
import 'package:go_router/go_router.dart';

enum HomeRoute {
  home('/');

  final String path;

  const HomeRoute(this.path);
}

class HomeRouter {
  static final route = GoRoute(
    name: HomeRoute.home.name,
    path: HomeRoute.home.path,
    pageBuilder: (context, state) => const NoTransitionPage(
      child: HomeScreen(),
    ),
  );
}
