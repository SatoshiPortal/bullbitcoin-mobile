import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

extension ExchangeSupportChatFailureL10n on ExchangeSupportChatFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NotAuthenticatedFailure() => context.loc.exchangeSupportLoginChatRequired,
    LoadMessagesFailure() => context.loc.exchangeSupportChatLoadMessagesError,
    SendMessageFailure() => context.loc.exchangeSupportChatSendMessageError,
    MessageEmptyFailure() => context.loc.exchangeSupportChatMessageEmptyError,
    LoadAttachmentFailure() =>
      context.loc.exchangeSupportChatLoadAttachmentError,
    FetchFileDataFailure() =>
      context.loc.exchangeSupportChatFetchFileDataFailed,
    PickFilesFailure() => context.loc.exchangeSupportChatPickFilesFailed,
    AttachLogsFailure() => context.loc.exchangeSupportChatAttachLogsFailed,
    ExchangeSupportChatUnexpectedFailure() =>
      context.loc.oopsSomethingWentWrong,
  };
}
