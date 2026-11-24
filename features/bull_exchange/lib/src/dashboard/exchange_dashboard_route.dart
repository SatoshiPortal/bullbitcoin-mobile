import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:preferences/preferences.dart';

import '../exchange_landing_navigation.dart';
import '../limit_orders/limit_orders_management.dart';
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
  required Exchange Function()? limitOrders,
}) => GoRoute(
  name: BullExchangeNavigation.dashboardName,
  path: BullExchangeNavigation.dashboardPath,
  redirect: (context, _) async {
    if (await networkUnavailable()) return homePath;
    if (!context.mounted) return null;
    if (!_signedIn(host.currentAccess()) || showWebsiteOnly(context)) {
      return BullExchangeNavigation.landingPath;
    }
    return null;
  },
  pageBuilder: (context, state) => NoTransitionPage(
    key: state.pageKey,
    child: _SessionReturn(
      host: host,
      onExit: onExit,
      child: _DashboardContent(
        host: host,
        brandAsset: brandAsset,
        onExit: onExit,
        limitOrders: limitOrders,
      ),
    ),
  ),
  routes: [?kycRoute],
);

bool _signedIn(ExchangeAccess access) => access.isSignedIn;

class _DashboardContent extends StatefulWidget {
  final ExchangeDashboardHost host;
  final String brandAsset;
  final void Function(BuildContext) onExit;
  final Exchange Function()? limitOrders;

  const _DashboardContent({
    required this.host,
    required this.brandAsset,
    required this.onExit,
    required this.limitOrders,
  });

  @override
  State<_DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<_DashboardContent> {
  final _refreshes = StreamController<void>.broadcast();

  @override
  void dispose() {
    unawaited(_refreshes.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = widget.host;
    return ExchangeHomeScreen(
      watchDashboard: host.watchDashboard,
      exchange: host.exchange,
      preferences: host.preferences,
      brandAsset: widget.brandAsset,
      settingsAsset: host.settingsAsset,
      refreshAccount: () => host.refreshAccount(context),
      stopDca: () => host.stopDca(context),
      homeCards: [
        if (widget.limitOrders case final exchange?)
          LimitOrdersManagementCard(
            exchange: exchange,
            refreshRequests: _refreshes.stream,
          ),
      ],
      onHomeRefresh: () => _refreshes.add(null),
      onOpenSettings: () => host.onOpenSettings(context),
      onOpenDca: () => host.onOpenDca(context),
      onWithdraw: () => host.onWithdraw(context),
      onHistory: () => host.onHistory(context),
      onAction: (action) => host.onAction(context, action),
      onExit: () => widget.onExit(context),
      failureMessage: host.failureMessage,
    );
  }
}

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
      if (widget.host.currentAccess().isEnabled) {
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
