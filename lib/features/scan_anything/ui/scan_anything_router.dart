import 'package:bb_mobile/features/scan_anything/presentation/scan_anything_cubit.dart';
import 'package:bb_mobile/features/scan_anything/public/scan_anything_route.dart';
import 'package:bb_mobile/features/scan_anything/ui/screens/scan_anything_screen.dart';
import 'package:bb_mobile/features/scan_anything/ui/screens/scan_result_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class ScanAnythingRouter {
  static final route = ShellRoute(
    builder: (context, state, child) =>
        BlocProvider(create: (_) => GetIt.I<ScanAnythingCubit>(), child: child),
    routes: [
      GoRoute(
        name: ScanAnythingRoute.scanAnything.name,
        path: ScanAnythingRoute.scanAnything.path,
        builder: (context, state) => const ScanAnythingScreen(),
        routes: [
          GoRoute(
            name: ScanAnythingRoute.scanAnythingResult.name,
            path: ScanAnythingRoute.scanAnythingResult.path,
            builder: (context, state) => const ScanResultScreen(),
          ),
        ],
      ),
    ],
  );
}
