import 'package:bb_mobile/features/utxos/frameworks_drivers/ui/screens/utxo_details_screen.dart';
import 'package:bb_mobile/features/utxos/frameworks_drivers/ui/screens/utxos_screen.dart';
import 'package:go_router/go_router.dart';

enum UtxosRoute {
  utxos('/utxos/:walletId'),
  utxo('/utxos/:walletId/:utxoId');

  final String path;
  const UtxosRoute(this.path);
}

class UtxosRouter {
  static final routes = [
    GoRoute(
      name: UtxosRoute.utxos.name,
      path: UtxosRoute.utxos.path,
      builder: (context, state) {
        // TODO: add utxos bloc provider
        final walletId = state.pathParameters['walletId'];
        return UtxosScreen(walletId: walletId);
      },
    ),
    GoRoute(
      name: UtxosRoute.utxo.name,
      path: UtxosRoute.utxo.path,
      builder: (context, state) {
        // TODO: add utxo details bloc provider
        final walletId = state.pathParameters['walletId'];
        final utxoId = state.pathParameters['utxoId'];
        return UtxoDetailsScreen(walletId: walletId, utxoId: utxoId);
      },
    ),
  ];
}
