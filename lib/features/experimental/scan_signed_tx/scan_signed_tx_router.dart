import 'package:bb_mobile/features/experimental/scan_signed_tx/scan_signed_tx_screen.dart';
import 'package:go_router/go_router.dart';

enum ScanSignedTxRoutes {
  go('/scan-signed-tx');

  final String path;
  const ScanSignedTxRoutes(this.path);
}

class ScanSignedTxRouterConfig {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: ScanSignedTxRoutes.go.name,
        path: ScanSignedTxRoutes.go.path,
        builder: (context, state) => const ScanSignedTxScreen(),
      ),
    ],
  );
}
