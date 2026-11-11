import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/screens/exchange_support_chat_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

class ExchangeSupportChatRouter {
  static GoRoute route({
    required bool Function(BuildContext) isLoggedIn,
    required Widget Function(ExchangeSupportChatDraft?) loginScreenBuilder,
    required void Function(BuildContext, bool fromExchange) onExit,
  }) => GoRoute(
    name: ExchangeSupportChatFacade.routeName,
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
                onExit: exit,
                initialMessage: draft?.initialMessage,
              )
            : loginScreenBuilder(draft),
      );
    },
  );
}
