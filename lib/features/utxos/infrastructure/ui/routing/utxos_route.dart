import 'package:bb_mobile/features/utxos/infrastructure/ui/screens/utxo_details_screen.dart';
import 'package:bb_mobile/features/utxos/infrastructure/ui/screens/utxos_screen.dart';
import 'package:bb_mobile/features/utxos/interface_adapters/presenters/bloc/utxos_bloc.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum UtxosRoute {
  utxoList('/utxos/:walletId'),
  utxoDetails('/utxos/:walletId/:outpoint');

  final String path;
  const UtxosRoute(this.path);
}

class UtxosRouter {
  static final routes = [
    GoRoute(
      name: UtxosRoute.utxoList.name,
      path: UtxosRoute.utxoList.path,
      builder: (context, state) {
        final walletId = state.pathParameters['walletId']!;
        return BlocProvider<UtxosBloc>(
          create: (context) => locator<UtxosBloc>()..add(UtxosLoaded(walletId)),
          child: UtxosScreen(walletId: walletId),
        );
      },
    ),
    GoRoute(
      name: UtxosRoute.utxoDetails.name,
      path: UtxosRoute.utxoDetails.path,
      builder: (context, state) {
        final walletId = state.pathParameters['walletId']!;
        final outpoint = state.pathParameters['outpoint']!;
        final utxosBloc = state.extra as UtxosBloc?;
        if (utxosBloc != null) {
          return BlocProvider<UtxosBloc>.value(
            value: utxosBloc,
            child: UtxoDetailsScreen(outpoint: outpoint),
          );
        }

        return BlocProvider<UtxosBloc>(
          create:
              (context) =>
                  locator<UtxosBloc>()..add(
                    UtxosUtxoDetailsLoaded(
                      walletId: walletId,
                      outpoint: outpoint,
                    ),
                  ),
          child: UtxoDetailsScreen(outpoint: outpoint),
        );
      },
    ),
  ];
}
