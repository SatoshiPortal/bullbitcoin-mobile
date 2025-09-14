import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_amount_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_external_wallet_network_selection_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_in_progress_screen.dart'
    as progress;
import 'package:bb_mobile/features/pay/ui/screens/pay_receive_payment_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_recipients_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_send_payment_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_sinpe_success_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_success_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_wallet_selection_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum PayRoute {
  pay('/pay'),
  payRecipients('pay-recipients'),
  payAmount('pay-amount'),
  payWalletSelection('pay-wallet-selection'),
  payExternalWalletNetworkSelection('pay-external-wallet-network-selection'),
  paySendPayment('pay-send-payment'),
  payReceivePayment('pay-receive-payment'),
  payInProgress('pay-in-progress'),
  payPaymentCompleted('payment-completed'),
  paySinpeSuccess('pay-sinpe-success');

  final String path;

  const PayRoute(this.path);
}

class PayRouter {
  static final route = GoRoute(
    path: PayRoute.pay.path,
    name: PayRoute.pay.name,
    builder: (context, state) {
      return BlocProvider(
        create: (_) => locator<PayBloc>()..add(const PayEvent.started()),
        child: MultiBlocListener(
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
                context.pushNamed(
                  PayRoute.payRecipients.name,
                  extra: context.read<PayBloc>(),
                );
              },
            ),
          ],
          child: const PayAmountScreen(),
        ),
      );
    },
    routes: [
      GoRoute(
        path: PayRoute.payRecipients.path,
        name: PayRoute.payRecipients.name,
        builder: (context, state) {
          final bloc = state.extra! as PayBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PayBloc, PayState>(
              listenWhen:
                  (previous, current) =>
                      previous is PayRecipientInputState &&
                      current is PayWalletSelectionState,
              listener: (context, state) {
                context.pushNamed(
                  PayRoute.payWalletSelection.name,
                  extra: context.read<PayBloc>(),
                );
              },
              child: const PayRecipientsScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: PayRoute.payAmount.path,
        name: PayRoute.payAmount.name,
        builder: (context, state) {
          final bloc = state.extra! as PayBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PayBloc, PayState>(
              listenWhen:
                  (previous, current) =>
                      previous is PayAmountInputState &&
                      current is PayRecipientInputState,
              listener: (context, state) {
                context.pushNamed(
                  PayRoute.payRecipients.name,
                  extra: context.read<PayBloc>(),
                );
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
          final bloc = state.extra! as PayBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PayBloc, PayState>(
              listenWhen:
                  (previous, current) =>
                      previous is PayWalletSelectionState &&
                      current is PayPaymentState &&
                      current.isInternalWallet,
              listener: (context, state) {
                context.pushNamed(
                  PayRoute.paySendPayment.name,
                  extra: context.read<PayBloc>(),
                );
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
          final bloc = state.extra! as PayBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PayBloc, PayState>(
              listenWhen:
                  (previous, current) =>
                      previous is PayWalletSelectionState &&
                      current is PayPaymentState &&
                      current.isExternalWallet,
              listener: (context, state) {
                context.pushNamed(
                  PayRoute.payReceivePayment.name,
                  extra: context.read<PayBloc>(),
                );
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
          final bloc = state.extra! as PayBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PayBloc, PayState>(
              listenWhen:
                  (previous, current) =>
                      previous is PayPaymentState && current is PaySuccessState,
              listener: (context, state) {
                context.pushNamed(
                  PayRoute.payInProgress.name,
                  extra: context.read<PayBloc>(),
                );
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
          final bloc = state.extra! as PayBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PayBloc, PayState>(
              listenWhen:
                  (previous, current) =>
                      previous is PayPaymentState && current is PaySuccessState,
              listener: (context, state) {
                context.pushNamed(
                  PayRoute.payInProgress.name,
                  extra: context.read<PayBloc>(),
                );
              },
              child: const PayReceivePaymentScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: PayRoute.payInProgress.path,
        name: PayRoute.payInProgress.name,
        builder:
            (context, state) => BlocProvider.value(
              value: state.extra! as PayBloc,
              child: const progress.PayInProgressScreen(),
            ),
      ),
      GoRoute(
        path: PayRoute.payPaymentCompleted.path,
        name: PayRoute.payPaymentCompleted.name,
        builder:
            (context, state) => BlocProvider.value(
              value: state.extra! as PayBloc,
              child: const PaySuccessScreen(),
            ),
      ),
      GoRoute(
        path: PayRoute.paySinpeSuccess.path,
        name: PayRoute.paySinpeSuccess.name,
        builder:
            (context, state) => BlocProvider.value(
              value: state.extra! as PayBloc,
              child: const PaySinpeSuccessScreen(),
            ),
      ),
    ],
  );
}
