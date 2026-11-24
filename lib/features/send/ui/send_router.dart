import 'package:send/send.dart';

import '../presentation/send_ark_cubit.dart';

import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/public/send_route_args.dart';
import 'package:bb_mobile/features/send/ui/screens/send_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class SendRouter {
  static GoRoute route({
    required GetIt locator,
    required OpenSignedTransactionReader openSignedTransactionReader,
  }) => GoRoute(
    name: SendRoute.send.name,
    path: SendRoute.send.path,
    builder: (context, state) {
      final extra = state.extra;
      final args = extra is SendRouteArgs ? extra : null;
      // A raw Wallet remains a supported route payload for regular sends.
      final wallet = args?.wallet ?? (extra is Wallet ? extra : null);
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
