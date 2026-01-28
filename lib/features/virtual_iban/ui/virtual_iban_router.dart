import 'package:bb_mobile/features/virtual_iban/presentation/virtual_iban_bloc.dart';
import 'package:bb_mobile/features/virtual_iban/ui/screens/virtual_iban_active_screen.dart';
import 'package:bb_mobile/features/virtual_iban/ui/screens/virtual_iban_details_screen.dart';
import 'package:bb_mobile/features/virtual_iban/ui/screens/virtual_iban_intro_screen.dart';
import 'package:bb_mobile/features/virtual_iban/ui/screens/virtual_iban_pending_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum VirtualIbanRoute {
  intro('/virtual-iban'),
  pending('pending'),
  active('active'),
  details('details');

  final String path;
  const VirtualIbanRoute(this.path);
}

class VirtualIbanRouter {
  /// Creates a shell route that provides the singleton VirtualIbanBloc.
  /// No location parameter needed - the bloc is a singleton that's already loaded.
  static ShellRoute createRoute() {
    return ShellRoute(
      builder: (context, state, child) {
        // Use the singleton bloc - it's already loaded on app start
        return BlocProvider.value(
          value: locator<VirtualIbanBloc>(),
          child: child,
        );
      },
      routes: [
        GoRoute(
          name: VirtualIbanRoute.intro.name,
          path: VirtualIbanRoute.intro.path,
          builder: (context, state) {
            return const _VirtualIbanStateRouter();
          },
          routes: [
            GoRoute(
              name: VirtualIbanRoute.pending.name,
              path: VirtualIbanRoute.pending.path,
              builder: (context, state) => const VirtualIbanPendingScreen(),
            ),
            GoRoute(
              name: VirtualIbanRoute.active.name,
              path: VirtualIbanRoute.active.path,
              builder: (context, state) => const VirtualIbanActiveScreen(),
            ),
            GoRoute(
              name: VirtualIbanRoute.details.name,
              path: VirtualIbanRoute.details.path,
              builder: (context, state) => const VirtualIbanDetailsScreen(),
            ),
          ],
        ),
      ],
    );
  }

  /// Alternative: Routes that can be added as nested routes under fund_exchange, etc.
  static List<RouteBase> get nestedRoutes => [
    GoRoute(
      name: VirtualIbanRoute.pending.name,
      path: VirtualIbanRoute.pending.path,
      builder: (context, state) => const VirtualIbanPendingScreen(),
    ),
    GoRoute(
      name: VirtualIbanRoute.active.name,
      path: VirtualIbanRoute.active.path,
      builder: (context, state) => const VirtualIbanActiveScreen(),
    ),
    GoRoute(
      name: VirtualIbanRoute.details.name,
      path: VirtualIbanRoute.details.path,
      builder: (context, state) => const VirtualIbanDetailsScreen(),
    ),
  ];
}

/// Widget that routes to the appropriate VIBAN screen based on state.
class _VirtualIbanStateRouter extends StatelessWidget {
  const _VirtualIbanStateRouter();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VirtualIbanBloc, VirtualIbanState>(
      listenWhen: (previous, current) {
        // Listen for state transitions to navigate
        return previous.runtimeType != current.runtimeType;
      },
      listener: (context, state) {
        if (state.isPending) {
          // Navigate to pending screen when VIBAN is created but not active
          context.goNamed(VirtualIbanRoute.pending.name);
        } else if (state.isActive) {
          // Navigate to active screen when VIBAN is activated
          context.goNamed(VirtualIbanRoute.active.name);
        }
      },
      builder: (context, state) {
        if (state.isNotSubmitted) {
          return const VirtualIbanIntroScreen();
        } else if (state.isPending) {
          return const VirtualIbanPendingScreen();
        } else if (state.isActive) {
          return const VirtualIbanActiveScreen();
        } else if (state.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text(
                'Error: ${(state as VirtualIbanErrorState).exception}',
              ),
            ),
          );
        } else {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}
