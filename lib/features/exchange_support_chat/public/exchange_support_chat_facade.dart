export '../exchange_support_chat_locator.dart' show ExchangeSupportChatLocator;
export '../ui/exchange_support_chat_router.dart' show ExchangeSupportChatRouter;

class ExchangeSupportChatFacade {
  static const routeName = 'supportChat';

  const ExchangeSupportChatFacade._();
}

class ExchangeSupportChatDraft {
  final String initialMessage;

  const ExchangeSupportChatDraft({required this.initialMessage});
}
