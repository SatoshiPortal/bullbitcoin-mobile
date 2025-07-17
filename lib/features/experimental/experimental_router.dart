import 'package:bb_mobile/features/experimental/broadcast_signed_tx/router.dart';
import 'package:bb_mobile/features/experimental/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/experimental/psbt_flow/psbt_router.dart';
import 'package:go_router/go_router.dart';

class ExperimentalRouterConfig {
  static final route = ShellRoute(
    builder: (context, state, child) => child,
    routes: [
      ImportWatchOnlyRouterConfig.route,
      PsbtRouterConfig.route,
      BroadcastSignedTxRouter.route,
    ],
  );
}
