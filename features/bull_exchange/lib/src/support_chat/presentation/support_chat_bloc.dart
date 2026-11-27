import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/support_chat_state.dart';
import '../domain/support_chat_event.dart';
import '../domain/support_chat_effect.dart';
import '../domain/usecases/create_log_attachment_usecase.dart';
import '../domain/usecases/get_support_chat_messages_usecase.dart';
import '../domain/usecases/open_support_chat_attachment_usecase.dart';
import '../domain/usecases/pick_image_attachments_usecase.dart';
import '../domain/usecases/send_support_chat_message_usecase.dart';
import '../domain/usecases/watch_support_chat_pushes_usecase.dart';

/// Shell of [SupportChatState.next]. Effect results arriving after close are
/// dropped (CHAT-1).
class SupportChatBloc extends Bloc<SupportChatEvent, SupportChatState> {
  SupportChatBloc({
    required ExchangeSession? session,
    required GetSupportChatMessagesUsecase getMessages,
    required SendSupportChatMessageUsecase sendMessage,
    required PickImageAttachmentsUsecase pickImages,
    required CreateLogAttachmentUsecase createLogAttachment,
    required OpenSupportChatAttachmentUsecase openAttachment,
    required WatchSupportChatPushesUsecase watchPushes,
    required void Function() onNewestShown,
    String? draft,
  }) : this._(
         supportChatStart(draft: draft),
         session,
         getMessages,
         sendMessage,
         pickImages,
         createLogAttachment,
         openAttachment,
         watchPushes,
         onNewestShown,
       );

  SupportChatBloc._(
    SupportChatNext start,
    this._session,
    this._getMessages,
    this._sendMessage,
    this._pickImages,
    this._createLogAttachment,
    this._openAttachment,
    WatchSupportChatPushesUsecase watchPushes,
    this._onNewestShown,
  ) : super(start.state) {
    on<SupportChatEvent>(_onEvent, transformer: sequential());
    _pushes = watchPushes.execute().listen((_) {
      if (!isClosed) add(const ChatPushed());
    });
    _run(start.effects);
  }

  /// The session the chat opened with; its calls answer for it only.
  final ExchangeSession? _session;
  final GetSupportChatMessagesUsecase _getMessages;
  final SendSupportChatMessageUsecase _sendMessage;
  final PickImageAttachmentsUsecase _pickImages;
  final CreateLogAttachmentUsecase _createLogAttachment;
  final OpenSupportChatAttachmentUsecase _openAttachment;

  /// Tells the owner of the unread count that the user saw every message.
  final void Function() _onNewestShown;
  late final StreamSubscription<NotificationMessage> _pushes;

  void _onEvent(SupportChatEvent event, Emitter<SupportChatState> emit) {
    final next = state.next(event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<SupportChatEffect> effects) {
    for (final effect in effects) {
      unawaited(
        _answer(effect).then((event) {
          if (event != null && !isClosed) add(event);
        }),
      );
    }
  }

  /// Runs [effect]; its answer, if it has one, is the next event.
  Future<SupportChatEvent?> _answer(SupportChatEffect effect) async =>
      switch (effect) {
        ChatFetchPage(:final ticket, :final page) => ChatPageLoaded(
          ticket,
          await _getMessages.execute(
            _session,
            page: page,
            pageSize: supportChatPageSize,
          ),
        ),
        ChatNewestShown() => _told(_onNewestShown),
        ChatPickImages() => ChatAttachmentsPicked(await _pickImages.execute()),
        ChatBuildLogs() => ChatLogsBuilt(await _createLogAttachment.execute()),
        ChatSend(:final localId, :final text, :final attachments) =>
          ChatSendAnswered(
            localId,
            await _sendMessage.execute(
              _session,
              text: text,
              attachments: attachments,
            ),
          ),
        ChatOpenAttachment(:final attachmentId) => ChatOpenFinished(
          attachmentId,
          await _openAttachment.execute(_session, attachmentId),
        ),
      };

  /// An effect with no answer.
  SupportChatEvent? _told(void Function() tell) {
    tell();
    return null;
  }

  @override
  Future<void> close() async {
    await _pushes.cancel();
    return super.close();
  }
}
