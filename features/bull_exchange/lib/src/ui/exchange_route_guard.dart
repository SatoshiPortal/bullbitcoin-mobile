import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../autobuy/autobuy_mount.dart';
import '../buy/ui/buy_router.dart';
import '../dca/ui/dca_router.dart';
import '../default_wallets/ui/default_wallets_router.dart';
import '../exchange_l10n.dart';
import '../exchange_landing_navigation.dart';
import '../funding/fund_exchange_router.dart';
import '../limit_orders/limit_orders_navigation.dart';
import '../pay/ui/pay_router.dart';
import '../sell/ui/sell_router.dart';
import '../settings/ui/exchange_access_settings_route.dart';
import '../settings/ui/exchange_settings_route.dart';
import '../support_chat/exchange_support_chat_navigation.dart';
import '../withdraw/ui/withdraw_router.dart';

/// Whether a route needs a signed-in exchange account.
enum ExchangeRouteNeed { account, open }

/// The locations one [ExchangeRouteGuard] covers. Every path below an account
/// root needs the account too; open paths match exactly.
///
/// The exchange names only the routes it mounts: [mounted] at their own
/// absolute paths, and [settingsUnder] for the settings routes the host nests
/// under a path of its own. The host composes them and adds any routes of its
/// own that need an exchange account.
@immutable
final class ExchangeGuardedPaths {
  final List<String> accountRoots;
  final List<String> openPaths;

  const ExchangeGuardedPaths({
    this.accountRoots = const [],
    this.openPaths = const [],
  });

  /// The routes `BullExchangeFeature` mounts at absolute paths.
  static final mounted = ExchangeGuardedPaths(
    accountRoots: List.unmodifiable([
      BuyRoute.buy.path,
      SellRoute.sell.path,
      PayRoute.pay.path,
      WithdrawRoute.withdraw.path,
      for (final route in FundExchangeRoute.values)
        if (route.path.startsWith('/')) route.path,
      DcaRoute.dca.path,
      AutoBuyNavigation.path,
      LimitOrdersNavigation.root,
      BullExchangeNavigation.kycPath,
    ]),
    openPaths: const [
      BullExchangeNavigation.dashboardPath,
      BullExchangeNavigation.landingPath,
      BullExchangeNavigation.authPath,
      ExchangeSupportChatNavigation.path,
    ],
  );

  /// `BullExchangeFeature.settingsRoutes` as mounted under [parentPath].
  static ExchangeGuardedPaths settingsUnder(String parentPath) {
    final parent = parentPath.endsWith('/')
        ? parentPath.substring(0, parentPath.length - 1)
        : parentPath;
    final needs = {
      for (final route in ExchangeSettingsRoute.values)
        route.path: exchangeSettingsRouteNeed(route),
      ExchangeAccessSettingsNavigation.path: ExchangeRouteNeed.open,
      DefaultWalletsNavigation.path: ExchangeRouteNeed.account,
    };
    return ExchangeGuardedPaths(
      accountRoots: List.unmodifiable([
        for (final MapEntry(key: segment, value: need) in needs.entries)
          if (need == ExchangeRouteNeed.account) '$parent/$segment',
      ]),
      openPaths: List.unmodifiable([
        for (final MapEntry(key: segment, value: need) in needs.entries)
          if (need == ExchangeRouteNeed.open) '$parent/$segment',
      ]),
    );
  }

  ExchangeGuardedPaths operator +(ExchangeGuardedPaths other) =>
      ExchangeGuardedPaths(
        accountRoots: List.unmodifiable([
          ...accountRoots,
          ...other.accountRoots,
        ]),
        openPaths: List.unmodifiable([...openPaths, ...other.openPaths]),
      );

  /// Null for a location this guard doesn't cover.
  ExchangeRouteNeed? needOf(String path) {
    if (accountRoots.any((root) => path == root || path.startsWith('$root/'))) {
      return ExchangeRouteNeed.account;
    }
    if (openPaths.contains(path)) return ExchangeRouteNeed.open;
    return null;
  }
}

/// The settings home shows its own sign-in entry and keeps sign-out
/// reachable; every other exchange settings screen acts on the account.
ExchangeRouteNeed exchangeSettingsRouteNeed(ExchangeSettingsRoute route) =>
    switch (route) {
      ExchangeSettingsRoute.home => ExchangeRouteNeed.open,
      ExchangeSettingsRoute.security ||
      ExchangeSettingsRoute.referrals ||
      ExchangeSettingsRoute.accountInfo ||
      ExchangeSettingsRoute.preferences ||
      ExchangeSettingsRoute.secureFileUpload ||
      ExchangeSettingsRoute.statistics => ExchangeRouteNeed.account,
    };

sealed class ExchangeRouteDecision {
  const ExchangeRouteDecision();
}

final class ExchangeRouteAllowed extends ExchangeRouteDecision {
  const ExchangeRouteAllowed();
}

/// Sign in, then resume the requested location.
final class ExchangeRouteSignIn extends ExchangeRouteDecision {
  const ExchangeRouteSignIn();
}

final class ExchangeRouteUnavailable extends ExchangeRouteDecision {
  const ExchangeRouteUnavailable();
}

/// The platform restriction applies: show the website-only landing.
final class ExchangeRouteWebsiteOnly extends ExchangeRouteDecision {
  const ExchangeRouteWebsiteOnly();
}

/// Keyed on the access state (through [ExchangeAvailability]), never on
/// whether an account summary is loaded (B5).
ExchangeRouteDecision decideExchangeRoute(
  ExchangeRouteNeed need,
  ExchangeAvailability availability,
) => switch ((need, availability)) {
  (
    ExchangeRouteNeed.open,
    ExchangeAvailability.ready ||
        ExchangeAvailability.signInRequired ||
        ExchangeAvailability.unavailable ||
        ExchangeAvailability.hidden ||
        ExchangeAvailability.websiteOnly,
  ) =>
    const ExchangeRouteAllowed(),
  (ExchangeRouteNeed.account, ExchangeAvailability.ready) =>
    const ExchangeRouteAllowed(),
  (ExchangeRouteNeed.account, ExchangeAvailability.signInRequired) =>
    const ExchangeRouteSignIn(),
  (
    ExchangeRouteNeed.account,
    ExchangeAvailability.unavailable || ExchangeAvailability.hidden,
  ) =>
    const ExchangeRouteUnavailable(),
  (ExchangeRouteNeed.account, ExchangeAvailability.websiteOnly) =>
    const ExchangeRouteWebsiteOnly(),
};

/// The sign-in location that resumes [location] once a key is stored.
String exchangeSignInResuming(Uri location) => Uri(
  path: BullExchangeNavigation.authPath,
  queryParameters: {'resume': location.toString()},
).toString();

/// The one `onEnter` guard of every exchange route (INT-13, DW-9), over the
/// [paths] the host composed.
class ExchangeRouteGuard {
  final GlobalKey<NavigatorState> navigatorKey;
  final Future<Result<ExchangeAvailability, ExchangeFailure>> Function()
  checkAvailability;
  final Future<Result<void, ExchangeFailure>> Function() resolveAccess;
  final ExchangeGuardedPaths paths;

  const ExchangeRouteGuard({
    required this.navigatorKey,
    required this.checkAvailability,
    required this.resolveAccess,
    required this.paths,
  });

  Future<OnEnterResult> onEnter(
    BuildContext context,
    GoRouterState current,
    GoRouterState next,
    GoRouter router,
  ) async {
    final need = paths.needOf(next.uri.path);
    if (need == null || need == ExchangeRouteNeed.open) return const Allow();
    final availability = switch (await checkAvailability()) {
      Ok(:final value) => value,
      Err() => ExchangeAvailability.unavailable,
    };
    return switch (decideExchangeRoute(need, availability)) {
      ExchangeRouteAllowed() => const Allow(),
      ExchangeRouteSignIn() => Block.then(
        () => router.push(exchangeSignInResuming(next.uri)),
      ),
      ExchangeRouteUnavailable() => Block.then(
        () => _showUnavailable(router, next.uri),
      ),
      ExchangeRouteWebsiteOnly() => Block.then(
        () => router.push(BullExchangeNavigation.landingPath),
      ),
    };
  }

  void _showUnavailable(GoRouter router, Uri location) {
    void showFeedback() {
      final overlay = navigatorKey.currentState?.overlay;
      if (overlay == null || !overlay.mounted) return;
      final loc = overlay.context.loc;
      BullSnackBar.showOnOverlay(
        overlay,
        message: loc.exchangeTradingUnavailable,
        actionLabel: loc.exchangeTradingRetry,
        onAction: () async {
          final _ = await resolveAccess();
          router.push(location.toString());
        },
      );
    }

    if (navigatorKey.currentState?.overlay == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => showFeedback());
    } else {
      showFeedback();
    }
  }
}
