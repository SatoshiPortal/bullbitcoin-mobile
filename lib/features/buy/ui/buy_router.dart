import 'package:bb_mobile/features/buy/presentation/buy_bloc.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_confirm_screen.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_input_screen.dart';
import 'package:bb_mobile/features/buy/ui/screens/buy_success_screen.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum BuyRoute {
  buy('/buy'),
  buyConfirmation('confirmation'),
  buySuccess('success'),
  buyAccelerate('/buy/:orderId/accelerate');

  final String path;

  const BuyRoute(this.path);
}

class BuyRouter {
  static final routes = [
    ShellRoute(
      builder: (context, state, child) {
        return BlocProvider(
          create: (_) => locator<BuyBloc>()..add(const BuyEvent.started()),
          child: child,
        );
      },
      routes: [
        GoRoute(
          name: BuyRoute.buy.name,
          path: BuyRoute.buy.path,
          builder: (context, state) {
            return MultiBlocListener(
              listeners: [
                BlocListener<BuyBloc, BuyState>(
                  listenWhen:
                      (previous, current) =>
                          previous.apiKeyException == null &&
                          current.apiKeyException != null,
                  listener: (context, state) {
                    context.goNamed(ExchangeRoute.exchangeHome.name);
                  },
                ),
                BlocListener<BuyBloc, BuyState>(
                  listenWhen:
                      (previous, current) =>
                          previous.buyOrder == null && current.buyOrder != null,
                  listener: (context, state) {
                    context.pushReplacementNamed(BuyRoute.buyConfirmation.name);
                  },
                ),
              ],
              child: const BuyInputScreen(),
            );
          },
          routes: [
            GoRoute(
              name: BuyRoute.buyConfirmation.name,
              path: BuyRoute.buyConfirmation.path,
              builder: (context, state) {
                return BlocListener<BuyBloc, BuyState>(
                  listenWhen:
                      (previous, current) =>
                          previous.buyOrder?.isPayinCompleted != true &&
                          current.buyOrder?.isPayinCompleted == true,
                  listener: (context, state) {
                    context.pushReplacementNamed(
                      BuyRoute.buySuccess.name,
                      extra: context.read<BuyBloc>(),
                    );
                  },
                  child: const BuyConfirmScreen(),
                );
              },
            ),
            GoRoute(
              parentNavigatorKey: AppRouter.rootNavigatorKey,
              name: BuyRoute.buySuccess.name,
              path: BuyRoute.buySuccess.path,
              builder: (context, state) {
                final buyBloc = state.extra! as BuyBloc;

                return BlocProvider.value(
                  value: buyBloc,
                  child: const BuySuccessScreen(),
                );
              },
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: BuyRoute.buyAccelerate.path,
      name: BuyRoute.buyAccelerate.name,
      builder: (context, state) {
        final orderId = state.pathParameters['orderId']!;
        return BlocProvider(
          create:
              (context) =>
                  locator<BuyBloc>()..add(BuyEvent.reloadOrder(orderId)),
          child: const BuyInputScreen(),
        );
      },
    ),
  ];
}
