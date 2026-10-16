import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/recipients/public/recipients_ui.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_amount_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_confirmation_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_payment_details_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_recipients_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_success_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart' show SizedBox;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum WithdrawRoute {
  withdraw('/withdraw'),
  withdrawRecipients('/withdraw/recipients'),
  withdrawConfidentialSepaActivation('/withdraw/confidential-sepa-activation'),
  withdrawPaymentDetails('/withdraw/payment-details'),
  withdrawConfirmation('/withdraw/confirmation'),
  withdrawSuccess('/withdraw/success');

  final String path;

  const WithdrawRoute(this.path);
}

enum _VirtualPayeeActivationChoice { activated, regularSepa }

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
                  current is WithdrawRecipientInputState &&
                  current.recipientToActivate != null &&
                  (previous is! WithdrawRecipientInputState ||
                      previous.recipientToActivate == null),
              listener: (context, state) async {
                final bloc = context.read<WithdrawBloc>();
                final choice = await context
                    .pushNamed<_VirtualPayeeActivationChoice>(
                      WithdrawRoute.withdrawConfidentialSepaActivation.name,
                      extra: bloc,
                    );
                bloc.add(switch (choice) {
                  _VirtualPayeeActivationChoice.activated =>
                    const WithdrawEvent.virtualPayeeActivated(),
                  _VirtualPayeeActivationChoice.regularSepa =>
                    const WithdrawEvent.regularSepaChosen(),
                  null => const WithdrawEvent.virtualPayeeActivationDismissed(),
                });
              },
            ),
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
                  current is WithdrawPaymentDetailsInputState,
              listener: (context, state) {
                context.pushNamed(
                  WithdrawRoute.withdrawPaymentDetails.name,
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
            child: const WithdrawRecipientsScreen(),
          );
        },
      ),
      GoRoute(
        path: WithdrawRoute.withdrawConfidentialSepaActivation.path,
        name: WithdrawRoute.withdrawConfidentialSepaActivation.name,
        builder: (context, state) {
          final bloc = state.extra! as WithdrawBloc;
          final recipient = switch (bloc.state) {
            WithdrawRecipientInputState(:final recipientToActivate?) =>
              recipientToActivate,
            _ => null,
          };
          if (recipient == null) return const SizedBox.shrink();
          return SepaVirtualPayeeActivationScreen(
            recipientId: recipient.id,
            onActivated: () =>
                context.pop(_VirtualPayeeActivationChoice.activated),
            onUseRegularSepa: () =>
                context.pop(_VirtualPayeeActivationChoice.regularSepa),
          );
        },
      ),
      GoRoute(
        path: WithdrawRoute.withdrawPaymentDetails.path,
        name: WithdrawRoute.withdrawPaymentDetails.name,
        builder: (context, state) {
          final bloc = state.extra! as WithdrawBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<WithdrawBloc, WithdrawState>(
              listenWhen: (previous, current) =>
                  previous is WithdrawPaymentDetailsInputState &&
                  current is WithdrawConfirmationState,
              listener: (context, state) {
                context.pushNamed(
                  WithdrawRoute.withdrawConfirmation.name,
                  extra: bloc,
                );
              },
              child: const WithdrawPaymentDetailsScreen(),
            ),
          );
        },
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
