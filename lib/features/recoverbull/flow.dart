import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
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

  @override
  Widget build(BuildContext context) {
    final flow = context.read<RecoverBullBloc>().state.flow;
    final page = switch (flow) {
      RecoverBullFlow.settings => const SettingsPage(),
      _ => const ConnectingPage(),
    };

    context.read<RecoverBullBloc>().add(const OnTorInitialization());
    context.read<RecoverBullBloc>().add(const OnServerCheck());

    return PopScope(
      canPop: !(_navigatorKey.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (_navigatorKey.currentState?.canPop() ?? false)) {
          _navigatorKey.currentState?.pop();
        }
      },
      child: Navigator(
        key: _navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(builder: (context) => page);
        },
      ),
    );
  }
}
