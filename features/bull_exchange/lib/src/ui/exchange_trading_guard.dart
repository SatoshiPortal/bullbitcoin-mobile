import 'package:exchange/exchange.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import '../exchange_l10n.dart';
import '../exchange_landing_navigation.dart';

/// Blocks trading navigation when the exchange cannot currently be used.
class ExchangeTradingGuard {
  final GlobalKey<NavigatorState> navigatorKey;
  final Future<Result<ExchangeAvailability, ExchangeFailure>> Function()
  checkAvailability;
  final Future<Result<void, ExchangeFailure>> Function() resolveAccess;

  const ExchangeTradingGuard({
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
    final path = next.uri.path;
    if (![
      '/buy',
      '/sell',
      '/pay',
    ].any((root) => path == root || path.startsWith('$root/'))) {
      return const Allow();
    }
    final result = await checkAvailability();
    if (result case Ok(value: ExchangeAvailability.ready)) {
      return const Allow();
    }
    if (result case Ok(value: ExchangeAvailability.signInRequired)) {
      return Block.then(() => router.push(BullExchangeNavigation.authPath));
    }
    return Block.then(() {
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
            router.push(next.uri.toString());
          },
        );
      }

      if (navigatorKey.currentState?.overlay == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => showFeedback());
      } else {
        showFeedback();
      }
    });
  }
}
