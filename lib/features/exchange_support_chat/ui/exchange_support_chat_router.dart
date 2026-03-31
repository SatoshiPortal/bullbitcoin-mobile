import 'package:bb_mobile/features/exchange_support_chat/ui/screens/exchange_support_chat_screen.dart';
import 'package:go_router/go_router.dart';

enum ExchangeSupportChatRoute {
  supportChat('/exchange/support-chat');

  final String path;

  const ExchangeSupportChatRoute(this.path);
}

class ExchangeSupportChatRouter {
  static final route = GoRoute(
    name: ExchangeSupportChatRoute.supportChat.name,
    path: ExchangeSupportChatRoute.supportChat.path,
    builder: (context, state) {
      final fromExchange = state.uri.queryParameters['from'] == 'exchange';
      final backToWalletHome =
          state.uri.queryParameters['backToWalletHome'] == 'true';
      return ExchangeSupportChatScreen(
        fromExchange: fromExchange,
        backToWalletHome: backToWalletHome,
      );
    },
  );
}

