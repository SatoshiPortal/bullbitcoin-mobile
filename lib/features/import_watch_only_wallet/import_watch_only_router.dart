import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/scan_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:go_router/go_router.dart';

enum ImportWalletRoutes {
  import('/import-watch-only'),
  scan('/import-watch-only-scanner');

  final String path;
  const ImportWalletRoutes(this.path);
}

class ImportWatchOnlyRouter {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: ImportWalletRoutes.import.name,
        path: ImportWalletRoutes.import.path,
        builder: (context, state) {
          final watchOnlyWallet = state.extra as WatchOnlyWalletEntity?;
          return ImportWatchOnlyScreen(watchOnlyWallet: watchOnlyWallet);
        },
      ),
      GoRoute(
        name: ImportWalletRoutes.scan.name,
        path: ImportWalletRoutes.scan.path,
        builder: (context, state) => const ScanWatchOnlyScreen(),
      ),
    ],
  );
}
