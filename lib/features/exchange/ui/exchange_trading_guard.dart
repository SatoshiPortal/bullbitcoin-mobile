import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullSnackBar;
import 'package:go_router/go_router.dart';

/// Blocks trading navigation when the exchange cannot currently be used.
class ExchangeTradingGuard {
  const ExchangeTradingGuard(this.exchange, this.navigatorKey);

  final ExchangeFacade exchange;
  final GlobalKey<NavigatorState> navigatorKey;

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
    final result = await exchange.guardTradingEntry();
    if (result case Ok(value: ExchangeAvailability.ready)) {
      return const Allow();
    }
    if (result case Ok(value: ExchangeAvailability.signInRequired)) {
      return Block.then(() => router.push(ExchangeRoute.exchangeAuth.path));
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
            final _ = await exchange.resolveAccess();
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
