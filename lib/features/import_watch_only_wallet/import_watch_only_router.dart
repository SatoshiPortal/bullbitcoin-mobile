import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/scan_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:go_router/go_router.dart';

enum ImportWatchOnlyRoutes {
  import('/import-watch-only'),
  scan('/import-watch-only-scanner');

  final String path;
  const ImportWatchOnlyRoutes(this.path);
}

class ImportWatchOnlyRouter {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: ImportWatchOnlyRoutes.import.name,
        path: ImportWatchOnlyRoutes.import.path,
        builder: (context, state) {
          final watchOnlyWallet = state.extra as WatchOnlyWalletEntity?;
          return ImportWatchOnlyScreen(watchOnlyWallet: watchOnlyWallet);
        },
      ),
      GoRoute(
        name: ImportWatchOnlyRoutes.scan.name,
        path: ImportWatchOnlyRoutes.scan.path,
        builder: (context, state) => const ScanWatchOnlyScreen(),
      ),
    ],
  );
}
