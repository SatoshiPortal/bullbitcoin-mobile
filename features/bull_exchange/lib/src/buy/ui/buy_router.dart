import 'package:bull_exchange/src/buy/presentation/buy_bloc.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_accelerate_screen.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_accelerate_success_screen.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_confirm_screen.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_input_screen.dart';
import 'package:bull_exchange/src/buy/ui/screens/buy_success_screen.dart';

import '../../exchange_payout_field.dart';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum BuyRoute {
  buy('/buy'),
  buyConfirmation('confirmation'),
  buySuccess('success'),
  buyAccelerate('/buy/:orderId/accelerate'),
  buyAccelerateSuccess('/buy/:orderId/accelerate/success');

  final String path;

  const BuyRoute(this.path);
}

/// A confirmed order goes to the success screen, which follows it, even when
/// its payin is not completed yet.
bool _isPastConfirmation(BuyState state) =>
    state.isOrderConfirmed || state.buyOrder?.isPayinCompleted == true;

class BuyRouter {
  static List<RouteBase> routes({
    required BuyBloc Function() createBloc,
    required ExchangePayoutField payoutField,
    required String bitcoinAsset,
    required void Function(BuildContext) onClose,
    required void Function(BuildContext, String) openOrder,
  }) => [
    ShellRoute(
      builder: (context, state, child) {
        return BlocProvider(
          create: (_) => createBloc()..add(const BuyEvent.started()),
          child: child,
        );
      },
      routes: [
        GoRoute(
          name: BuyRoute.buy.name,
          path: BuyRoute.buy.path,
          builder: (context, state) {
            return BlocListener<BuyBloc, BuyState>(
              listenWhen: (previous, current) =>
                  !previous.isCreatingOrder && current.isCreatingOrder,
              listener: (context, state) {
                context.pushNamed(BuyRoute.buyConfirmation.name);
              },
              child: BuyInputScreen(payoutField: payoutField),
            );
          },
          routes: [
            GoRoute(
              name: BuyRoute.buyConfirmation.name,
              path: BuyRoute.buyConfirmation.path,
              builder: (context, state) {
                return BlocListener<BuyBloc, BuyState>(
                  listenWhen: (previous, current) =>
                      !_isPastConfirmation(previous) &&
                      _isPastConfirmation(current),
                  listener: (context, state) {
                    context.goNamed(
                      BuyRoute.buySuccess.name,
                      extra: context.read<BuyBloc>(),
                    );
                  },
                  child: BuyConfirmScreen(bitcoinAsset: bitcoinAsset),
                );
              },
              routes: [
                GoRoute(
                  name: BuyRoute.buySuccess.name,
                  path: BuyRoute.buySuccess.path,
                  builder: (context, state) {
                    return BuySuccessScreen(
                      onClose: onClose,
                      openOrder: openOrder,
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: BuyRoute.buyAccelerate.path,
      name: BuyRoute.buyAccelerate.name,
      builder: (context, state) {
        final orderId = state.pathParameters['orderId'];
        if (orderId == null) return const SizedBox.shrink();
        return BlocProvider(
          create: (context) =>
              createBloc()..add(BuyEvent.accelerateTransactionPressed(orderId)),
          child: BlocListener<BuyBloc, BuyState>(
            listenWhen: (previous, current) =>
                previous.buyOrder?.unbatchedBuyOnchainFees == null &&
                current.buyOrder?.unbatchedBuyOnchainFees != null,
            listener: (context, state) {
              context.pushReplacementNamed(
                BuyRoute.buyAccelerateSuccess.name,
                pathParameters: {'orderId': orderId},
              );
            },
            child: const BuyAccelerateScreen(),
          ),
        );
      },
    ),
    GoRoute(
      name: BuyRoute.buyAccelerateSuccess.name,
      path: BuyRoute.buyAccelerateSuccess.path,
      builder: (context, state) {
        final orderId = state.pathParameters['orderId'];
        if (orderId == null) return const SizedBox.shrink();

        return BlocProvider(
          create: (context) =>
              createBloc()..add(BuyEvent.refreshOrder(orderId: orderId)),
          child: BuyAccelerateSuccessScreen(
            onClose: onClose,
            openOrder: openOrder,
          ),
        );
      },
    ),
  ];
}
