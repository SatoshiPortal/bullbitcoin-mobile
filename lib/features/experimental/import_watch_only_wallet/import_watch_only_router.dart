import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/extended_public_key_entity.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/import_watch_only_screen.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/scan_watch_only_screen.dart';
import 'package:go_router/go_router.dart';

enum ImportWatchOnlyRoutes {
  import('/import-watch-only'),
  scan('/import-watch-only-scanner');

  final String path;
  const ImportWatchOnlyRoutes(this.path);
}

class ImportWatchOnlyRouterConfig {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: ImportWatchOnlyRoutes.import.name,
        path: ImportWatchOnlyRoutes.import.path,
        builder: (context, state) {
          final pub =
              state.extra as ExtendedPublicKeyEntity? ??
              const ExtendedPublicKeyEntity(key: '', type: ScriptType.bip44);
          return ImportWatchOnlyScreen(pub: pub);
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
