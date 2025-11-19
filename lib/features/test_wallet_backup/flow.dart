import 'package:bb_mobile/features/test_wallet_backup/ui/screens/show_mnemonic_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/screens/verify_mnemonic_screen.dart';
import 'package:bb_mobile/features/test_wallet_backup/ui/test_wallet_backup_router.dart';
import 'package:flutter/material.dart';

class TestPhysicalBackupFlowNavigator extends StatelessWidget {
  final TestPhysicalBackupFlow flow;
  const TestPhysicalBackupFlowNavigator({super.key, required this.flow});

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
            builder:
                (context) => switch (flow) {
                  TestPhysicalBackupFlow.backup => const ShowMnemonicScreen(),
                  TestPhysicalBackupFlow.verify => const VerifyMnemonicScreen(),
                },
          );
        },
      ),
    );
  }
}
