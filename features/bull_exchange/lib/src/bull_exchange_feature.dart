import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'exchange_landing_copy.dart';
import 'exchange_landing_navigation.dart';
import 'ui/screens/exchange_landing_screen.dart';
import 'ui/screens/exchange_landing_screen_v2.dart';

/// Mounts the Exchange landing screens and contributes their route.
final class BullExchangeFeature {
  final List<RouteBase> routes;

  const BullExchangeFeature._(this.routes);

  static BullExchangeFeature mount({
    required Future<bool> Function() networkUnavailable,
    required bool Function(BuildContext) showWebsiteOnly,
    required String unavailableRedirectPath,
    required String brandAssetPath,
    required ExchangeLandingCopy Function(BuildContext) copy,
    required void Function(BuildContext) onSignIn,
    required void Function(BuildContext) onExit,
  }) => BullExchangeFeature._(
    List.unmodifiable([
      GoRoute(
        name: BullExchangeNavigation.landingName,
        path: BullExchangeNavigation.landingPath,
        redirect: (_, _) async =>
            await networkUnavailable() ? unavailableRedirectPath : null,
        pageBuilder: (context, state) {
          final labels = copy(context);
          void exit() => onExit(context);
          return NoTransitionPage(
            key: state.pageKey,
            child: showWebsiteOnly(context)
                ? ExchangeLandingScreenV2(
                    copy: labels,
                    brandAssetPath: brandAssetPath,
                    onExit: exit,
                  )
                : ExchangeLandingScreen(
                    copy: labels,
                    brandAssetPath: brandAssetPath,
                    onSignIn: () => onSignIn(context),
                    onExit: exit,
                  ),
          );
        },
      ),
    ]),
  );
}
