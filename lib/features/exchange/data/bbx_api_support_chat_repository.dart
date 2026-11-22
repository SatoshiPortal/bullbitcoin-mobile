import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_support_chat_repository.dart';
import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart';

/// [ExchangeSupportChatRepository] through the `bbx_api` package.
///
/// [users] and [commcenter] may come from different clients: the chat calls
/// carry attachments and run without the request timeout.
class BbxApiSupportChatRepository implements ExchangeSupportChatRepository {
  static const _source = 'BULL Mobile';

  final bbx.UsersApi _users;
  final bbx.CommcenterApi _commcenter;

  BbxApiSupportChatRepository({
    required this._users,
    required this._commcenter,
  });

  @override
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>>
  getMessages({int? page, int? pageSize}) async {
    try {
      final userResult = await _users.getUserSummary();
      final String? userId;
      switch (userResult) {
        case Ok(:final value):
          userId = value?.userId;
        case Err(failure: bbx.BbxRpcFailure()):
          userId = null;
        case Err(:final failure):
          return Err(_failure(failure, LoadMessagesFailure.new, 'load'));
      }
      if (userId == null) {
        // No usable identity behind the key: the session is not good enough
        // to read the thread, which is an auth problem rather than transport.
        log.warning('Support chat: user summary carries no user id');
        return const Err(NotAuthenticatedFailure());
      }

      final messagesResult = await _commcenter.listMessages(
        page: page ?? 1,
        pageSize: pageSize ?? 10,
      );
      return switch (messagesResult) {
        Ok(:final value) => Ok([for (final m in value) _message(m, userId)]),
        Err(:final failure) => Err(
          _failure(failure, LoadMessagesFailure.new, 'load'),
        ),
      };
    } catch (e, st) {
      return Err(_unexpected(e, st, LoadMessagesFailure.new, 'load'));
    }
  }

  @override
  Future<Result<void, ExchangeSupportChatFailure>> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) async {
    try {
      final result = await _commcenter.sendMessageToSupport(
        text: text,
        source: _source,
        attachments: attachments == null
            ? null
            : [
                for (final attachment in attachments)
                  if (attachment.fileData case final fileData?)
                    bbx.NewSupportAttachment(
                      fileName: attachment.fileName,
                      fileType: attachment.fileType,
                      fileSize: attachment.fileSize,
                      fileData: fileData,
                    ),
              ],
      );
      return switch (result) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(
          _failure(failure, SendMessageFailure.new, 'send'),
        ),
      };
    } catch (e, st) {
      return Err(_unexpected(e, st, SendMessageFailure.new, 'send'));
    }
  }

  @override
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  getMessageAttachment(String attachmentId) async {
    try {
      final result = await _commcenter.getMessageAttachment(attachmentId);
      return switch (result) {
        Ok(:final value) => Ok(_attachment(value, messageId: value.messageId)),
        Err(:final failure) => Err(
          _failure(failure, LoadAttachmentFailure.new, 'load attachment'),
        ),
      };
    } catch (e, st) {
      return Err(
        _unexpected(e, st, LoadAttachmentFailure.new, 'load attachment'),
      );
    }
  }

  static ExchangeSupportChatFailure _failure(
    bbx.BbxFailure failure,
    ExchangeSupportChatFailure Function(String) onFailure,
    String operation,
  ) {
    switch (failure) {
      case bbx.BbxMissingCredentialFailure():
        log.warning(
          'Support chat: not authenticated',
          error: failure.runtimeType,
        );
        return const NotAuthenticatedFailure();
      case bbx.BbxCredentialUnavailableFailure():
        return onFailure('Exchange credential unavailable');
      default:
        log.warning(
          'Failed to $operation support chat data',
          error: failure.runtimeType,
        );
        return onFailure('$operation failed: ${failure.runtimeType}');
    }
  }

  static ExchangeSupportChatFailure _unexpected(
    Object e,
    StackTrace st,
    ExchangeSupportChatFailure Function(String) onFailure,
    String operation,
  ) {
    if (e is Error) Error.throwWithStackTrace(e, st);
    log.warning(
      'Failed to $operation support chat data',
      error: e.runtimeType,
      trace: st,
    );
    return onFailure('$operation failed: ${e.runtimeType}');
  }

  /// A message not sent by [userId] is from support. Attachments without an
  /// id or a file name are dropped; one without a message id takes the
  /// message's.
  static SupportChatMessage _message(bbx.SupportMessage m, String userId) =>
      SupportChatMessage(
        messageId: m.messageId,
        text: m.text,
        fromUserId: m.fromUserId,
        toGroupCode: m.toGroupCode,
        createdAt: m.createdAt,
        updatedAt: m.updatedAt,
        isAdmin: m.fromUserId != userId,
        attachments: m.attachments
            ?.where((a) => a.attachmentId != null || a.fileName != null)
            .map((a) => _attachment(a, messageId: a.messageId ?? m.messageId))
            .toList(),
      );

  static SupportChatMessageAttachment _attachment(
    bbx.SupportAttachment a, {
    required String? messageId,
  }) => SupportChatMessageAttachment(
    attachmentId: a.attachmentId,
    fileName: a.fileName,
    fileType: a.fileType,
    fileSize: a.fileSize,
    fileData: a.fileData,
    messageId: messageId,
    createdAt: a.createdAt,
  );
}
