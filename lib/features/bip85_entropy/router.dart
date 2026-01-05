import 'package:bb_mobile/features/bip85_entropy/bip85_home_page.dart';
import 'package:bb_mobile/features/bip85_entropy/presentation/cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:bb_mobile/core/infra/di/core_dependencies.dart';

enum Bip85EntropyRoute {
  bip85Home('/bip85-home');

  final String path;

  const Bip85EntropyRoute(this.path);
}

class Bip85EntropyRouter {
  static final route = ShellRoute(
    builder: (context, state, child) =>
        BlocProvider(create: (_) => sl<Bip85EntropyCubit>(), child: child),
    routes: [
      GoRoute(
        name: Bip85EntropyRoute.bip85Home.name,
        path: Bip85EntropyRoute.bip85Home.path,
        builder: (context, state) => const Bip85HomePage(),
        routes: const [],
      ),
    ],
  );
}
