import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_amount_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_external_wallet_network_selection_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_in_progress_screen.dart'
    as progress;
import 'package:bull_exchange/src/pay/ui/screens/pay_receive_payment_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_recipient_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_send_payment_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_sinpe_success_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_success_screen.dart';
import 'package:bull_exchange/src/pay/ui/screens/pay_wallet_selection_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PayRoute {
  pay('/pay'),
  payAmount('amount'),
  payWalletSelection('wallet-selection'),
  payExternalWalletNetworkSelection('external-wallet-network-selection'),
  paySendPayment('send-payment'),
  payReceivePayment('receive-payment'),
  payInProgress('in-progress'),
  payPaymentCompleted('payment-completed'),
  paySinpeSuccess('sinpe-success');

  final String path;

  const PayRoute(this.path);
}

class PayRouter {
  static ShellRoute route({
    required PayBloc Function() createBloc,
    required ExchangePayinUi ui,
  }) => ShellRoute(
    builder: (context, state, child) => RepositoryProvider.value(
      value: ui,
      child: BlocProvider(
        create: (_) => createBloc()..add(const PayEvent.started()),
        child: child,
      ),
    ),
    routes: [_entryRoute()],
  );

  static GoRoute _entryRoute() => GoRoute(
    path: PayRoute.pay.path,
    name: PayRoute.pay.name,
    builder: (context, state) {
      return BlocListener<PayBloc, PayState>(
        listenWhen: (previous, current) =>
            previous is PayRecipientSelectionState &&
            current is PayAmountInputState,
        listener: (context, state) {
          context.pushNamed(PayRoute.payAmount.name);
        },
        child: const PayRecipientScreen(),
      );
    },
    routes: [
      GoRoute(
        path: PayRoute.payAmount.path,
        name: PayRoute.payAmount.name,
        builder: (context, state) {
          return _PayRouteGuard(
            child: BlocListener<PayBloc, PayState>(
              listenWhen: (previous, current) =>
                  previous is PayAmountInputState &&
                  current is PayWalletSelectionState,
              listener: (context, state) {
                context.pushNamed(PayRoute.payWalletSelection.name);
              },
              child: const PayAmountScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: PayRoute.payWalletSelection.path,
        name: PayRoute.payWalletSelection.name,
        builder: (context, state) {
          return _PayRouteGuard(
            child: BlocListener<PayBloc, PayState>(
              listenWhen: (previous, current) =>
                  current is PayPreparingPaymentState &&
                  previous is! PayPreparingPaymentState &&
                  current.selectedWallet != null,
              listener: (context, state) {
                context.pushNamed(PayRoute.paySendPayment.name);
              },
              child: const PayWalletSelectionScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: PayRoute.payExternalWalletNetworkSelection.path,
        name: PayRoute.payExternalWalletNetworkSelection.name,
        builder: (context, state) {
          return _PayRouteGuard(
            child: BlocListener<PayBloc, PayState>(
              listenWhen: (previous, current) =>
                  current is PayPreparingPaymentState &&
                  previous is! PayPreparingPaymentState &&
                  current.selectedWallet == null,
              listener: (context, state) {
                context.pushNamed(PayRoute.payReceivePayment.name);
              },
              child: const PayExternalWalletNetworkSelectionScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: PayRoute.paySendPayment.path,
        name: PayRoute.paySendPayment.name,
        builder: (context, state) {
          return _PayRouteGuard(
            child: BlocListener<PayBloc, PayState>(
              listenWhen: (previous, current) =>
                  previous is PayPaymentState && current is PaySuccessState,
              listener: (context, state) {
                context.pushNamed(PayRoute.payInProgress.name);
              },
              child: const PaySendPaymentScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: PayRoute.payReceivePayment.path,
        name: PayRoute.payReceivePayment.name,
        builder: (context, state) {
          return _PayRouteGuard(
            child: BlocListener<PayBloc, PayState>(
              listenWhen: (previous, current) =>
                  previous is PayPaymentState && current is PaySuccessState,
              listener: (context, state) {
                context.pushNamed(PayRoute.payInProgress.name);
              },
              child: const PayReceivePaymentScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: PayRoute.payInProgress.path,
        name: PayRoute.payInProgress.name,
        builder: (context, state) =>
            _PayRouteGuard(child: const progress.PayInProgressScreen()),
      ),
      GoRoute(
        path: PayRoute.payPaymentCompleted.path,
        name: PayRoute.payPaymentCompleted.name,
        builder: (context, state) =>
            _PayRouteGuard(child: const PaySuccessScreen()),
      ),
      GoRoute(
        path: PayRoute.paySinpeSuccess.path,
        name: PayRoute.paySinpeSuccess.name,
        builder: (context, state) =>
            _PayRouteGuard(child: const PaySinpeSuccessScreen()),
      ),
    ],
  );
}

/// A restored subroute has no recipient or order until the in-memory flow starts.
class _PayRouteGuard extends StatelessWidget {
  final Widget child;

  const _PayRouteGuard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isAtEntry = context.select(
      (PayBloc bloc) => switch (bloc.state) {
        PayRecipientSelectionState() => true,
        _ => false,
      },
    );
    if (!isAtEntry) return child;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final router = GoRouter.of(context);
      final location = router.routeInformationProvider.value.uri.path;
      if (location.startsWith('${PayRoute.pay.path}/')) {
        context.goNamed(PayRoute.pay.name);
      }
    });
    return const SizedBox.shrink();
  }
}
