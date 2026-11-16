import 'package:bb_mobile/features/psbt_signing/presentation/psbt_signing_cubit.dart';
import 'package:bb_mobile/features/psbt_signing/ui/psbt_signing_qr_screen.dart';
import 'package:bb_mobile/features/psbt_signing/ui/psbt_signing_scanner_screen.dart';
import 'package:bb_mobile/features/psbt_signing/ui/psbt_signing_screen.dart';
import 'package:get_it/get_it.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PsbtSigningRoute {
  psbtSigning('/wallet/:walletId/sign-psbt'),
  psbtSigningScan('scan'),
  psbtSigningQr('qr');

  final String path;

  const PsbtSigningRoute(this.path);
}

class PsbtSigningRouter {
  static final route = GoRoute(
    name: PsbtSigningRoute.psbtSigning.name,
    path: PsbtSigningRoute.psbtSigning.path,
    builder: (context, state) => BlocProvider(
      create: (_) => GetIt.I<PsbtSigningCubit>(
        param1:
            state.pathParameters['walletId'] ??
            (throw StateError('Missing wallet ID')),
      ),
      child: const PsbtSigningScreen(),
    ),
    routes: [
      GoRoute(
        name: PsbtSigningRoute.psbtSigningScan.name,
        path: PsbtSigningRoute.psbtSigningScan.path,
        builder: (context, _) => const PsbtSigningScannerScreen(),
      ),
      GoRoute(
        name: PsbtSigningRoute.psbtSigningQr.name,
        path: PsbtSigningRoute.psbtSigningQr.path,
        builder: (context, state) =>
            PsbtSigningQrScreen(psbt: state.extra! as String),
      ),
    ],
  );
}
