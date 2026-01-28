import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_bloc.dart';
import 'package:bb_mobile/features/bitaxe/presentation/bloc/bitaxe_event.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'screens/bitaxe_connection_screen.dart';
import 'screens/bitaxe_dashboard_screen.dart';
import 'screens/bitaxe_entry_screen.dart';
import 'screens/bitaxe_success_screen.dart';

enum BitaxeRoute {
  entry('bitaxe'),
  connection('bitaxe/connect'),
  dashboard('bitaxe/dashboard'),
  success('bitaxe/success');

  const BitaxeRoute(this.path);
  final String path;
}

class BitaxeRouter {
  static final routes = [
    ShellRoute(
      builder: (context, state, child) {
        return BlocProvider<BitaxeBloc>(
          create: (_) => locator<BitaxeBloc>(),
          child: child,
        );
      },
      routes: [
        GoRoute(
          name: BitaxeRoute.entry.name,
          path: BitaxeRoute.entry.path,
          builder: (context, state) {
            final bloc = context.read<BitaxeBloc>();
            bloc.add(const BitaxeEvent.loadStoredConnection());
            return const BitaxeEntryScreen();
          },
        ),
        GoRoute(
          name: BitaxeRoute.connection.name,
          path: BitaxeRoute.connection.path,
          builder: (context, state) => const BitaxeConnectionScreen(),
        ),
        GoRoute(
          name: BitaxeRoute.dashboard.name,
          path: BitaxeRoute.dashboard.path,
          builder: (context, state) => const BitaxeDashboardScreen(),
        ),
        GoRoute(
          name: BitaxeRoute.success.name,
          path: BitaxeRoute.success.path,
          builder: (context, state) => const BitaxeSuccessScreen(),
        ),
      ],
    ),
  ];
}
