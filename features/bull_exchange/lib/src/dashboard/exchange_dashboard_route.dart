import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';

import '../exchange_landing_navigation.dart';
import 'exchange_home_actions.dart';
import 'exchange_home_screen.dart';

typedef ExchangeDashboardHost = ({
  Exchange Function() exchange,
  Preferences Function() preferences,
  ExchangeAccess Function() currentAccess,
  Stream<ExchangeAccess> Function() watchAccess,
  ExchangeDashboardState Function(BuildContext) watchDashboard,
  Future<void> Function(BuildContext) refreshAccount,
  Future<void> Function(BuildContext) stopDca,
  List<Widget> Function() buildHomeCards,
  VoidCallback onHomeRefresh,
  void Function(BuildContext) onOpenSettings,
  void Function(BuildContext) onOpenDca,
  void Function(BuildContext) onWithdraw,
  void Function(BuildContext) onHistory,
  void Function(BuildContext, ExchangeHomeAction) onAction,
  String Function(BuildContext, ExchangeFailure) failureMessage,
  String settingsAsset,
});

GoRoute exchangeDashboardRoute({
  required ExchangeDashboardHost host,
  required GoRoute? kycRoute,
  required Future<bool> Function() networkUnavailable,
  required bool Function(BuildContext) showWebsiteOnly,
  required String homePath,
  required String brandAsset,
  required void Function(BuildContext) onExit,
}) => GoRoute(
  name: BullExchangeNavigation.dashboardName,
  path: BullExchangeNavigation.dashboardPath,
  redirect: (context, _) async {
    if (await networkUnavailable()) return homePath;
    if (!context.mounted) return null;
    if (!_signedIn(host.currentAccess())) {
      return BullExchangeNavigation.landingPath;
    }
    return showWebsiteOnly(context) ? homePath : null;
  },
  pageBuilder: (context, state) => NoTransitionPage(
    key: state.pageKey,
    child: _SessionReturn(
      host: host,
      onExit: onExit,
      child: Builder(
        builder: (context) {
          return ExchangeHomeScreen(
            watchDashboard: host.watchDashboard,
            exchange: host.exchange,
            preferences: host.preferences,
            brandAsset: brandAsset,
            settingsAsset: host.settingsAsset,
            refreshAccount: () => host.refreshAccount(context),
            stopDca: () => host.stopDca(context),
            homeCards: host.buildHomeCards(),
            onHomeRefresh: host.onHomeRefresh,
            onOpenSettings: () => host.onOpenSettings(context),
            onOpenDca: () => host.onOpenDca(context),
            onWithdraw: () => host.onWithdraw(context),
            onHistory: () => host.onHistory(context),
            onAction: (action) => host.onAction(context, action),
            onExit: () => onExit(context),
            failureMessage: host.failureMessage,
          );
        },
      ),
    ),
  ),
  routes: [?kycRoute],
);

bool _signedIn(ExchangeAccess access) =>
    access is ExchangeAccessEnabled &&
    access.session == ExchangeAccessSession.signedIn;

class _SessionReturn extends StatefulWidget {
  final ExchangeDashboardHost host;
  final void Function(BuildContext) onExit;
  final Widget child;

  const _SessionReturn({
    required this.host,
    required this.onExit,
    required this.child,
  });

  @override
  State<_SessionReturn> createState() => _SessionReturnState();
}

class _SessionReturnState extends State<_SessionReturn> {
  StreamSubscription<ExchangeAccess>? _subscription;

  @override
  void initState() {
    super.initState();
    var signedIn = _signedIn(widget.host.currentAccess());
    _subscription = widget.host.watchAccess().listen((access) {
      final current = _signedIn(access);
      final ended = signedIn && !current;
      signedIn = current;
      if (!mounted || !ended) return;
      if (widget.host.currentAccess() is ExchangeAccessEnabled) {
        BullExchangeNavigation.goToLanding(context);
      } else {
        widget.onExit(context);
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
