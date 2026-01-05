import 'package:bb_mobile/features/virtual_iban/domain/virtual_iban_location.dart';
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
  static ShellRoute createRoute(VirtualIbanLocation location) {
    return ShellRoute(
      builder: (context, state, child) {
        return BlocProvider(
          create: (_) =>
              locator<VirtualIbanBloc>(param1: location)
                ..add(const VirtualIbanEvent.started()),
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
        state.maybeWhen(
          pending: (_, _, _, _) {
            // Navigate to pending screen when VIBAN is created but not active
            context.goNamed(VirtualIbanRoute.pending.name);
          },
          active: (_, _, _) {
            // Navigate to active screen when VIBAN is activated
            context.goNamed(VirtualIbanRoute.active.name);
          },
          orElse: () {},
        );
      },
      builder: (context, state) {
        return state.maybeWhen(
          notSubmitted: (_, _, _, _, _) => const VirtualIbanIntroScreen(),
          pending: (_, _, _, _) => const VirtualIbanPendingScreen(),
          active: (_, _, _) => const VirtualIbanActiveScreen(),
          error: (exception) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: $exception')),
          ),
          orElse: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
        );
      },
    );
  }
}
