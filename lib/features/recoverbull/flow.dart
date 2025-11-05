import 'package:bb_mobile/features/recoverbull/ui/pages/connecting_page.dart';
import 'package:flutter/material.dart';

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
          return MaterialPageRoute(
            builder: (context) => const ConnectingPage(),
          );
        },
      ),
    );
  }
}
