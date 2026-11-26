import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

import '../domain/exchange_support_chat_failure.dart';
import 'support_chat_machine.dart';

/// What the chat's effects call.
typedef SupportChatEffects = ({
  Future<Result<List<SupportChatMessage>, ExchangeSupportChatFailure>> Function(
    int page,
  )
  fetchPage,
  Future<Result<void, ExchangeSupportChatFailure>> Function(
    String text,
    List<SupportChatMessageAttachment> attachments,
  )
  send,
  Future<Result<List<SupportChatMessageAttachment>, ExchangeSupportChatFailure>>
  Function()
  pickImages,
  Future<Result<SupportChatMessageAttachment, ExchangeSupportChatFailure>>
  Function()
  buildLogs,
  Future<Result<void, ExchangeSupportChatFailure>> Function(String attachmentId)
  openAttachment,

  /// Tells the owner of the unread count that the user saw every message.
  void Function() newestShown,
});

/// Runs [effect]; its answer, if it has one, is the next event.
Future<SupportChatEvent?> runSupportChatEffect(
  SupportChatEffect effect,
  SupportChatEffects effects,
) async => switch (effect) {
  ChatFetchPage(:final ticket, :final page) => ChatPageLoaded(
    ticket,
    await effects.fetchPage(page),
  ),
  ChatNewestShown() => _told(effects.newestShown),
  ChatPickImages() => ChatAttachmentsPicked(await effects.pickImages()),
  ChatBuildLogs() => ChatLogsBuilt(await effects.buildLogs()),
  ChatSend(:final localId, :final text, :final attachments) => ChatSendAnswered(
    localId,
    await effects.send(text, attachments),
  ),
  ChatOpenAttachment(:final attachmentId) => ChatOpenFinished(
    attachmentId,
    await effects.openAttachment(attachmentId),
  ),
};

/// An effect with no answer.
SupportChatEvent? _told(void Function() tell) {
  tell();
  return null;
}

/// Shell of [transitionSupportChat]. Effect results arriving after close are
/// dropped (CHAT-1).
class SupportChatBloc extends Bloc<SupportChatEvent, SupportChatState> {
  SupportChatBloc({
    required SupportChatEffects effects,
    required Stream<Result<NotificationMessage, ExchangeFailure>> notifications,
    String? draft,
  }) : this._(supportChatStart(draft: draft), effects, notifications);

  SupportChatBloc._(
    SupportChatNext start,
    this._effects,
    Stream<Result<NotificationMessage, ExchangeFailure>> notifications,
  ) : super(start.state) {
    on<SupportChatEvent>(_onEvent, transformer: sequential());
    _pushes = notifications
        .where(
          (event) => switch (event) {
            Ok(:final value) => value.kind == NotificationMessageKind.message,
            Err() => false,
          },
        )
        .listen((_) {
          if (!isClosed) add(const ChatPushed());
        });
    _run(start.effects);
  }

  final SupportChatEffects _effects;
  late final StreamSubscription<Result<NotificationMessage, ExchangeFailure>>
  _pushes;

  void _onEvent(SupportChatEvent event, Emitter<SupportChatState> emit) {
    final next = transitionSupportChat(state, event);
    if (identical(next.state, state)) return;
    emit(next.state);
    _run(next.effects);
  }

  void _run(List<SupportChatEffect> effects) {
    for (final effect in effects) {
      unawaited(
        runSupportChatEffect(effect, _effects).then((event) {
          if (event != null && !isClosed) add(event);
        }),
      );
    }
  }

  @override
  Future<void> close() async {
    await _pushes.cancel();
    return super.close();
  }
}
