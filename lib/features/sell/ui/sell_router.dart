import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_external_wallet_network_selection_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_receive_payment_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_send_payment_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_success_screen.dart';
import 'package:bb_mobile/features/sell/ui/screens/sell_wallet_selection_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SellRoute {
  sell('/sell'),
  sellWalletSelection('wallet-selection'),
  sellExternalWalletNetworkSelection('external-wallet-network-selection'),
  sellExternalWalletReceivePayment('external-wallet-receive-payment'),
  sellSendPayment('send-payment'),
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
                          previous is SellAmountInputState &&
                          current is SellWalletSelectionState,
                  listener: (context, state) {
                    context.pushNamed(SellRoute.sellWalletSelection.name);
                  },
                ),
              ],
              child: const SellScreen(),
            ),
        routes: [
          GoRoute(
            name: SellRoute.sellWalletSelection.name,
            path: SellRoute.sellWalletSelection.path,
            builder:
                (context, state) => BlocListener<SellBloc, SellState>(
                  listenWhen:
                      (previous, current) =>
                          previous is SellWalletSelectionState &&
                          current is SellPaymentState &&
                          current.selectedWallet != null,
                  listener: (context, state) {
                    context.pushNamed(SellRoute.sellSendPayment.name);
                  },
                  child: const SellWalletSelectionScreen(),
                ),
          ),
          GoRoute(
            name: SellRoute.sellSendPayment.name,
            path: SellRoute.sellSendPayment.path,
            builder:
                (context, state) => BlocListener<SellBloc, SellState>(
                  listenWhen:
                      (previous, current) =>
                          previous is SellPaymentState &&
                          current is SellSuccessState,
                  listener: (context, state) {
                    context.pushNamed(SellRoute.sellSuccess.name);
                  },
                  child: const SellSendPaymentScreen(),
                ),
          ),
          GoRoute(
            name: SellRoute.sellExternalWalletNetworkSelection.name,
            path: SellRoute.sellExternalWalletNetworkSelection.path,
            builder:
                (context, state) => BlocListener<SellBloc, SellState>(
                  listenWhen:
                      (previous, current) =>
                          previous is SellWalletSelectionState &&
                          current is SellPaymentState &&
                          current.selectedWallet == null,
                  listener: (context, state) {
                    context.pushNamed(
                      SellRoute.sellExternalWalletReceivePayment.name,
                    );
                  },
                  child: const SellExternalWalletNetworkSelectionScreen(),
                ),
          ),
          GoRoute(
            name: SellRoute.sellExternalWalletReceivePayment.name,
            path: SellRoute.sellExternalWalletReceivePayment.path,
            builder:
                (context, state) => BlocListener<SellBloc, SellState>(
                  listenWhen:
                      (previous, current) =>
                          previous is SellPaymentState &&
                          current is SellSuccessState,
                  listener: (context, state) {
                    context.pushNamed(SellRoute.sellSuccess.name);
                  },
                  child: const SellReceivePaymentScreen(),
                ),
          ),

          GoRoute(
            name: SellRoute.sellSuccess.name,
            path: SellRoute.sellSuccess.path,
            builder: (context, state) => const SellSuccessScreen(),
          ),
        ],
      ),
    ],
  );
}
