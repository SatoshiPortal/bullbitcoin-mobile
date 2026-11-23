import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'exchange_landing_copy.dart';
import 'exchange_landing_navigation.dart';
import 'settings/ui/exchange_settings_router.dart';
import 'support_chat/exchange_support_chat_navigation.dart';
import 'support_chat/ui/exchange_support_chat_router.dart';
import 'ui/screens/exchange_landing_screen.dart';
import 'ui/screens/exchange_landing_screen_v2.dart';

typedef ExchangeSupportChatHost = ({
  Exchange Function() exchange,
  bool Function(BuildContext) isLoggedIn,
  Widget Function(ExchangeSupportChatDraft?) loginScreenBuilder,
  void Function(BuildContext, bool fromExchange) onExit,
});

/// Mounts Exchange routes in their host's navigation slots.
final class BullExchangeFeature {
  final List<RouteBase> routes;
  final GoRoute? supportChatRoute;
  final List<RouteBase> settingsRoutes;

  const BullExchangeFeature._(
    this.routes,
    this.supportChatRoute,
    this.settingsRoutes,
  );

  static BullExchangeFeature mount({
    required Future<bool> Function() networkUnavailable,
    required bool Function(BuildContext) showWebsiteOnly,
    required String unavailableRedirectPath,
    required String brandAssetPath,
    required ExchangeLandingCopy Function(BuildContext) copy,
    required void Function(BuildContext) onSignIn,
    required void Function(BuildContext) onExit,
    ExchangeSupportChatHost? supportChat,
    ExchangeSettingsHost? settings,
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
    supportChat == null
        ? null
        : ExchangeSupportChatRouter.route(
            exchange: supportChat.exchange,
            isLoggedIn: supportChat.isLoggedIn,
            loginScreenBuilder: supportChat.loginScreenBuilder,
            onExit: supportChat.onExit,
          ),
    settings == null
        ? const []
        : List.unmodifiable(ExchangeSettingsRouter.routes(settings)),
  );
}
