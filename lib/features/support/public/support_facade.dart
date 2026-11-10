import 'dart:async';

import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

/// What "contact support" means in this app.
///
/// This is the one place a fork changes to point support somewhere else: the
/// shell registers [contactSupport] in a `BullSupportScope`, and every
/// `BullSupportButton` calls it.
class SupportFacade {
  const SupportFacade._();

  /// Opens Bull Bitcoin support from [context].
  ///
  /// Inside the router, opens the exchange support chat, pre-filled with
  /// [message] when one is given; the chat route shows its login screen to a
  /// logged-out user. Outside the router (startup and init-error screens, which
  /// render before any route), opens the web support page instead.
  static void contactSupport(BuildContext context, {String? message}) {
    if (GoRouter.maybeOf(context) != null) {
      ExchangeSupportChatFacade.open(context, initialMessage: message);
      return;
    }
    unawaited(
      launchUrl(
        Uri.parse(SettingsConstants.webSupportLink),
        mode: LaunchMode.externalApplication,
      ),
    );
  }
}
