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
  void initState() {
    super.initState();
    final bloc = context.read<RecoverBullBloc>();
    if (bloc.state.flow != RecoverBullFlow.settings) {
      bloc.add(const OnTorInitialization());
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (context.read<RecoverBullBloc>().state.flow) {
      RecoverBullFlow.settings => const SettingsPage(),
      _ => const ConnectingPage(),
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
        onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => page),
      ),
    );
  }
}
