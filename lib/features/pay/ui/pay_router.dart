import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_amount_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_external_wallet_network_selection_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_receive_payment_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_recipients_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_send_payment_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_success_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_wallet_selection_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PayRoute {
  pay('/pay'),
  payRecipients('recipients'),
  payWalletSelection('wallet-selection'),
  payExternalWalletNetworkSelection('external-wallet-network-selection'),
  paySendPayment('send-payment'),
  payReceivePayment('receive-payment'),
  paySuccess('success');

  final String path;

  const PayRoute(this.path);
}

class PayRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create: (_) => locator<PayBloc>()..add(const PayEvent.started()),
        child: child,
      );
    },
    routes: [
      GoRoute(
        path: PayRoute.pay.path,
        name: PayRoute.pay.name,
        builder: (context, state) {
          return MultiBlocListener(
            listeners: [
              BlocListener<PayBloc, PayState>(
                listenWhen:
                    (previous, current) =>
                        previous is PayInitialState &&
                        previous.apiKeyException == null &&
                        current is PayInitialState &&
                        current.apiKeyException != null,
                listener: (context, state) {
                  context.goNamed(ExchangeRoute.exchangeHome.name);
                },
              ),
              BlocListener<PayBloc, PayState>(
                listenWhen:
                    (previous, current) =>
                        previous is PayAmountInputState &&
                        current is PayRecipientInputState,
                listener: (context, state) {
                  context.pushNamed(PayRoute.payRecipients.name);
                },
              ),
              BlocListener<PayBloc, PayState>(
                listenWhen:
                    (previous, current) =>
                        previous is PayRecipientInputState &&
                        current is PayWalletSelectionState,
                listener: (context, state) {
                  context.pushNamed(PayRoute.payWalletSelection.name);
                },
              ),
              BlocListener<PayBloc, PayState>(
                listenWhen:
                    (previous, current) =>
                        previous is PayWalletSelectionState &&
                        current is PayPaymentState &&
                        current.isExternalWallet,
                listener: (context, state) {
                  context.pushNamed(PayRoute.payReceivePayment.name);
                },
              ),
              BlocListener<PayBloc, PayState>(
                listenWhen:
                    (previous, current) =>
                        previous is PayWalletSelectionState &&
                        current is PayPaymentState &&
                        current.isInternalWallet,
                listener: (context, state) {
                  context.pushNamed(PayRoute.paySendPayment.name);
                },
              ),
              BlocListener<PayBloc, PayState>(
                listenWhen:
                    (previous, current) =>
                        previous is PayPaymentState &&
                        current is PaySuccessState,
                listener: (context, state) {
                  context.pushNamed(PayRoute.paySuccess.name);
                },
              ),
            ],
            child: const PayAmountScreen(),
          );
        },
        routes: [
          GoRoute(
            path: PayRoute.payRecipients.path,
            name: PayRoute.payRecipients.name,
            builder: (context, state) => const PayRecipientsScreen(),
          ),
          GoRoute(
            path: PayRoute.payWalletSelection.path,
            name: PayRoute.payWalletSelection.name,
            builder: (context, state) => const PayWalletSelectionScreen(),
          ),
          GoRoute(
            path: PayRoute.payExternalWalletNetworkSelection.path,
            name: PayRoute.payExternalWalletNetworkSelection.name,
            builder:
                (context, state) => BlocListener<PayBloc, PayState>(
                  listenWhen:
                      (previous, current) =>
                          previous is PayWalletSelectionState &&
                          current is PayPaymentState &&
                          current.isExternalWallet,
                  listener: (context, state) {
                    context.pushNamed(PayRoute.payReceivePayment.name);
                  },
                  child: const PayExternalWalletNetworkSelectionScreen(),
                ),
          ),
          GoRoute(
            path: PayRoute.paySendPayment.path,
            name: PayRoute.paySendPayment.name,
            builder: (context, state) => const PaySendPaymentScreen(),
          ),
          GoRoute(
            path: PayRoute.payReceivePayment.path,
            name: PayRoute.payReceivePayment.name,
            builder: (context, state) => const PayReceivePaymentScreen(),
          ),
          GoRoute(
            path: PayRoute.paySuccess.path,
            name: PayRoute.paySuccess.name,
            builder: (context, state) => const PaySuccessScreen(),
          ),
        ],
      ),
    ],
  );
}
