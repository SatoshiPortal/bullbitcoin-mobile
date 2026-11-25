import 'package:flutter/widgets.dart' show ImageProvider, Widget, BuildContext;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:send/src/send_localizations.dart';
import 'package:swaps/order_swaps.dart' show OrderSwapRecord;
import 'package:sync/sync.dart' show WalletKey;
import 'package:transactions/transactions.dart' show SettlementPoll;

import '../presentation/bloc/send_cubit.dart';
import '../presentation/send_ark_cubit.dart';
import '../public/send_psbt_handoff.dart';
import '../public/send_route.dart';
import '../public/send_route_args.dart';
import 'screens/send_screen.dart';
import 'send_payment_ui.dart';

GoRoute paymentRoute({
  required SendCubit Function(SendRouteArgs?, String?) createCubit,
  required SendArkCubit Function() createArkCubit,
  required OpenSignedTransactionReader openSignedTransactionReader,
  required void Function(BuildContext) openHome,
  required void Function(BuildContext, WalletKey) openCoins,
  required Widget Function(OrderSwapRecord) orderUnderReview,
  required ImageProvider arrowImage,
  required ImageProvider successImage,
  required SettlementPoll pollSettlement,
}) => GoRoute(
  name: SendRoute.send.name,
  path: SendRoute.send.path,
  builder: (context, state) {
    final args = switch (state.extra) {
      final SendRouteArgs args => args,
      _ => null,
    };
    return MultiBlocProvider(
      providers: [
        BlocProvider<SendArkCubit>(create: (_) => createArkCubit()),
        BlocProvider<SendCubit>(
          create: (_) => createCubit(
            args,
            args?.isSpMode == true ? context.loc.walletSpTitle : null,
          )..loadWalletWithRatesAndFees(),
        ),
      ],
      child: SendPaymentUi(
        openHome: openHome,
        openCoins: openCoins,
        orderUnderReview: orderUnderReview,
        arrowImage: arrowImage,
        successImage: successImage,
        child: SendPsbtHandoff(
          openReader: openSignedTransactionReader,
          child: SendScreen(poll: pollSettlement),
        ),
      ),
    );
  },
);
