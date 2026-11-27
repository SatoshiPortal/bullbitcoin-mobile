import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:secrets/storage.dart' show SecretsInventory;

import 'data/secrets_views_port.dart';
import 'domain/views_port.dart';
import 'presentation/views_cubit.dart';
import 'ui/view_switcher.dart';
import 'ui/views_screen.dart';

/// The typed route of the list of views.
final class ViewsRouteData {
  const ViewsRouteData();

  static const name = 'views';
  static const path = '/views';

  Future<void> push(BuildContext context) => context.pushNamed<void>(name);
}

/// Mounts the views screens. With [enabled] false, the production state, it
/// contributes no route and every widget it builds is empty: the gate decides
/// nothing about access, it only keeps the screens out of a build that cannot
/// open more than one view.
final class ViewsFeature {
  final bool enabled;
  final ViewsPort? _port;

  /// Routes to register in the root router. Empty while the gate is closed.
  final List<RouteBase> routes;

  ViewsFeature._(this.enabled, this._port, this.routes);

  factory ViewsFeature.mount({
    required SecretsInventory inventory,
    required bool enabled,
  }) => ViewsFeature._forPort(
    enabled ? SecretsViewsPort(inventory) : null,
    enabled: enabled,
  );

  /// For tests: the same feature over any [ViewsPort].
  @visibleForTesting
  factory ViewsFeature.forPort(ViewsPort port, {required bool enabled}) =>
      ViewsFeature._forPort(port, enabled: enabled);

  factory ViewsFeature._forPort(ViewsPort? port, {required bool enabled}) {
    final routes = enabled && port != null
        ? <RouteBase>[
            GoRoute(
              name: ViewsRouteData.name,
              path: ViewsRouteData.path,
              builder: (context, state) => BlocProvider(
                create: (_) => ViewsCubit(port),
                child: ViewsScreen(onBack: () => context.pop()),
              ),
            ),
          ]
        : const <RouteBase>[];
    return ViewsFeature._(enabled, port, routes);
  }

  /// The switcher of the view in use; empty while the gate is closed.
  Widget switcher() {
    final port = _port;
    if (!enabled || port == null) return const SizedBox.shrink();
    return BlocProvider(
      create: (_) => ViewsCubit(port),
      child: const ViewSwitcher(),
    );
  }
}
