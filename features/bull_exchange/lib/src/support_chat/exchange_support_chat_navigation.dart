import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

abstract final class ExchangeSupportChatNavigation {
  static const routeName = 'supportChat';

  /// Opens the support chat, pre-filled with [initialMessage] when given.
  /// Leaving the chat returns to the screen that opened it.
  static void open(BuildContext context, {String? initialMessage}) {
    context.pushNamed(
      routeName,
      extra: initialMessage == null
          ? null
          : ExchangeSupportChatDraft(initialMessage: initialMessage),
    );
  }
}

class ExchangeSupportChatDraft {
  final String initialMessage;

  const ExchangeSupportChatDraft({required this.initialMessage});
}
