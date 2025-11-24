import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/server_confirmation_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RecoverBullFlowNavigator extends StatefulWidget {
  const RecoverBullFlowNavigator({super.key});

  @override
  State<RecoverBullFlowNavigator> createState() =>
      _RecoverBullFlowNavigatorState();
}

class _RecoverBullFlowNavigatorState extends State<RecoverBullFlowNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _serverConfirmed = false;

  void _onServerConfirmed() {
    setState(() => _serverConfirmed = true);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.read<RecoverBullBloc>().state.flow;

    final page = switch (flow) {
      RecoverBullFlow.settings => const SettingsPage(),
      _ =>
        _serverConfirmed
            ? const ConnectingPage()
            : ServerConfirmationPage(onConfirm: _onServerConfirmed),
    };

    return PopScope(
      canPop: !(_navigatorKey.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_navigatorKey.currentState?.canPop() ?? false)) {
          _navigatorKey.currentState?.pop();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        pages: [MaterialPage(key: ValueKey(_serverConfirmed), child: page)],
        onDidRemovePage: (page) {},
      ),
    );
  }
}
