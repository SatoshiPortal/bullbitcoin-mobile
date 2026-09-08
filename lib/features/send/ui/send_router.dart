import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/public/send_route.dart';
import 'package:bb_mobile/features/send/public/send_route_args.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_cubit.dart';
import 'package:bb_mobile/features/send/request_identifier/request_identifier_screen.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SendRouter {
  static final route = GoRoute(
    name: SendRoute.send.name,
    path: SendRoute.send.path,
    builder: (context, state) {
      final args = state.extra is SendRouteArgs
          ? state.extra! as SendRouteArgs
          : null;
      // A raw Wallet remains a supported route payload for regular sends.
      final wallet =
          args?.wallet ??
          (state.extra is Wallet ? state.extra! as Wallet : null);
      return BlocProvider(
        create: (_) =>
            locator<SendCubit>(param1: wallet, param2: args)
              ..loadWalletWithRatesAndFees(),
        child: const SendScreen(),
      );
    },
    routes: [
      GoRoute(
        name: SendRoute.requestIdentifier.name,
        path: SendRoute.requestIdentifier.path,
        builder: (context, state) => BlocProvider(
          create: (_) => RequestIdentifierCubit(),
          child: const RequestIdentifierScreen(),
        ),
      ),
    ],
  );
}
