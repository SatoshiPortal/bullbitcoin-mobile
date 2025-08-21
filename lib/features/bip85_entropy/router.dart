import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:bb_mobile/features/bip85_entropy/ui/bip85_home_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum Bip85EntropyRoute {
  home('/bip85-home');

  final String path;

  const Bip85EntropyRoute(this.path);
}

class Bip85EntropyRouter {
  static final route = ShellRoute(
    builder:
        (context, state, child) => BlocProvider(
          create: (_) => locator<Bip85EntropyCubit>(),
          child: child,
        ),
    routes: [
      GoRoute(
        name: Bip85EntropyRoute.home.name,
        path: Bip85EntropyRoute.home.path,
        builder: (context, state) => const Bip85HomePage(),
        routes: const [],
      ),
    ],
  );
}
