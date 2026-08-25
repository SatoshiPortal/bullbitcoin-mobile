import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/scan_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:go_router/go_router.dart';

typedef WatchOnlyImportInput = ({
  String input,
  SignerDeviceEntity? signerDevice,
});

enum ImportWatchOnlyWalletRoutes {
  import('/import-watch-only'),
  scan('/import-watch-only-scanner');

  final String path;
  const ImportWatchOnlyWalletRoutes(this.path);
}

class ImportWatchOnlyRouter {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: ImportWatchOnlyWalletRoutes.import.name,
        path: ImportWatchOnlyWalletRoutes.import.path,
        builder: (context, state) {
          final extra = state.extra;
          return ImportWatchOnlyScreen(
            watchOnlyWallet: extra is WatchOnlyWalletEntity ? extra : null,
            input: extra is WatchOnlyImportInput ? extra.input : null,
            signerDevice: extra is WatchOnlyImportInput
                ? extra.signerDevice
                : null,
          );
        },
      ),
      GoRoute(
        name: ImportWatchOnlyWalletRoutes.scan.name,
        path: ImportWatchOnlyWalletRoutes.scan.path,
        builder: (context, state) {
          final signerDevice = state.extra as SignerDeviceEntity?;
          return ScanWatchOnlyScreen(signerDevice: signerDevice);
        },
      ),
    ],
  );
}
