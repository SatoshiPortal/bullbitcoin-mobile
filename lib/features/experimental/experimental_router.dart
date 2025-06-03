import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/extended_public_key_entity.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/import_screen.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/presentation/scanner_screen.dart';
import 'package:go_router/go_router.dart';

enum ExperimentalRoutes {
  watchOnly('/watch-only'),
  scanner('/scanner');

  final String path;
  const ExperimentalRoutes(this.path);
}

class ExperimentalRouterConfig {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: ExperimentalRoutes.watchOnly.name,
        path: ExperimentalRoutes.watchOnly.path,
        builder: (context, state) {
          final pub =
              state.extra as ExtendedPublicKeyEntity? ??
              const ExtendedPublicKeyEntity(key: '', type: ScriptType.bip44);
          return ImportScreen(pub: pub);
        },
      ),
      GoRoute(
        name: ExperimentalRoutes.scanner.name,
        path: ExperimentalRoutes.scanner.path,
        builder: (context, state) => const ScannerScreen(),
      ),
    ],
  );
}
