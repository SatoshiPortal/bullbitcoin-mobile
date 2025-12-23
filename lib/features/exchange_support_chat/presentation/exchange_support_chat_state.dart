import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exchange_support_chat_state.freezed.dart';

@freezed
abstract class ExchangeSupportChatState with _$ExchangeSupportChatState {
  const factory ExchangeSupportChatState({
    @Default([]) List<SupportChatMessage> messages,
    @Default(false) bool loadingMessages,
    @Default('') String errorLoadingMessages,
    @Default(false) bool sendingMessage,
    @Default('') String errorSendingMessage,
    @Default('') String newMessageText,
    @Default([]) List<SupportChatMessageAttachment> newMessageAttachments,
    @Default(1) int currentPage,
    @Default(false) bool loadingOlderMessages,
    String? loadingAttachmentId,
    @Default('') String errorLoadingAttachment,
    @Default('') String errorPermissionDenied,
    String? userId,
  }) = _ExchangeSupportChatState;
}
