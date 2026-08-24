import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_support_login_screen.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/screens/exchange_support_chat_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class ExchangeSupportChatRouter {
  static final route = GoRoute(
    name: ExchangeSupportChatFacade.routeName,
    path: '/exchange/support-chat',
    builder: (context, state) {
      final draft = state.extra as ExchangeSupportChatDraft?;
      if (context.read<ExchangeCubit>().state.notLoggedIn) {
        return ExchangeSupportLoginScreen(draft: draft);
      }
      final fromExchange = state.uri.queryParameters['from'] == 'exchange';
      return ExchangeSupportChatScreen(
        fromExchange: fromExchange,
        initialMessage: draft?.initialMessage,
      );
    },
  );
}
