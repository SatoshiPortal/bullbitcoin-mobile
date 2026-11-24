import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../exchange_l10n.dart';
import '../exchange_landing_navigation.dart';

/// Whether a route needs a signed-in exchange account.
enum ExchangeRouteNeed { account, open }

/// Roots of the routes that act on the account. Every route below a root is
/// covered too.
@visibleForTesting
const exchangeAccountRoutes = [
  '/buy',
  '/sell',
  '/pay',
  '/withdraw',
  '/fund-exchange',
  '/dca',
  '/auto-buy',
  '/limit-orders',
  '/exchange/kyc',
  '/settings/exchange-security',
  '/settings/exchange-referrals',
  '/settings/exchange-account-info',
  '/settings/exchange-app-settings',
  '/settings/secure-file-upload',
  '/settings/exchange-statistics',
  '/settings/exchange-bitcoin-wallets',
];

/// Exchange routes that render the access state themselves.
@visibleForTesting
const exchangeOpenRoutes = [
  BullExchangeNavigation.dashboardPath,
  BullExchangeNavigation.landingPath,
  BullExchangeNavigation.authPath,
  '/exchange/support-chat',
  // Shows its own sign-in entry and keeps sign-out reachable.
  '/settings/exchange-settings',
  '/settings/exchange-access',
];

bool _under(String path, String root) =>
    path == root ||
    path.startsWith('$root/') ||
    // The funding methods are siblings named after their root.
    (root == '/fund-exchange' && path.startsWith('$root-'));

/// Null for a route outside the exchange.
ExchangeRouteNeed? exchangeRouteNeed(String path) {
  if (exchangeAccountRoutes.any((root) => _under(path, root))) {
    return ExchangeRouteNeed.account;
  }
  if (exchangeOpenRoutes.contains(path)) return ExchangeRouteNeed.open;
  return null;
}

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

/// The one `onEnter` guard of every exchange route (INT-13, DW-9).
class ExchangeRouteGuard {
  final GlobalKey<NavigatorState> navigatorKey;
  final Future<Result<ExchangeAvailability, ExchangeFailure>> Function()
  checkAvailability;
  final Future<Result<void, ExchangeFailure>> Function() resolveAccess;

  const ExchangeRouteGuard({
    required this.navigatorKey,
    required this.checkAvailability,
    required this.resolveAccess,
  });

  Future<OnEnterResult> onEnter(
    BuildContext context,
    GoRouterState current,
    GoRouterState next,
    GoRouter router,
  ) async {
    final need = exchangeRouteNeed(next.uri.path);
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
