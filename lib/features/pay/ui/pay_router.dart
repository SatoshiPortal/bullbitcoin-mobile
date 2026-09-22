import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_amount_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_external_wallet_network_selection_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_in_progress_screen.dart'
    as progress;
import 'package:bb_mobile/features/pay/ui/screens/pay_receive_payment_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_recipient_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_send_payment_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_sinpe_success_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_success_screen.dart';
import 'package:bb_mobile/features/pay/ui/screens/pay_wallet_selection_screen.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/locator.dart';
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
  paySinpeSuccess('sinpe-success'),
  payFrPayeeActivation('fr-payee-activation');

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
        child: BlocListener<PayBloc, PayState>(
          listenWhen: (previous, current) =>
              previous is PayRecipientSelectionState &&
              current is PayAmountInputState,
          listener: (context, state) {
            context.pushNamed(
              PayRoute.payAmount.name,
              extra: context.read<PayBloc>(),
            );
          },
          child: const PayRecipientScreen(),
        ),
      );
    },
    routes: [
      GoRoute(
        path: PayRoute.payAmount.path,
        name: PayRoute.payAmount.name,
        builder: (context, state) {
          final bloc = state.extra! as PayBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<PayBloc, PayState>(
              listenWhen: (previous, current) =>
                  previous is PayAmountInputState &&
                  current is PayWalletSelectionState,
              listener: (context, state) {
                context.pushNamed(
                  PayRoute.payWalletSelection.name,
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
            child: MultiBlocListener(
              listeners: [
                BlocListener<PayBloc, PayState>(
                  listenWhen: (previous, current) =>
                      previous is PayWalletSelectionState &&
                      current is PayPaymentState &&
                      current.isInternalWallet,
                  listener: (context, state) {
                    context.pushNamed(
                      PayRoute.paySendPayment.name,
                      extra: context.read<PayBloc>(),
                    );
                  },
                ),
                BlocListener<PayBloc, PayState>(
                  listenWhen: _confidentialSepaErrorAppeared,
                  listener: _pushPayActivation,
                ),
              ],
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
              listenWhen: (previous, current) =>
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
              listenWhen: (previous, current) =>
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
              listenWhen: (previous, current) =>
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
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as PayBloc,
          child: const progress.PayInProgressScreen(),
        ),
      ),
      GoRoute(
        path: PayRoute.payPaymentCompleted.path,
        name: PayRoute.payPaymentCompleted.name,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as PayBloc,
          child: const PaySuccessScreen(),
        ),
      ),
      GoRoute(
        path: PayRoute.paySinpeSuccess.path,
        name: PayRoute.paySinpeSuccess.name,
        builder: (context, state) => BlocProvider.value(
          value: state.extra! as PayBloc,
          child: const PaySinpeSuccessScreen(),
        ),
      ),
      GoRoute(
        path: PayRoute.payFrPayeeActivation.path,
        name: PayRoute.payFrPayeeActivation.name,
        builder: (context, state) {
          final args = state.extra! as FrPayeeActivationArgs;
          return FrPayeeActivationScreen(
            recipient: args.recipient,
            onActivated: args.onActivated,
            onUseRegularSepa: args.onUseRegularSepa,
          );
        },
      ),
    ],
  );
}

bool _confidentialSepaErrorAppeared(PayState previous, PayState current) {
  final currentError = current is PayWalletSelectionState
      ? current.error
      : null;
  final previousError = previous is PayWalletSelectionState
      ? previous.error
      : null;
  return currentError is PayConfidentialSepaNotActivatedFailure &&
      previousError is! PayConfidentialSepaNotActivatedFailure;
}

void _pushPayActivation(BuildContext context, PayState state) {
  final recipient = (state as PayWalletSelectionState).selectedRecipient;
  final bloc = context.read<PayBloc>();
  context.pushNamed(
    PayRoute.payFrPayeeActivation.name,
    extra: FrPayeeActivationArgs(
      recipient: recipient,
      onActivated: (activated) => bloc.add(
        PayEvent.recipientUpdated(activated, resumePendingOrder: true),
      ),
      onUseRegularSepa: recipient.supportsRegularSepa
          ? () => bloc.add(
              PayEvent.recipientUpdated(
                recipient.copyWith(type: RecipientType.sepaEur),
                resumePendingOrder: true,
              ),
            )
          : null,
    ),
  );
}
