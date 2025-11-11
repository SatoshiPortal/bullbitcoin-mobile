import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/routing/recipients_router.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_view_model.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_amount_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_confirmation_screen.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_success_screen.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum WithdrawRoute {
  withdraw('/withdraw'),
  withdrawConfirmation('/withdraw/confirmation'),
  withdrawSuccess('/withdraw/success');

  final String path;

  const WithdrawRoute(this.path);
}

class WithdrawRouter {
  static final route = GoRoute(
    path: WithdrawRoute.withdraw.path,
    name: WithdrawRoute.withdraw.name,
    builder: (context, state) {
      return BlocProvider(
        create:
            (_) => locator<WithdrawBloc>()..add(const WithdrawEvent.started()),
        child: MultiBlocListener(
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
                context.pushNamed(
                  RecipientsRoute.recipients.name,
                  extra: {
                    'onRecipientSelected': (RecipientViewModel recipient) {
                      context.read<WithdrawBloc>().add(
                        WithdrawEvent.recipientSelected(recipient),
                      );
                    },
                    'selectableRecipientTypes': RecipientType.typesForCurrency(
                      context.read<WithdrawBloc>().state.currency.code,
                    ),
                  },
                );
              },
            ),
            BlocListener<WithdrawBloc, WithdrawState>(
              listenWhen:
                  (previous, current) =>
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
          final bloc = state.extra! as WithdrawBloc;
          return BlocProvider.value(
            value: bloc,
            child: BlocListener<WithdrawBloc, WithdrawState>(
              listenWhen:
                  (previous, current) =>
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
