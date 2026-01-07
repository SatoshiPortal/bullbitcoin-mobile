import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/notification_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/create_log_attachment_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/exchange_notification_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_messages_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/pick_image_attachments_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/share_attachment_usecase.dart';
import 'package:bb_mobile/features/exchange_support_chat/presentation/exchange_support_chat_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeSupportChatCubit extends Cubit<ExchangeSupportChatState> {
  ExchangeSupportChatCubit({
    required GetSupportChatMessagesUsecase getMessagesUsecase,
    required SendSupportChatMessageUsecase sendMessageUsecase,
    required GetExchangeUserSummaryUsecase getUserSummaryUsecase,
    required CreateLogAttachmentUsecase createLogAttachmentUsecase,
    required ExchangeNotificationUsecase exchangeNotificationUsecase,
    required PickImageAttachmentsUsecase pickImageAttachmentsUsecase,
    required ShareAttachmentUsecase shareAttachmentUsecase,
  }) : _getMessagesUsecase = getMessagesUsecase,
       _sendMessageUsecase = sendMessageUsecase,
       _getUserSummaryUsecase = getUserSummaryUsecase,
       _createLogAttachmentUsecase = createLogAttachmentUsecase,
       _exchangeNotificationUsecase = exchangeNotificationUsecase,
       _pickImageAttachmentsUsecase = pickImageAttachmentsUsecase,
       _shareAttachmentUsecase = shareAttachmentUsecase,
       super(const ExchangeSupportChatState()) {
    _notificationSubscription = _exchangeNotificationUsecase.messageStream
        .where((message) => message.type == 'message')
        .listen((_) => loadMessages(page: 1));
  }

  final GetSupportChatMessagesUsecase _getMessagesUsecase;
  final SendSupportChatMessageUsecase _sendMessageUsecase;
  final GetExchangeUserSummaryUsecase _getUserSummaryUsecase;
  final CreateLogAttachmentUsecase _createLogAttachmentUsecase;
  final ExchangeNotificationUsecase _exchangeNotificationUsecase;
  final PickImageAttachmentsUsecase _pickImageAttachmentsUsecase;
  final ShareAttachmentUsecase _shareAttachmentUsecase;
  StreamSubscription<NotificationMessage>? _notificationSubscription;

  bool _limitFetchingOlderMessages = false;

  Future<void> loadMessages({int? page}) async {
    try {
      emit(state.copyWith(loadingMessages: true, errorLoadingMessages: ''));

      if (state.userId == null) {
        try {
          final userSummary = await _getUserSummaryUsecase.execute();
          final userId = userSummary.userId;
          if (userId == null) {
            throw Exception('User ID not found in user summary');
          }
          emit(state.copyWith(userId: userId));
        } catch (_) {}
      }

      final pageToLoad = page ?? 1;
      final messages = await _getMessagesUsecase.execute(
        page: pageToLoad,
        pageSize: 10,
      );

      final updatedMessages = pageToLoad == 1
          ? messages
          : [...state.messages, ...messages];

      emit(
        state.copyWith(
          messages: updatedMessages,
          loadingMessages: false,
          currentPage: pageToLoad,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          loadingMessages: false,
          errorLoadingMessages: e.toString(),
        ),
      );
    }
  }

  Future<void> loadOlderMessages() async {
    if (state.loadingOlderMessages || _limitFetchingOlderMessages) {
      return;
    }

    _limitFetchingOlderMessages = true;
    final nextPage = state.currentPage + 1;
    emit(state.copyWith(loadingOlderMessages: true));

    try {
      final messages = await _getMessagesUsecase.execute(
        page: nextPage,
        pageSize: 10,
      );

      if (messages.isEmpty) {
        emit(state.copyWith(loadingOlderMessages: false));
        return;
      }

      emit(
        state.copyWith(
          messages: [...state.messages, ...messages],
          loadingOlderMessages: false,
          currentPage: nextPage,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loadingOlderMessages: false));
    } finally {
      Future.delayed(const Duration(milliseconds: 500), () {
        _limitFetchingOlderMessages = false;
      });
    }
  }

  void updateMessageText(String text) {
    emit(state.copyWith(newMessageText: text));
  }

  static const String errorMessageEmpty =
      'EXCHANGE_SUPPORT_CHAT_MESSAGE_EMPTY_ERROR';

  Future<void> addAttachment() async {
    emit(state.copyWith(errorPermissionDenied: ''));

    final result = await _pickImageAttachmentsUsecase.execute();

    if (result.hasError) {
      final errorMessage = switch (result.error!) {
        PickImageError.permissionDenied => 'Permission denied.',
        PickImageError.permissionPermanentlyDenied =>
          'Permission denied. Please grant photo library access in Settings.',
        PickImageError.pickFailed => 'Failed to pick files. Please try again.',
      };
      emit(state.copyWith(errorPermissionDenied: errorMessage));
      return;
    }

    if (result.attachments.isEmpty) return;

    emit(
      state.copyWith(
        newMessageAttachments: [
          ...state.newMessageAttachments,
          ...result.attachments,
        ],
      ),
    );
  }

  void removeAttachment(String attachmentId) {
    emit(
      state.copyWith(
        newMessageAttachments: state.newMessageAttachments
            .where((att) => att.attachmentId != attachmentId)
            .toList(),
      ),
    );
  }

  Future<void> attachLogs() async {
    try {
      emit(state.copyWith(errorPermissionDenied: ''));

      final attachment = await _createLogAttachmentUsecase.execute();

      emit(
        state.copyWith(
          newMessageText: 'Here are my logs',
          newMessageAttachments: [...state.newMessageAttachments, attachment],
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          errorPermissionDenied: 'Failed to attach logs. Please try again.',
        ),
      );
    }
  }

  Future<void> downloadAttachment(String attachmentId) async {
    try {
      emit(
        state.copyWith(
          loadingAttachmentId: attachmentId,
          errorLoadingAttachment: '',
        ),
      );

      await _shareAttachmentUsecase.execute(attachmentId);

      emit(state.copyWith(loadingAttachmentId: null));
    } catch (e) {
      emit(
        state.copyWith(
          loadingAttachmentId: null,
          errorLoadingAttachment: e.toString(),
        ),
      );
    }
  }

  Future<void> sendMessage() async {
    final messageText = state.newMessageText.trim();
    final attachmentsToSend = List<SupportChatMessageAttachment>.from(
      state.newMessageAttachments,
    );
    final hasAttachments = attachmentsToSend.isNotEmpty;

    if (messageText.isEmpty) {
      emit(state.copyWith(errorSendingMessage: errorMessageEmpty));
      return;
    }

    try {
      emit(state.copyWith(sendingMessage: true, errorSendingMessage: ''));

      final tempMessage = SupportChatMessage(
        messageId: 'temp_${DateTime.now().millisecondsSinceEpoch}',
        text: messageText.isEmpty ? null : messageText,
        fromUserId: state.userId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isAdmin: false,
        attachments: attachmentsToSend,
      );

      emit(
        state.copyWith(
          messages: [tempMessage, ...state.messages],
          newMessageText: '',
          newMessageAttachments: [],
        ),
      );

      await _sendMessageUsecase.execute(
        text: messageText,
        attachments: hasAttachments ? attachmentsToSend : null,
      );

      // Don't immediately reload - let the message appear naturally
      // The attachment might not be fully processed on the server yet
      await Future.delayed(const Duration(seconds: 2));
      await loadMessages(page: 1);

      emit(state.copyWith(sendingMessage: false));
    } catch (e) {
      emit(
        state.copyWith(
          sendingMessage: false,
          errorSendingMessage: e.toString(),
          newMessageText: messageText,
          newMessageAttachments: attachmentsToSend,
          messages: state.messages
              .where((msg) => !msg.messageId!.startsWith('temp'))
              .toList(),
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _notificationSubscription?.cancel();
    return super.close();
  }
}
