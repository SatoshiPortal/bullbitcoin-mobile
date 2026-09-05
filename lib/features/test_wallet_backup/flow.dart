import 'package:bb_mobile/features/test_wallet_backup/public/test_wallet_backup_facade.dart';
import 'package:flutter/material.dart';

class TestPhysicalBackupFlowNavigator extends StatelessWidget {
  final TestPhysicalBackupFlow flow;
  final VoidCallback? onVerified;

  const TestPhysicalBackupFlowNavigator({
    super.key,
    required this.flow,
    this.onVerified,
  });

  @override
  Widget build(BuildContext context) {
    final navigatorKey = GlobalKey<NavigatorState>();

    return PopScope(
      canPop: !(navigatorKey.currentState?.canPop() ?? false),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && (navigatorKey.currentState?.canPop() ?? false)) {
          navigatorKey.currentState?.pop();
        }
      },
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => switch (flow) {
              TestPhysicalBackupFlow.backup => const ShowMnemonicScreen(),
              TestPhysicalBackupFlow.verify => VerifyMnemonicScreen(
                onVerified: onVerified,
              ),
            },
          );
        },
      ),
    );
  }
}
