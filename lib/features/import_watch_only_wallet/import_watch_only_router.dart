import 'package:wallet_import/wallet_import.dart';
import 'package:signers/signers.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/scan_watch_only_screen.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:go_router/go_router.dart';

class ImportWatchOnlyRouter {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      GoRoute(
        name: ImportNavigation.watchOnlyConfirmationName,
        path: ImportNavigation.watchOnlyConfirmationPath,
        builder: (context, state) {
          final request = state.extra as WatchOnlyImportRequest?;
          final watchOnlyWallet = request == null
              ? null
              : WatchOnlyWalletEntity.fromInput(request.input)
                    .copyWith(label: request.label);
          return ImportWatchOnlyScreen(watchOnlyWallet: watchOnlyWallet);
        },
      ),
      GoRoute(
        name: ImportNavigation.watchOnlyScannerName,
        path: ImportNavigation.watchOnlyScannerPath,
        builder: (context, state) {
          final signerDevice = state.extra as SignerDevice?;
          return ScanWatchOnlyScreen(signerDevice: signerDevice);
        },
      ),
    ],
  );
}
