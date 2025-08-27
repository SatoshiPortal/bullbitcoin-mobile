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
  withdrawRecipients('recipients'),
  withdrawConfirmation('confirmation'),
  withdrawSuccess('success');

  final String path;

  const WithdrawRoute(this.path);
}

class WithdrawRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      return BlocProvider(
        create:
            (_) => locator<WithdrawBloc>()..add(const WithdrawEvent.started()),
        child: child,
      );
    },
    routes: [
      GoRoute(
        path: WithdrawRoute.withdraw.path,
        name: WithdrawRoute.withdraw.name,
        builder: (context, state) {
          return MultiBlocListener(
            listeners: [
              BlocListener<WithdrawBloc, WithdrawState>(
                listenWhen:
                    (previous, current) =>
                        previous is WithdrawInitialState &&
                        previous.apiKeyException == null &&
                        current is WithdrawInitialState &&
                        current.apiKeyException != null,
                listener: (context, state) {
                  // Redirect to exchange home if API key exception occurs which means the user is not authenticated
                  context.goNamed(ExchangeRoute.exchangeHome.name);
                },
              ),
              BlocListener<WithdrawBloc, WithdrawState>(
                listenWhen:
                    (previous, current) =>
                        previous is WithdrawAmountInputState &&
                        current is WithdrawRecipientInputState,
                listener: (context, state) {
                  context.pushNamed(WithdrawRoute.withdrawRecipients.name);
                },
              ),
            ],
            child: const WithdrawAmountScreen(),
          );
        },
        routes: [
          GoRoute(
            path: WithdrawRoute.withdrawRecipients.path,
            name: WithdrawRoute.withdrawRecipients.name,
            builder: (context, state) {
              return BlocListener<WithdrawBloc, WithdrawState>(
                listenWhen:
                    (previous, current) =>
                        previous is WithdrawRecipientInputState &&
                        current is WithdrawConfirmationState,
                listener: (context, state) {
                  context.pushNamed(WithdrawRoute.withdrawConfirmation.name);
                },
                child: const WithdrawRecipientsScreen(),
              );
            },
          ),
          /*GoRoute(
        path: WithdrawRoute.withdrawDescription.path,
        name: WithdrawRoute.withdrawDescription.name,
        builder: (context, state) {
          return const WithdrawDescriptionScreen();
        },
      ),*/
          GoRoute(
            path: WithdrawRoute.withdrawConfirmation.path,
            name: WithdrawRoute.withdrawConfirmation.name,
            builder: (context, state) {
              return BlocListener<WithdrawBloc, WithdrawState>(
                listenWhen:
                    (previous, current) =>
                        previous is WithdrawConfirmationState &&
                        current is WithdrawSuccessState,
                listener: (context, state) {
                  context.pushNamed(WithdrawRoute.withdrawSuccess.name);
                },
                child: const WithdrawConfirmationScreen(),
              );
            },
          ),

          GoRoute(
            path: WithdrawRoute.withdrawSuccess.path,
            name: WithdrawRoute.withdrawSuccess.name,
            builder: (context, state) {
              return const WithdrawSuccessScreen();
            },
          ),
        ],
      ),
    ],
  );
}
