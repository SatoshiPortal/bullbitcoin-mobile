import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/presentation/screens/receive_screen.dart';
import 'package:bb_mobile/features/receive/presentation/screens/receive_success_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ReceiveRoute {
  receive('/receive'),
  //invoice('invoice'),
  success('success');

  final String path;

  const ReceiveRoute(this.path);
}

class ReceiveRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider<ReceiveBloc>(
        create: (context) => locator<ReceiveBloc>(),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: ReceiveRoute.receive.name,
        path: ReceiveRoute.receive.path,
        builder: (context, state) => const ReceiveScreen(),
        routes: [
          GoRoute(
            name: ReceiveRoute.success.name,
            path: ReceiveRoute.success.path,
            builder: (context, state) => const ReceiveSuccessScreen(),
          ),
        ],
      ),
    ],
  );
}
