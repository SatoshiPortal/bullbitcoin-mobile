import 'package:wallet_import/src/import_navigation.dart';
import 'package:signers/signers.dart';
import 'package:wallet_import/src/ui/watch_only/import_watch_only_screen.dart';
import 'package:wallet_import/src/ui/watch_only/scan_watch_only_screen.dart';
import 'package:wallet_import/src/domain/watch_only/watch_only_wallet_entity.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart' show BuildContext;
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_cubit.dart';

class ImportWatchOnlyRouter {
  static ShellRoute route({
    required ImportWatchOnlyCubit Function(WatchOnlyWalletEntity?) createCubit,
    required void Function(BuildContext) onImported,
  }) => ShellRoute(
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
          return ImportWatchOnlyScreen(
            createCubit: () => createCubit(watchOnlyWallet),
            onImported: onImported,
          );
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
