import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_payout_method_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SellRoute {
  sell('/sell'),
  sellPayoutMethod('payout-method'),
  sellRecipient('recipient'),
  sellWallet('wallet'),
  sellNetwork('network'),
  sellConfirmation('confirmation'),
  sellInProgress('in-progress'),
  sellSuccess('success');

  final String path;

  const SellRoute(this.path);
}

class SellRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create: (_) => locator<SellBloc>()..add(const SellEvent.started()),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: SellRoute.sell.name,
        path: SellRoute.sell.path,
        builder:
            (context, state) => MultiBlocListener(
              listeners: [
                BlocListener<SellBloc, SellState>(
                  listenWhen:
                      (previous, current) =>
                          previous is SellInitialState &&
                          previous.apiKeyException == null &&
                          current is SellInitialState &&
                          current.apiKeyException != null,
                  listener: (context, state) {
                    // Redirect to exchange home if API key exception occurs which means the user is not authenticated
                    context.goNamed(ExchangeRoute.exchangeHome.name);
                  },
                ),
                BlocListener<SellBloc, SellState>(
                  listenWhen:
                      (previous, current) =>
                          previous is SellAmountState &&
                          current is SellPayoutMethodState,
                  listener: (context, state) {
                    context.pushNamed(SellRoute.sellPayoutMethod.name);
                  },
                ),
              ],
              child: const SellScreen(),
            ),
        routes: [
          GoRoute(
            name: SellRoute.sellPayoutMethod.name,
            path: SellRoute.sellPayoutMethod.path,
            builder: (context, state) => const SellPayoutMethodScreen(),
          ),
        ],
      ),
    ],
  );
}
