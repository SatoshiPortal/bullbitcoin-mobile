import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_support_chat_state.freezed.dart';

@freezed
abstract class ExchangeSupportChatState with _$ExchangeSupportChatState {
  const factory ExchangeSupportChatState({
    @Default([]) List<SupportChatMessage> messages,
    @Default(false) bool loadingMessages,
    @Default(false) bool sendingMessage,
    @Default('') String newMessageText,
    @Default([]) List<SupportChatMessageAttachment> newMessageAttachments,
    @Default(1) int currentPage,
    @Default(false) bool loadingOlderMessages,
    String? loadingAttachmentId,
    // Transient failures surfaced via snackbar (load / attachment / permission
    // / picker / logs). Typed — the UI translates it, never reads raw text.
    ExchangeSupportChatFailure? failure,
    // Failure shown inline next to the message input (send / empty message).
    ExchangeSupportChatFailure? sendMessageFailure,
    String? userId,
  }) = _ExchangeSupportChatState;
}
