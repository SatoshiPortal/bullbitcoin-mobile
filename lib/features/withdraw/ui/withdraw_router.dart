import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_amount_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_confirmation_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_recipients_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_success_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum WithdrawRoute {
  withdraw('/withdraw'),
  withdrawRecipients('/withdraw/recipients'),
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
            child: const WithdrawRecipientsScreen(),
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
