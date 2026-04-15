import 'package:bb_mobile/features/exchange/ui/screens/exchange_support_login_screen.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/screens/exchange_support_chat_screen.dart';
import 'package:go_router/go_router.dart';

enum ExchangeSupportChatRoute {
  loginForSupport('/support/login'),
  supportChat('/support/chat');

  final String path;

  const ExchangeSupportChatRoute(this.path);
}

class ExchangeSupportChatRouter {
  static final loginForSupportRoute = GoRoute(
    name: ExchangeSupportChatRoute.loginForSupport.name,
    path: ExchangeSupportChatRoute.loginForSupport.path,
    builder: (context, state) => const ExchangeSupportLoginScreen(),
  );

  static final supportChatRoute = GoRoute(
    name: ExchangeSupportChatRoute.supportChat.name,
    path: ExchangeSupportChatRoute.supportChat.path,
    builder: (context, state) => const ExchangeSupportChatScreen(),
  );
}
