import 'package:access/access.dart';
import 'package:backups/src/ui/screens/show_mnemonic_screen.dart';
import 'package:backups/src/ui/screens/verify_mnemonic_screen.dart';
import 'package:material_ui/material_ui.dart';

enum TestPhysicalBackupFlow { backup, verify }

class TestPhysicalBackupFlowNavigator extends StatelessWidget {
  final TestPhysicalBackupFlow flow;
  final void Function(BuildContext) onTestSucceeded;
  final ImageProvider successImage;
  final Access access;

  const TestPhysicalBackupFlowNavigator({
    super.key,
    required this.flow,
    required this.onTestSucceeded,
    required this.successImage,
    required this.access,
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
              TestPhysicalBackupFlow.backup => ShowMnemonicScreen(
                access: access,
                onTestSucceeded: onTestSucceeded,
                successImage: successImage,
              ),
              TestPhysicalBackupFlow.verify => VerifyMnemonicScreen(
                onTestSucceeded: onTestSucceeded,
                successImage: successImage,
              ),
            },
          );
        },
      ),
    );
  }
}
