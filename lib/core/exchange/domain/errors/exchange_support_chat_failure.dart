import 'package:bb_mobile/core/failures/failure.dart';

sealed class ExchangeSupportChatFailure extends Failure {
  const ExchangeSupportChatFailure([super.logMessage]);
}

/// Could not load the chat message history.
final class LoadMessagesFailure extends ExchangeSupportChatFailure {
  const LoadMessagesFailure([super.logMessage]);
}

/// Sending a chat message (with or without attachments) failed.
final class SendMessageFailure extends ExchangeSupportChatFailure {
  const SendMessageFailure([super.logMessage]);
}

/// The user tried to send an empty message.
final class MessageEmptyFailure extends ExchangeSupportChatFailure {
  const MessageEmptyFailure();
}

/// Downloading / opening a message attachment failed.
final class LoadAttachmentFailure extends ExchangeSupportChatFailure {
  const LoadAttachmentFailure([super.logMessage]);
}

/// The attachment came back without usable file data.
final class FetchFileDataFailure extends ExchangeSupportChatFailure {
  const FetchFileDataFailure([super.logMessage]);
}

/// Media-library permission was denied (can be retried in-app).
final class PermissionDeniedFailure extends ExchangeSupportChatFailure {
  const PermissionDeniedFailure([super.logMessage]);
}

/// Media-library permission was permanently denied — the user must enable it
/// from the OS settings.
final class PermissionDeniedNeedsSettingsFailure
    extends ExchangeSupportChatFailure {
  const PermissionDeniedNeedsSettingsFailure([super.logMessage]);
}

/// Picking image files failed.
final class PickFilesFailure extends ExchangeSupportChatFailure {
  const PickFilesFailure([super.logMessage]);
}

/// Building / attaching the diagnostic logs failed.
final class AttachLogsFailure extends ExchangeSupportChatFailure {
  const AttachLogsFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI — the
/// presentation extension returns the shared generic string.
final class ExchangeSupportChatUnexpectedFailure
    extends ExchangeSupportChatFailure {
  const ExchangeSupportChatUnexpectedFailure([super.logMessage]);
}
