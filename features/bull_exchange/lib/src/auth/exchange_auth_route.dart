import 'dart:async';

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
          child: _SettingsAuthenticationReturn(
            onExit: exitSettingsAuth,
            watchAccess: host.watchAccess,
            child: Scaffold(
              body: ExchangeAuthScreen(host: host, onExit: exitSettingsAuth),
            ),
          ),
        ),
      );
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
          child: _AccountSignInReturn(
            changes: host.accountSignedInChanges,
            onSignedIn: (context) {
              if (fromSupport) {
                final isIOSNonSuperuser = showWebsiteOnly(context);
                context.goNamed(
                  ExchangeSupportChatNavigation.routeName,
                  queryParameters: isIOSNonSuperuser
                      ? {}
                      : {'from': 'exchange'},
                  extra: draft,
                );
                return;
              }
              if (showWebsiteOnly(context)) {
                onExit(context);
                return;
              }
              context.goNamed(BullExchangeNavigation.dashboardName);
            },
            child: Scaffold(
              body: ExchangeAuthScreen(
                host: host,
                onExit: () => onExit(context),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

class _SettingsAuthenticationReturn extends StatefulWidget {
  const _SettingsAuthenticationReturn({
    required this.child,
    required this.onExit,
    required this.watchAccess,
  });

  final Widget child;
  final VoidCallback onExit;
  final Stream<ExchangeAccess> Function() watchAccess;

  @override
  State<_SettingsAuthenticationReturn> createState() =>
      _SettingsAuthenticationReturnState();
}

class _SettingsAuthenticationReturnState
    extends State<_SettingsAuthenticationReturn> {
  StreamSubscription<ExchangeAccess>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.watchAccess().listen((status) {
      if (mounted && status.isSignedIn) {
        widget.onExit();
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

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

class _AccountSignInReturn extends StatefulWidget {
  const _AccountSignInReturn({
    required this.changes,
    required this.onSignedIn,
    required this.child,
  });

  final Stream<bool> Function(BuildContext) changes;
  final void Function(BuildContext) onSignedIn;
  final Widget child;

  @override
  State<_AccountSignInReturn> createState() => _AccountSignInReturnState();
}

class _AccountSignInReturnState extends State<_AccountSignInReturn> {
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    bool? signedIn;
    _subscription = widget.changes(context).listen((value) {
      final justSignedIn = signedIn == false && value;
      signedIn = value;
      if (mounted && justSignedIn) widget.onSignedIn(context);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
