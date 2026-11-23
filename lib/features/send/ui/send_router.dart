import 'package:bb_mobile/features/send/public/send_psbt_handoff.dart';

import '../presentation/send_ark_cubit.dart';

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/public/send_route.dart';
import 'package:bb_mobile/features/send/public/send_route_args.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SendRouter {
  static GoRoute route({
    required OpenSignedTransactionReader openSignedTransactionReader,
  }) => GoRoute(
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
      return MultiBlocProvider(
        providers: [
          BlocProvider<SendArkCubit>(create: (_) => locator<SendArkCubit>()),
          BlocProvider<SendCubit>(
            create: (_) => locator<SendCubit>(
              param1: wallet,
              param2: (
                args: args,
                spWalletLabel: args?.isSpMode == true
                    ? context.loc.walletSpTitle
                    : null,
              ),
            )..loadWalletWithRatesAndFees(),
          ),
        ],
        child: SendPsbtHandoff(
          openReader: openSignedTransactionReader,
          child: const SendScreen(),
        ),
      );
    },
  );
}
