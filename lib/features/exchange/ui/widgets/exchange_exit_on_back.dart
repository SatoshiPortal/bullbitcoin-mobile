import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

/// Sends the back gesture of a screen with nothing beneath it to [onExit],
/// where the system would otherwise close the app. A screen pushed over
/// another pops as usual.
class ExchangeExitOnBack extends StatelessWidget {
  const ExchangeExitOnBack({
    super.key,
    required this.onExit,
    required this.child,
  });

  final VoidCallback onExit;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onExit();
      },
      child: child,
    );
  }
}
