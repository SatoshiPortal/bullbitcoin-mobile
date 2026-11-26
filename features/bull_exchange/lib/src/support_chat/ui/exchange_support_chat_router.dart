import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:primitives/primitives.dart';

import '../exchange_support_chat_navigation.dart';
import 'screens/exchange_support_chat_screen.dart';
import 'screens/exchange_support_login_screen.dart';

class ExchangeSupportChatRouter {
  static GoRoute route({
    required Exchange Function() exchange,
    required bool Function(BuildContext) isLoggedIn,
    required Future<Result<void, ExchangeFailure>> Function(BuildContext)
    enableLogin,
    required void Function(BuildContext, ExchangeSupportChatDraft?) onLogin,
    required String Function(BuildContext) loginLabel,
    required String Function(BuildContext, ExchangeFailure) failureMessage,
    required void Function(BuildContext, bool fromExchange) onExit,
    required void Function(BuildContext) onMessagesRead,
  }) => GoRoute(
    name: ExchangeSupportChatNavigation.routeName,
    path: ExchangeSupportChatNavigation.path,
    builder: (context, state) {
      final draft = state.extra as ExchangeSupportChatDraft?;
      final fromExchange = state.uri.queryParameters['from'] == 'exchange';
      void exit() => onExit(context, fromExchange);
      void back() => context.canPop() ? context.pop() : exit();
      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) exit();
        },
        child: isLoggedIn(context)
            ? ExchangeSupportChatScreen(
                exchange: exchange(),
                onExit: exit,
                onMessagesRead: () => onMessagesRead(context),
                initialMessage: draft?.initialMessage,
              )
            : ExchangeSupportLoginScreen(
                enable: enableLogin,
                onLogin: (context) => onLogin(context, draft),
                loginLabel: loginLabel,
                failureMessage: failureMessage,
                onBack: back,
              ),
      );
    },
  );
}
