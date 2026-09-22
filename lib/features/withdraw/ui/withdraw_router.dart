import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_failure.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_amount_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_confirmation_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_payment_description_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_recipients_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_success_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum WithdrawRoute {
  withdraw('/withdraw'),
  withdrawRecipients('/withdraw/recipients'),
  withdrawFrPayeeActivation('/withdraw/fr-payee-activation'),
  withdrawPaymentDescription('/withdraw/payment-description'),
  withdrawConfirmation('/withdraw/confirmation'),
  withdrawSuccess('/withdraw/success');

  final String path;

  const WithdrawRoute(this.path);
}

class WithdrawRouter {
  static final route = GoRoute(
    path: WithdrawRoute.withdraw.path,
    name: WithdrawRoute.withdraw.name,
    redirect: (context, state) {
      final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
      if (notLoggedIn) return ExchangeRoute.exchangeHome.path;
      return null;
    },
    builder: (context, state) {
      return BlocProvider(
        create: (_) =>
            locator<WithdrawBloc>()..add(const WithdrawEvent.started()),
        child: MultiBlocListener(
          listeners: [
            BlocListener<WithdrawBloc, WithdrawState>(
              listenWhen: (previous, current) =>
                  previous is WithdrawAmountInputState &&
                  current is WithdrawRecipientInputState,
              listener: (context, state) {
                context.pushNamed(
                  WithdrawRoute.withdrawRecipients.name,
                  extra: context.read<WithdrawBloc>(),
                );
              },
            ),
            BlocListener<WithdrawBloc, WithdrawState>(
              listenWhen: (previous, current) =>
                  previous is WithdrawRecipientInputState &&
                  current is WithdrawConfirmationState,
              listener: (context, state) {
                context.pushNamed(
                  WithdrawRoute.withdrawConfirmation.name,
                  extra: context.read<WithdrawBloc>(),
                );
              },
            ),
          ],
          child: const WithdrawAmountScreen(),
        ),
      );
    },
    routes: [
      GoRoute(
        path: WithdrawRoute.withdrawRecipients.path,
        name: WithdrawRoute.withdrawRecipients.name,
        builder: (context, state) {
          final bloc = state.extra! as WithdrawBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<WithdrawBloc, WithdrawState>(
              listenWhen: _confidentialSepaWithdrawErrorAppeared,
              listener: _pushWithdrawActivation,
              child: const WithdrawRecipientsScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: WithdrawRoute.withdrawFrPayeeActivation.path,
        name: WithdrawRoute.withdrawFrPayeeActivation.name,
        builder: (context, state) {
          final args = state.extra! as FrPayeeActivationArgs;
          return FrPayeeActivationScreen(
            recipient: args.recipient,
            onActivated: args.onActivated,
            onUseRegularSepa: args.onUseRegularSepa,
          );
        },
      ),
      GoRoute(
        path: WithdrawRoute.withdrawPaymentDescription.path,
        name: WithdrawRoute.withdrawPaymentDescription.name,
        builder: (context, state) => WithdrawPaymentDescriptionScreen(
          initialDescription: state.extra as String? ?? '',
        ),
      ),
      GoRoute(
        path: WithdrawRoute.withdrawConfirmation.path,
        name: WithdrawRoute.withdrawConfirmation.name,
        builder: (context, state) {
          final bloc = state.extra! as WithdrawBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<WithdrawBloc, WithdrawState>(
              listenWhen: (previous, current) =>
                  previous is WithdrawConfirmationState &&
                  current is WithdrawSuccessState,
              listener: (context, state) {
                context.pushNamed(
                  WithdrawRoute.withdrawSuccess.name,
                  extra: bloc,
                );
              },
              child: const WithdrawConfirmationScreen(),
            ),
          );
        },
      ),
      GoRoute(
        path: WithdrawRoute.withdrawSuccess.path,
        name: WithdrawRoute.withdrawSuccess.name,
        builder: (context, state) {
          final bloc = state.extra! as WithdrawBloc;
          return BlocProvider.value(
            value: bloc,
            child: const WithdrawSuccessScreen(),
          );
        },
      ),
    ],
  );
}

bool _confidentialSepaWithdrawErrorAppeared(
  WithdrawState previous,
  WithdrawState current,
) {
  final currentError = current is WithdrawRecipientInputState
      ? current.selectedRecipientError ?? current.newRecipientError
      : null;
  final previousError = previous is WithdrawRecipientInputState
      ? previous.selectedRecipientError ?? previous.newRecipientError
      : null;
  return currentError is WithdrawConfidentialSepaNotActivatedFailure &&
      previousError is! WithdrawConfidentialSepaNotActivatedFailure;
}

void _pushWithdrawActivation(BuildContext context, WithdrawState state) {
  final recipientState = state as WithdrawRecipientInputState;
  final recipient = recipientState.selectedRecipient;
  if (recipient == null) return;
  final isNew = recipientState.newRecipientError != null;
  final bloc = context.read<WithdrawBloc>();
  context.pushNamed(
    WithdrawRoute.withdrawFrPayeeActivation.name,
    extra: FrPayeeActivationArgs(
      recipient: recipient,
      onActivated: (activated) => bloc.add(
        WithdrawEvent.recipientSelected(
          activated,
          isNew: isNew,
          paymentDescription: recipientState.paymentDescription,
        ),
      ),
      onUseRegularSepa: recipient.supportsRegularSepa
          ? () => bloc.add(
              WithdrawEvent.recipientSelected(
                recipient.copyWith(type: RecipientType.sepaEur),
                isNew: isNew,
                paymentDescription: recipientState.paymentDescription,
              ),
            )
          : null,
    ),
  );
}
