// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'exchange_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ExchangeLocalizationsEn extends ExchangeLocalizations {
  ExchangeLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get exchangeSupportChatAttachFileTooltip => 'Attach a file';

  @override
  String get exchangeSupportChatAttachLogsFailed =>
      'Failed to attach logs. Please try again.';

  @override
  String get exchangeSupportChatAttachLogsTooltip => 'Attach logs';

  @override
  String get exchangeSupportChatAttachmentImage => 'Image';

  @override
  String get exchangeSupportChatAttachmentUnknownFile => 'Unknown file';

  @override
  String get exchangeSupportChatEmptyState =>
      'No messages yet. Start a conversation!';

  @override
  String get exchangeSupportChatFetchFileDataFailed =>
      'Failed to fetch file data';

  @override
  String get exchangeSupportChatInputHint => 'Type a message…';

  @override
  String get exchangeSupportChatLoadAttachmentError =>
      'Couldn\'t open the attachment. Please try again.';

  @override
  String get exchangeSupportChatLoadMessagesError =>
      'Couldn\'t load messages. Please try again.';

  @override
  String get exchangeSupportChatMessageEmptyError => 'Message cannot be empty';

  @override
  String get exchangeSupportChatMessageRequired => 'A message is required';

  @override
  String get exchangeSupportChatPickFilesFailed =>
      'Failed to pick files. Please try again.';

  @override
  String get exchangeSupportChatSendMessageError =>
      'Couldn\'t send your message. Please try again.';

  @override
  String get exchangeSupportChatSendTooltip => 'Send message';

  @override
  String get exchangeSupportChatTitle => 'Support Chat';

  @override
  String get exchangeSupportChatYesterday => 'Yesterday';

  @override
  String get exchangeSupportLoginChatRequired =>
      'To get human support, you must first log in to your Bull Bitcoin account. It\'s 100% free and no KYC is required, only an email address.';

  @override
  String get oopsSomethingWentWrong => 'Oops! Something went wrong';

  @override
  String get exchangeSupportChatLogDraft => 'Here are my logs';
}
