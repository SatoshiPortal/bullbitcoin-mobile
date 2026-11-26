import 'package:bull_ui/bull_ui.dart'
    show BullScaffold, BullTopBar, BullButton, BullText, Gap, BullTypographyX;
import 'package:exchange/exchange.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../exchange_l10n.dart';
import '../exchange_landing_navigation.dart';
import '../support_chat/exchange_support_chat_navigation.dart';
import 'exchange_auth_screen.dart';
import 'exchange_exit_on_back.dart';

GoRoute exchangeAuthRoute({
  required ExchangeAuthHost host,
  required Future<bool> Function() networkUnavailable,
  required bool Function(BuildContext) showWebsiteOnly,
  required String homePath,
  required void Function(BuildContext) onExit,
}) => GoRoute(
  name: BullExchangeNavigation.authName,
  path: BullExchangeNavigation.authPath,
  redirect: (context, state) async =>
      await networkUnavailable() ? homePath : null,
  pageBuilder: (context, state) {
    final draft = state.extra as ExchangeSupportChatDraft?;
    final fromSupport = state.uri.queryParameters['from'] == 'support';
    final fromSettings = state.uri.queryParameters['from'] == 'settings';
    if (fromSettings) {
      void exitSettingsAuth() {
        if (context.canPop()) {
          context.pop();
        } else {
          onExit(context);
        }
      }

      return NoTransitionPage(
        key: state.pageKey,
        child: _AuthAccessGate(
          host: host,
          onExit: onExit,
          child: Scaffold(
            body: ExchangeAuthScreen(
              host: host,
              onExit: exitSettingsAuth,
              onDone: exitSettingsAuth,
            ),
          ),
        ),
      );
    }
    // A stored key is the only way out forward (B2): the route never waits
    // for the account read.
    final resume = state.uri.queryParameters['resume'];
    void onSignedIn() {
      // The route guard sent the user here from [resume] (INT-13).
      if (resume != null && resume.startsWith('/')) {
        context.pushReplacement(resume);
        return;
      }
      if (fromSupport) {
        final isIOSNonSuperuser = showWebsiteOnly(context);
        context.goNamed(
          ExchangeSupportChatNavigation.routeName,
          queryParameters: isIOSNonSuperuser ? {} : {'from': 'exchange'},
          extra: draft,
        );
        return;
      }
      if (showWebsiteOnly(context)) {
        onExit(context);
        return;
      }
      context.goNamed(BullExchangeNavigation.dashboardName);
    }

    // Support and the landing page open sign-in with `go`, which leaves
    // nothing to go back to.
    return NoTransitionPage(
      key: state.pageKey,
      child: ExchangeExitOnBack(
        onExit: () => onExit(context),
        child: _AuthAccessGate(
          host: host,
          onExit: onExit,
          child: Scaffold(
            body: ExchangeAuthScreen(
              host: host,
              onExit: () => onExit(context),
              onDone: onSignedIn,
            ),
          ),
        ),
      ),
    );
  },
);

class _AuthAccessGate extends StatelessWidget {
  const _AuthAccessGate({
    required this.host,
    required this.onExit,
    required this.child,
  });
  final ExchangeAuthHost host;
  final void Function(BuildContext) onExit;
  final Widget child;
  @override
  Widget build(BuildContext context) => StreamBuilder<ExchangeAccess>(
    stream: host.watchAccess(),
    initialData: host.currentAccess(),
    builder: (context, snapshot) {
      final access = snapshot.data ?? host.currentAccess();
      if (ExchangeAvailability.canAuthenticate(access)) {
        return child;
      }
      return BullScaffold(
        body: SafeArea(
          child: Column(
            children: [
              BullTopBar(
                title: context.loc.exchangeAccessSettingsTitle,
                onBack: () => onExit(context),
              ),
              const Gap(24),
              BullText(
                context.loc.exchangeTradingUnavailable,
                style: context.bullType.body,
              ),
              const Gap(16),
              BullButton.primary(
                label: context.loc.exchangeTradingRetry,
                onPressed: () => host.retryAccess(context),
              ),
            ],
          ),
        ),
      );
    },
  );
}
