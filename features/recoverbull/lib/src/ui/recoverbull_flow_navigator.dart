import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../domain/entities/recoverbull_flow.dart';
import '../presentation/vault_flow_presentation.dart';
import 'pages/connecting_page.dart';
import 'pages/server_confirmation_page.dart';
import 'pages/settings_page.dart';

/// What every page of one flow shares: the presentation and the shell callbacks.
class RecoverBullFlowScope extends InheritedWidget {
  final RecoverBullFlow flow;
  final VaultFlowPresentation presentation;
  final String copiedMessage;
  final VoidCallback? onRecovered;

  /// Replaces this flow with a test of the vault just created.
  final VoidCallback onTestVault;

  /// Leaves a successfully tested backup for the wallet home.
  final VoidCallback onFinished;
  final VoidCallback? onOpenTorSettings;

  const RecoverBullFlowScope({
    super.key,
    required this.flow,
    required this.presentation,
    required this.copiedMessage,
    required this.onTestVault,
    required this.onFinished,
    required super.child,
    this.onRecovered,
    this.onOpenTorSettings,
  });

  static RecoverBullFlowScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<RecoverBullFlowScope>();
    if (scope == null) throw StateError('No RecoverBullFlowScope in context');
    return scope;
  }

  @override
  bool updateShouldNotify(RecoverBullFlowScope oldWidget) =>
      flow != oldWidget.flow || presentation != oldWidget.presentation;
}

/// Leaves the current page, or the whole flow from its first page.
void recoverBullBack(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    context.pop();
  }
}

/// Hosts one RecoverBull flow in a nested navigator, starting with the server
/// confirmation until consent is granted, then the connection check.
class RecoverBullFlowNavigator extends StatefulWidget {
  final RecoverBullFlow flow;
  final Future<VaultFlowPresentation> Function() presentation;
  final String copiedMessage;
  final VoidCallback? onRecovered;
  final VoidCallback onTestVault;
  final VoidCallback onFinished;
  final VoidCallback? onOpenTorSettings;

  const RecoverBullFlowNavigator({
    super.key,
    required this.flow,
    required this.presentation,
    required this.copiedMessage,
    required this.onTestVault,
    required this.onFinished,
    this.onRecovered,
    this.onOpenTorSettings,
  });

  @override
  State<RecoverBullFlowNavigator> createState() =>
      _RecoverBullFlowNavigatorState();
}

class _RecoverBullFlowNavigatorState extends State<RecoverBullFlowNavigator> {
  VaultFlowPresentation? _presentation;
  bool _settingsRead = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final presentation = await widget.presentation();
    if (!mounted) {
      await presentation.close();
      return;
    }
    setState(() => _presentation = presentation);
    await presentation.cubit.settings();
    if (mounted) setState(() => _settingsRead = true);
  }

  @override
  void dispose() {
    unawaited(_presentation?.close() ?? Future.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _presentation;
    if (presentation == null || !_settingsRead) {
      return const Scaffold(
        body: Center(child: BullFadingLinearProgress(trigger: true)),
      );
    }
    final granted =
        presentation.cubit.state.settings?.permissionGranted ?? false;
    return RecoverBullFlowHost(
      flow: widget.flow,
      presentation: presentation,
      copiedMessage: widget.copiedMessage,
      onRecovered: widget.onRecovered,
      onTestVault: widget.onTestVault,
      onFinished: widget.onFinished,
      onOpenTorSettings: widget.onOpenTorSettings,
      page: switch (widget.flow) {
        RecoverBullFlow.settings => const SettingsPage(),
        _ when !granted => const ServerConfirmationPage(),
        _ => const ConnectingPage(),
      },
    );
  }
}

/// Provides one flow's presentation to [page] and the pages it pushes.
class RecoverBullFlowHost extends StatefulWidget {
  final RecoverBullFlow flow;
  final VaultFlowPresentation presentation;
  final Widget page;
  final String copiedMessage;
  final VoidCallback? onRecovered;
  final VoidCallback onTestVault;
  final VoidCallback onFinished;
  final VoidCallback? onOpenTorSettings;

  const RecoverBullFlowHost({
    super.key,
    required this.flow,
    required this.presentation,
    required this.page,
    required this.copiedMessage,
    required this.onTestVault,
    required this.onFinished,
    this.onRecovered,
    this.onOpenTorSettings,
  });

  @override
  State<RecoverBullFlowHost> createState() => _RecoverBullFlowHostState();
}

class _RecoverBullFlowHostState extends State<RecoverBullFlowHost> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: widget.presentation.cubit,
    child: RecoverBullFlowScope(
      flow: widget.flow,
      presentation: widget.presentation,
      copiedMessage: widget.copiedMessage,
      onRecovered: widget.onRecovered,
      onTestVault: widget.onTestVault,
      onFinished: widget.onFinished,
      onOpenTorSettings: widget.onOpenTorSettings,
      child: NavigatorPopHandler<Object?>(
        onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
        child: Navigator(
          key: _navigatorKey,
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => widget.page),
        ),
      ),
    ),
  );
}
