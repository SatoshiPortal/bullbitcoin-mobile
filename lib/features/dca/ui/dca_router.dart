import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/ui/screens/dca_confirmation_screen.dart';
import 'package:bb_mobile/features/dca/ui/screens/dca_screen.dart';
import 'package:bb_mobile/features/dca/ui/screens/dca_success_screen.dart';
import 'package:bb_mobile/features/dca/ui/screens/dca_wallet_selection_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum DcaRoute {
  dca('/dca'),
  dcaWalletSelection('wallet-selection'),
  dcaConfirmation('confirmation'),
  dcaSuccess('success');

  final String path;

  const DcaRoute(this.path);
}

class DcaRouter {
  static final route = GoRoute(
    name: DcaRoute.dca.name,
    path: DcaRoute.dca.path,
    builder: (context, state) {
      return BlocProvider<DcaBloc>(
        create: (_) => locator<DcaBloc>()..add(const DcaEvent.started()),
        child: const DcaScreen(),
      );
    },
    routes: [
      GoRoute(
        name: DcaRoute.dcaWalletSelection.name,
        path: DcaRoute.dcaWalletSelection.path,
        builder: (context, state) {
          final dcaBloc = state.extra! as DcaBloc;
          return BlocProvider.value(
            value: dcaBloc,
            child: const DcaWalletSelectionScreen(),
          );
        },
      ),
      GoRoute(
        name: DcaRoute.dcaConfirmation.name,
        path: DcaRoute.dcaConfirmation.path,
        builder: (context, state) {
          final dcaBloc = state.extra! as DcaBloc;
          return BlocProvider.value(
            value: dcaBloc,
            child: const DcaConfirmationScreen(),
          );
        },
      ),
      GoRoute(
        name: DcaRoute.dcaSuccess.name,
        path: DcaRoute.dcaSuccess.path,
        builder: (context, state) {
          final dcaBloc = state.extra! as DcaBloc;
          return BlocProvider.value(
            value: dcaBloc,
            child: const DcaSuccessScreen(),
          );
        },
      ),
    ],
  );
}
