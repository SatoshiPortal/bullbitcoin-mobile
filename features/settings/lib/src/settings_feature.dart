import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart'
    show BuildContext, Builder, Widget;
import 'package:network/network.dart';

import 'domain/watch_settings_service_health_usecase.dart';
import 'settings_menu.dart';
import 'ui/all_settings_screen.dart';
import 'ui/settings_search_view.dart';
import 'ui/settings_hub_bindings.dart';

const _homePath = '/settings';
const _homeName = 'settings';
const _searchPath = 'search';
const _searchName = 'search';

final class SettingsFeature {
  final GoRoute route;

  const SettingsFeature._(this.route);

  /// Resolves menu data and labels from the screen's current context.
  ///
  /// [menuScope] can provide inherited display inputs to both screens.
  static SettingsFeature mount({
    SettingsMenu Function(BuildContext) menuOf = SettingsHubBindings.menuOf,
    SettingsLabels Function(BuildContext) labelsOf =
        SettingsHubBindings.labelsOf,
    required NetworkStatus status,
    required List<RouteBase> childRoutes,
    Widget Function(Widget child)? menuScope,
  }) {
    Widget scoped(Widget child) => menuScope?.call(child) ?? child;

    return SettingsFeature._(
      GoRoute(
        name: _homeName,
        path: _homePath,
        builder: (_, _) => scoped(
          AllSettingsScreen(
            menuOf: menuOf,
            labelsOf: labelsOf,
            openSearch: SettingsNavigation.openSearch,
            watchServiceHealth: WatchSettingsServiceHealthUsecase(status)
                .execute,
          ),
        ),
        routes: [
          GoRoute(
            name: _searchName,
            path: _searchPath,
            builder: (_, _) => scoped(
              Builder(
                builder: (context) => SettingsSearchView(
                  items: menuOf(context).entries,
                  labels: labelsOf(context),
                ),
              ),
            ),
          ),
          ...childRoutes,
        ],
      ),
    );
  }
}

abstract final class SettingsNavigation {
  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(_homeName);

  static Future<void> openSearch(BuildContext context) =>
      context.pushNamed<void>(_searchName);
}
