import 'package:bb_mobile/core/errors/exchange_errors.dart';
import 'package:bb_mobile/core/exchange/data/exchange_authentication.dart';
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
      final userId = await _userId();
      if (userId == null) {
        // No usable identity behind the key: the session is not good enough to read the thread, which is an auth problem rather than a transport one.
        log.warning('Support chat: user summary carries no user id');
        return const Err(NotAuthenticatedFailure());
      }

      final messages = await _commcenter.listMessages(
        page: page ?? 1,
        pageSize: pageSize ?? 10,
      );
      return Ok([for (final m in messages) _message(m, userId)]);
    } on ApiKeyException catch (e, st) {
      log.warning(
        'Support chat: not authenticated',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(NotAuthenticatedFailure());
    } catch (e, st) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return refusal.isUnauthenticated
            ? const Err(NotAuthenticatedFailure())
            : const Err(LoadMessagesFailure('Exchange credential unavailable'));
      }
      log.warning(
        'Failed to load support chat messages',
        error: e.runtimeType,
        trace: st,
      );
      return Err(LoadMessagesFailure('Load messages failed: ${e.runtimeType}'));
    }
  }

  @override
  Future<Result<void, ExchangeSupportChatFailure>> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  }) async {
    try {
      await _commcenter.sendMessageToSupport(
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
      return const Ok(null);
    } on ApiKeyException catch (e, st) {
      log.warning(
        'Support chat: not authenticated',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(NotAuthenticatedFailure());
    } catch (e, st) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return refusal.isUnauthenticated
            ? const Err(NotAuthenticatedFailure())
            : const Err(SendMessageFailure('Exchange credential unavailable'));
      }
      log.warning(
        'Failed to send support chat message',
        error: e.runtimeType,
        trace: st,
      );
      return Err(SendMessageFailure('Send message failed: ${e.runtimeType}'));
    }
  }

  @override
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  getMessageAttachment(String attachmentId) async {
    try {
      final a = await _commcenter.getMessageAttachment(attachmentId);
      return Ok(_attachment(a, messageId: a.messageId));
    } on ApiKeyException catch (e, st) {
      log.warning(
        'Support chat: not authenticated',
        error: e.runtimeType,
        trace: st,
      );
      return const Err(NotAuthenticatedFailure());
    } catch (e, st) {
      final refusal = exchangeAuthenticationException(e);
      if (refusal != null) {
        return refusal.isUnauthenticated
            ? const Err(NotAuthenticatedFailure())
            : const Err(
                LoadAttachmentFailure('Exchange credential unavailable'),
              );
      }
      log.warning(
        'Failed to load support chat attachment',
        error: e.runtimeType,
        trace: st,
      );
      return Err(
        LoadAttachmentFailure('Load attachment failed: ${e.runtimeType}'),
      );
    }
  }

  /// The user's id; `null` also when the server answers with a JSON-RPC
  /// error, which counts as an empty result.
  Future<String?> _userId() async {
    try {
      return (await _users.getUserSummary())?.userId;
    } on bbx.BbxApiRpcException {
      return null;
    }
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
