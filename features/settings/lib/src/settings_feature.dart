import 'package:bull_exchange/bull_exchange.dart' show ExchangeAccessBuilder;
import 'package:exchange/exchange.dart' show Exchange, ExchangeAccess;
import 'package:flutter_bloc/flutter_bloc.dart' show RepositoryProvider;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart'
    show BuildContext, Builder, Widget;
import 'package:network/network.dart';
import 'package:primitives/primitives.dart' show Failure, Result;
import 'package:secrets/custody.dart' show SeedReferences;
import 'package:secrets/secrets.dart' show Secrets;
import 'package:secrets/storage.dart' show SecretsInventory;
import 'package:signers/storage.dart' show SignerDevices;
import 'package:swaps/order_swaps.dart' show OrderSwaps;
import 'package:swaps/swaps.dart' show SwapStore;
import 'package:sync/write.dart' show WalletNativeLifecycle;

import 'domain/watch_settings_service_health_usecase.dart';
import 'settings.dart';
import 'settings_menu.dart';
import 'ui/all_settings_screen.dart';
import 'ui/settings_search_view.dart';
import 'ui/settings_hub_bindings.dart';
import 'wallet_details/wallet_details_route.dart';

const _homePath = '/settings';
const _homeName = 'settings';
const _searchPath = 'search';
const _searchName = 'search';

final class SettingsFeature {
  final GoRoute route;

  const SettingsFeature._(this.route);

  /// The settings of one wallet, under the settings home: its public
  /// description, discovery and fail-closed deletion. [onDeleted] leaves the
  /// deleted wallet's screens.
  static GoRoute walletDetails({
    required SecretsInventory inventory,
    required SignerDevices devices,
    required WalletNativeLifecycle native,
    required SwapStore swaps,
    required OrderSwaps orders,
    required SeedReferences references,
    required Secrets secrets,
    required Future<Result<void, Failure>> Function(String walletId) discover,
    required void Function(BuildContext context) onDeleted,
  }) => walletDetailsRoute(
    inventory: inventory,
    devices: devices,
    native: native,
    swaps: swaps,
    orders: orders,
    references: references,
    secrets: secrets,
    discover: discover,
    onDeleted: onDeleted,
  );

  /// Resolves menu data and labels from the screen's current context.
  ///
  /// [menuScope] can provide inherited display inputs to both screens.
  /// [exchange] is resolved only when either menu is built.
  static SettingsFeature mount({
    SettingsMenu Function(BuildContext) menuOf = SettingsHubBindings.menuOf,
    SettingsLabels Function(BuildContext) labelsOf =
        SettingsHubBindings.labelsOf,
    required NetworkStatus status,
    required List<RouteBase> childRoutes,
    List<RouteBase> appSettingsRoutes = const [],
    Settings Function()? settings,
    Exchange Function()? exchange,
    Widget Function(Widget child)? menuScope,
  }) {
    Widget scoped(Widget child) {
      final menu = menuScope?.call(child) ?? child;
      if (exchange == null) return menu;
      return ExchangeAccessBuilder(
        exchange: exchange(),
        builder: (_, access) => RepositoryProvider<ExchangeAccess>.value(
          value: access,
          child: menu,
        ),
      );
    }

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
          if (settings != null) ...[
            ...Settings.walletRoutes(),
            Settings.appSettingsRoute(appSettingsRoutes, settings: settings),
          ],
          ...childRoutes,
        ],
      ),
    );
  }
}

abstract final class SettingsNavigation {
  /// Where the settings hub is mounted; hosts nest their routes below it.
  static const homePath = _homePath;

  static Future<void> open(BuildContext context) =>
      context.pushNamed<void>(_homeName);

  static Future<void> openSearch(BuildContext context) =>
      context.pushNamed<void>(_searchName);

  static Future<void> openWalletDetails(
    BuildContext context, {
    required String walletId,
  }) => context.pushNamed<void>(
    walletDetailsRouteName,
    pathParameters: {'walletId': walletId},
  );
}
