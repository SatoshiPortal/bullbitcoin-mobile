import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../exchange_support_chat_navigation.dart';
import 'screens/exchange_support_chat_screen.dart';

class ExchangeSupportChatRouter {
  static GoRoute route({
    required Exchange Function() exchange,
    required bool Function(BuildContext) isLoggedIn,
    required Widget Function(ExchangeSupportChatDraft?) loginScreenBuilder,
    required void Function(BuildContext, bool fromExchange) onExit,
  }) => GoRoute(
    name: ExchangeSupportChatNavigation.routeName,
    path: '/exchange/support-chat',
    builder: (context, state) {
      final draft = state.extra as ExchangeSupportChatDraft?;
      final fromExchange = state.uri.queryParameters['from'] == 'exchange';
      void exit() => onExit(context, fromExchange);
      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) exit();
        },
        child: isLoggedIn(context)
            ? ExchangeSupportChatScreen(
                exchange: exchange(),
                onExit: exit,
                initialMessage: draft?.initialMessage,
              )
            : loginScreenBuilder(draft),
      );
    },
  );
}
