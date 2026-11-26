import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart' show StepNext;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'exchange_support_chat_failure.dart';

/// Messages per page the thread asks for. A shorter page is the start of
/// the thread.
const supportChatPageSize = 10;

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    a.length == b.length && a.containsAll(b);

/// The key a message is merged by. A message without an id (CHAT-7) is
/// keyed by what it says and when.
String supportChatMessageKey(SupportChatMessage message) =>
    message.messageId ??
    'anon:${message.createdAt?.toIso8601String()}:${message.text}';

/// A refresh of the newest page. Pushes during a refresh ask for one more.
@immutable
sealed class ChatRefresh {
  const ChatRefresh();
}

final class ChatRefreshIdle extends ChatRefresh {
  const ChatRefreshIdle();

  @override
  bool operator ==(Object other) => other is ChatRefreshIdle;

  @override
  int get hashCode => (ChatRefreshIdle).hashCode;
}

final class ChatRefreshing extends ChatRefresh {
  final int ticket;

  /// A push arrived while this refresh ran: refresh once more after it.
  final bool again;

  const ChatRefreshing(this.ticket, {this.again = false});

  @override
  bool operator ==(Object other) =>
      other is ChatRefreshing && other.ticket == ticket && other.again == again;

  @override
  int get hashCode => Object.hash(ChatRefreshing, ticket, again);
}

@immutable
sealed class ChatOlder {
  const ChatOlder();
}

final class ChatOlderIdle extends ChatOlder {
  const ChatOlderIdle();

  @override
  bool operator ==(Object other) => other is ChatOlderIdle;

  @override
  int get hashCode => (ChatOlderIdle).hashCode;
}

final class ChatOlderLoading extends ChatOlder {
  final int ticket;
  final int page;

  const ChatOlderLoading(this.ticket, this.page);

  @override
  bool operator ==(Object other) =>
      other is ChatOlderLoading && other.ticket == ticket && other.page == page;

  @override
  int get hashCode => Object.hash(ChatOlderLoading, ticket, page);
}

/// The thread (CHAT-2..5, CHAT-10).
@immutable
sealed class ChatThread {
  const ChatThread();
}

final class ChatThreadLoading extends ChatThread {
  final int ticket;

  const ChatThreadLoading(this.ticket);

  @override
  bool operator ==(Object other) =>
      other is ChatThreadLoading && other.ticket == ticket;

  @override
  int get hashCode => Object.hash(ChatThreadLoading, ticket);
}

/// The first page failed: shown with Retry, never as an empty thread.
final class ChatThreadLoadFailed extends ChatThread {
  final ExchangeSupportChatFailure failure;

  const ChatThreadLoadFailed(this.failure);

  @override
  bool operator ==(Object other) =>
      other is ChatThreadLoadFailed && other.failure == failure;

  @override
  int get hashCode => Object.hash(ChatThreadLoadFailed, failure);
}

/// [messages] newest first, one per key; [nextPage] is null once the start
/// of the thread was read.
final class ChatThreadLoaded extends ChatThread {
  final List<SupportChatMessage> messages;
  final int? nextPage;
  final ChatRefresh refresh;
  final ChatOlder older;

  const ChatThreadLoaded(
    this.messages, {
    required this.nextPage,
    this.refresh = const ChatRefreshIdle(),
    this.older = const ChatOlderIdle(),
  });

  bool get startReached => nextPage == null;

  ChatThreadLoaded copyWith({
    List<SupportChatMessage>? messages,
    ChatRefresh? refresh,
    ChatOlder? older,
  }) => ChatThreadLoaded(
    messages ?? this.messages,
    nextPage: nextPage,
    refresh: refresh ?? this.refresh,
    older: older ?? this.older,
  );

  @override
  bool operator ==(Object other) =>
      other is ChatThreadLoaded &&
      _listEquals(other.messages, messages) &&
      other.nextPage == nextPage &&
      other.refresh == refresh &&
      other.older == older;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(messages), nextPage, refresh, older);
}

/// What the composer is waiting for.
@immutable
sealed class ChatAttaching {
  const ChatAttaching();
}

final class ChatAttachIdle extends ChatAttaching {
  const ChatAttachIdle();

  @override
  bool operator ==(Object other) => other is ChatAttachIdle;

  @override
  int get hashCode => (ChatAttachIdle).hashCode;
}

final class ChatAttachPicking extends ChatAttaching {
  const ChatAttachPicking();

  @override
  bool operator ==(Object other) => other is ChatAttachPicking;

  @override
  int get hashCode => (ChatAttachPicking).hashCode;
}

/// Building the log file; [line] is appended to the draft when it is
/// attached (CHAT-8).
final class ChatAttachBuildingLogs extends ChatAttaching {
  final String line;

  const ChatAttachBuildingLogs(this.line);

  @override
  bool operator ==(Object other) =>
      other is ChatAttachBuildingLogs && other.line == line;

  @override
  int get hashCode => Object.hash(ChatAttachBuildingLogs, line);
}

@immutable
final class ChatComposer {
  final String text;
  final List<SupportChatMessageAttachment> attachments;
  final ChatAttaching attaching;
  final ExchangeSupportChatFailure? problem;

  const ChatComposer({
    this.text = '',
    this.attachments = const [],
    this.attaching = const ChatAttachIdle(),
    this.problem,
  });

  ChatComposer copyWith({
    String? text,
    List<SupportChatMessageAttachment>? attachments,
    ChatAttaching? attaching,
    ExchangeSupportChatFailure? Function()? problem,
  }) => ChatComposer(
    text: text ?? this.text,
    attachments: attachments ?? this.attachments,
    attaching: attaching ?? this.attaching,
    problem: problem == null ? this.problem : problem(),
  );

  @override
  bool operator ==(Object other) =>
      other is ChatComposer &&
      other.text == text &&
      _listEquals(other.attachments, attachments) &&
      other.attaching == attaching &&
      other.problem == problem;

  @override
  int get hashCode =>
      Object.hash(text, Object.hashAll(attachments), attaching, problem);
}

/// A message the user sent from this screen (CHAT-6). It leaves the list
/// when the thread shows it.
@immutable
sealed class ChatOutgoing {
  final String localId;
  final String text;
  final List<SupportChatMessageAttachment> attachments;

  const ChatOutgoing(this.localId, this.text, this.attachments);

  @override
  bool operator ==(Object other) =>
      other is ChatOutgoing &&
      other.runtimeType == runtimeType &&
      other.localId == localId &&
      other.text == text &&
      _listEquals(other.attachments, attachments);

  @override
  int get hashCode =>
      Object.hash(runtimeType, localId, text, Object.hashAll(attachments));
}

final class ChatOutgoingSending extends ChatOutgoing {
  const ChatOutgoingSending(super.localId, super.text, super.attachments);
}

/// The exchange accepted it; the thread has not shown it yet.
final class ChatOutgoingSent extends ChatOutgoing {
  const ChatOutgoingSent(super.localId, super.text, super.attachments);
}

/// A failure shown once (snackbar); [id] tells a repeat from the same one.
@immutable
final class ChatNotice {
  final int id;
  final ExchangeSupportChatFailure failure;

  const ChatNotice(this.id, this.failure);

  @override
  bool operator ==(Object other) =>
      other is ChatNotice && other.id == id && other.failure == failure;

  @override
  int get hashCode => Object.hash(ChatNotice, id, failure);
}

/// The support chat: the thread, the composer, the messages being sent and
/// the attachments being opened (one entry each, CHAT-9).
@immutable
final class SupportChatState {
  final ChatThread thread;
  final ChatComposer composer;
  final List<ChatOutgoing> outgoing;
  final Set<String> opening;
  final ChatNotice? notice;
  final int tickets;

  const SupportChatState({
    required this.thread,
    this.composer = const ChatComposer(),
    this.outgoing = const [],
    this.opening = const {},
    this.notice,
    required this.tickets,
  });

  SupportChatState copyWith({
    ChatThread? thread,
    ChatComposer? composer,
    List<ChatOutgoing>? outgoing,
    Set<String>? opening,
    ChatNotice? notice,
    int? tickets,
  }) => SupportChatState(
    thread: thread ?? this.thread,
    composer: composer ?? this.composer,
    outgoing: outgoing ?? this.outgoing,
    opening: opening ?? this.opening,
    notice: notice ?? this.notice,
    tickets: tickets ?? this.tickets,
  );

  @override
  bool operator ==(Object other) =>
      other is SupportChatState &&
      other.thread == thread &&
      other.composer == composer &&
      _listEquals(other.outgoing, outgoing) &&
      _setEquals(other.opening, opening) &&
      other.notice == notice &&
      other.tickets == tickets;

  @override
  int get hashCode => Object.hash(
    thread,
    composer,
    Object.hashAll(outgoing),
    Object.hashAllUnordered(opening),
    notice,
    tickets,
  );
}

@immutable
sealed class SupportChatEvent {
  const SupportChatEvent();
}

/// The answer for the page a fetch with [ticket] asked for.
final class ChatPageLoaded extends SupportChatEvent {
  final int ticket;
  final Result<List<SupportChatMessage>, ExchangeSupportChatFailure> result;

  const ChatPageLoaded(this.ticket, this.result);
}

final class ChatRetryPressed extends SupportChatEvent {
  const ChatRetryPressed();
}

/// The exchange pushed a chat notification.
final class ChatPushed extends SupportChatEvent {
  const ChatPushed();
}

final class ChatOlderRequested extends SupportChatEvent {
  const ChatOlderRequested();
}

final class ChatDraftChanged extends SupportChatEvent {
  final String text;

  const ChatDraftChanged(this.text);
}

final class ChatAttachPressed extends SupportChatEvent {
  const ChatAttachPressed();
}

final class ChatAttachmentsPicked extends SupportChatEvent {
  final Result<List<SupportChatMessageAttachment>, ExchangeSupportChatFailure>
  result;

  const ChatAttachmentsPicked(this.result);
}

/// [line] is the localized sentence added to the draft with the logs.
final class ChatLogsPressed extends SupportChatEvent {
  final String line;

  const ChatLogsPressed(this.line);
}

final class ChatLogsBuilt extends SupportChatEvent {
  final Result<SupportChatMessageAttachment, ExchangeSupportChatFailure> result;

  const ChatLogsBuilt(this.result);
}

final class ChatAttachmentRemoved extends SupportChatEvent {
  final SupportChatMessageAttachment attachment;

  const ChatAttachmentRemoved(this.attachment);
}

final class ChatSendPressed extends SupportChatEvent {
  const ChatSendPressed();
}

final class ChatSendAnswered extends SupportChatEvent {
  final String localId;
  final Result<void, ExchangeSupportChatFailure> result;

  const ChatSendAnswered(this.localId, this.result);
}

final class ChatOpenPressed extends SupportChatEvent {
  final String attachmentId;

  const ChatOpenPressed(this.attachmentId);
}

final class ChatOpenFinished extends SupportChatEvent {
  final String attachmentId;
  final Result<void, ExchangeSupportChatFailure> result;

  const ChatOpenFinished(this.attachmentId, this.result);
}

@immutable
sealed class SupportChatEffect {
  const SupportChatEffect();
}

final class ChatFetchPage extends SupportChatEffect {
  final int ticket;
  final int page;

  const ChatFetchPage(this.ticket, this.page);

  @override
  bool operator ==(Object other) =>
      other is ChatFetchPage && other.ticket == ticket && other.page == page;

  @override
  int get hashCode => Object.hash(ChatFetchPage, ticket, page);
}

/// The newest page is on screen: the user has seen every message.
final class ChatNewestShown extends SupportChatEffect {
  const ChatNewestShown();

  @override
  bool operator ==(Object other) => other is ChatNewestShown;

  @override
  int get hashCode => (ChatNewestShown).hashCode;
}

final class ChatPickImages extends SupportChatEffect {
  const ChatPickImages();

  @override
  bool operator ==(Object other) => other is ChatPickImages;

  @override
  int get hashCode => (ChatPickImages).hashCode;
}

final class ChatBuildLogs extends SupportChatEffect {
  const ChatBuildLogs();

  @override
  bool operator ==(Object other) => other is ChatBuildLogs;

  @override
  int get hashCode => (ChatBuildLogs).hashCode;
}

final class ChatSend extends SupportChatEffect {
  final String localId;
  final String text;
  final List<SupportChatMessageAttachment> attachments;

  const ChatSend(this.localId, this.text, this.attachments);

  @override
  bool operator ==(Object other) =>
      other is ChatSend &&
      other.localId == localId &&
      other.text == text &&
      _listEquals(other.attachments, attachments);

  @override
  int get hashCode =>
      Object.hash(ChatSend, localId, text, Object.hashAll(attachments));
}

final class ChatOpenAttachment extends SupportChatEffect {
  final String attachmentId;

  const ChatOpenAttachment(this.attachmentId);

  @override
  bool operator ==(Object other) =>
      other is ChatOpenAttachment && other.attachmentId == attachmentId;

  @override
  int get hashCode => Object.hash(ChatOpenAttachment, attachmentId);
}

typedef SupportChatNext = StepNext<SupportChatState, SupportChatEffect>;

SupportChatNext supportChatStart({String? draft}) => StepNext(
  SupportChatState(
    thread: const ChatThreadLoading(1),
    composer: ChatComposer(text: draft ?? ''),
    tickets: 1,
  ),
  const [ChatFetchPage(1, 1)],
);

SupportChatNext transitionSupportChat(
  SupportChatState state,
  SupportChatEvent event,
) => switch ((state.thread, event)) {
  (final ChatThreadLoading loading, ChatPageLoaded loaded)
      when loaded.ticket == loading.ticket =>
    switch (loaded.result) {
      Ok(:final value) => StepNext(
        _withThread(
          state,
          ChatThreadLoaded(
            const [],
            nextPage: value.length < supportChatPageSize ? null : 2,
          ),
          value,
        ),
        const [ChatNewestShown()],
      ),
      Err(:final failure) => StepNext(
        state.copyWith(thread: ChatThreadLoadFailed(failure)),
      ),
    },
  (final ChatThreadLoaded thread, ChatPageLoaded loaded) => _pageLoaded(
    state,
    thread,
    loaded,
  ),
  (ChatThreadLoading() || ChatThreadLoadFailed(), ChatPageLoaded()) =>
    StepNext.stay(state),
  (ChatThreadLoadFailed(), ChatRetryPressed()) => StepNext(
    state.copyWith(
      thread: ChatThreadLoading(state.tickets + 1),
      tickets: state.tickets + 1,
    ),
    [ChatFetchPage(state.tickets + 1, 1)],
  ),
  (ChatThreadLoading() || ChatThreadLoaded(), ChatRetryPressed()) =>
    StepNext.stay(state),
  (final ChatThreadLoaded thread, ChatPushed()) => _refresh(state, thread),
  (ChatThreadLoading() || ChatThreadLoadFailed(), ChatPushed()) =>
    StepNext.stay(state),
  (
    final ChatThreadLoaded thread &&
        ChatThreadLoaded(:final nextPage?, older: ChatOlderIdle()),
    ChatOlderRequested(),
  ) =>
    StepNext(
      state.copyWith(
        thread: thread.copyWith(
          older: ChatOlderLoading(state.tickets + 1, nextPage),
        ),
        tickets: state.tickets + 1,
      ),
      [ChatFetchPage(state.tickets + 1, nextPage)],
    ),
  (
    ChatThreadLoading() || ChatThreadLoadFailed() || ChatThreadLoaded(),
    ChatOlderRequested(),
  ) =>
    StepNext.stay(state),
  (
    ChatThreadLoading() || ChatThreadLoadFailed() || ChatThreadLoaded(),
    final SupportChatEvent event,
  ) =>
    _composerEvent(state, event),
};

SupportChatNext _composerEvent(SupportChatState state, SupportChatEvent event) {
  final composer = state.composer;
  switch (event) {
    case ChatPageLoaded() ||
        ChatRetryPressed() ||
        ChatPushed() ||
        ChatOlderRequested():
      return StepNext.stay(state);
    case ChatDraftChanged(:final text):
      return StepNext(
        state.copyWith(
          composer: composer.copyWith(text: text, problem: () => null),
        ),
      );
    case ChatAttachPressed():
      return switch (composer.attaching) {
        ChatAttachIdle() => StepNext(
          state.copyWith(
            composer: composer.copyWith(attaching: const ChatAttachPicking()),
          ),
          const [ChatPickImages()],
        ),
        ChatAttachPicking() || ChatAttachBuildingLogs() => StepNext.stay(state),
      };
    case ChatAttachmentsPicked(:final result):
      return switch ((composer.attaching, result)) {
        (ChatAttachPicking(), Ok(:final value)) => StepNext(
          state.copyWith(
            composer: composer.copyWith(
              attaching: const ChatAttachIdle(),
              attachments: [...composer.attachments, ...value],
            ),
          ),
        ),
        (ChatAttachPicking(), Err(:final failure)) => StepNext(
          _notify(
            state.copyWith(
              composer: composer.copyWith(attaching: const ChatAttachIdle()),
            ),
            failure,
          ),
        ),
        (ChatAttachIdle() || ChatAttachBuildingLogs(), Ok() || Err()) =>
          StepNext.stay(state),
      };
    case ChatLogsPressed(:final line):
      return switch (composer.attaching) {
        ChatAttachIdle() => StepNext(
          state.copyWith(
            composer: composer.copyWith(
              attaching: ChatAttachBuildingLogs(line),
            ),
          ),
          const [ChatBuildLogs()],
        ),
        ChatAttachPicking() || ChatAttachBuildingLogs() => StepNext.stay(state),
      };
    case ChatLogsBuilt(:final result):
      return switch ((composer.attaching, result)) {
        (ChatAttachBuildingLogs(:final line), Ok(:final value)) => StepNext(
          state.copyWith(
            composer: composer.copyWith(
              attaching: const ChatAttachIdle(),
              attachments: [...composer.attachments, value],
              text: _withLine(composer.text, line),
              problem: () => null,
            ),
          ),
        ),
        (ChatAttachBuildingLogs(), Err(:final failure)) => StepNext(
          _notify(
            state.copyWith(
              composer: composer.copyWith(attaching: const ChatAttachIdle()),
            ),
            failure,
          ),
        ),
        (ChatAttachIdle() || ChatAttachPicking(), Ok() || Err()) =>
          StepNext.stay(state),
      };
    case ChatAttachmentRemoved(:final attachment):
      if (!composer.attachments.contains(attachment)) {
        return StepNext.stay(state);
      }
      return StepNext(
        state.copyWith(
          composer: composer.copyWith(
            attachments: [
              for (final a in composer.attachments)
                if (a != attachment) a,
            ],
          ),
        ),
      );
    case ChatSendPressed():
      final text = composer.text.trim();
      if (text.isEmpty) {
        if (state.outgoing.any((o) => o is ChatOutgoingSending) ||
            composer.problem is MessageEmptyFailure) {
          return StepNext.stay(state);
        }
        return StepNext(
          state.copyWith(
            composer: composer.copyWith(
              problem: () => const MessageEmptyFailure(),
            ),
          ),
        );
      }
      final ticket = state.tickets + 1;
      final localId = 'local-$ticket';
      return StepNext(
        state.copyWith(
          composer: ChatComposer(attaching: composer.attaching),
          outgoing: [
            ...state.outgoing,
            ChatOutgoingSending(localId, text, composer.attachments),
          ],
          tickets: ticket,
        ),
        [ChatSend(localId, text, composer.attachments)],
      );
    case ChatSendAnswered(:final localId, :final result):
      final sending = state.outgoing
          .whereType<ChatOutgoingSending>()
          .where((o) => o.localId == localId)
          .firstOrNull;
      if (sending == null) return StepNext.stay(state);
      switch (result) {
        case Ok():
          final sent = state.copyWith(
            outgoing: [
              for (final o in state.outgoing)
                o == sending
                    ? ChatOutgoingSent(o.localId, o.text, o.attachments)
                    : o,
            ],
          );
          return switch (sent.thread) {
            final ChatThreadLoaded thread => _refresh(sent, thread),
            ChatThreadLoading() || ChatThreadLoadFailed() => StepNext(sent),
          };
        case Err(:final failure):
          return StepNext(
            state.copyWith(
              outgoing: [
                for (final o in state.outgoing)
                  if (o != sending) o,
              ],
              composer: composer.copyWith(
                text: composer.text.trim().isEmpty
                    ? sending.text
                    : composer.text,
                attachments: [...sending.attachments, ...composer.attachments],
                problem: () => failure,
              ),
            ),
          );
      }
    case ChatOpenPressed(:final attachmentId):
      if (state.opening.contains(attachmentId)) return StepNext.stay(state);
      return StepNext(
        state.copyWith(opening: {...state.opening, attachmentId}),
        [ChatOpenAttachment(attachmentId)],
      );
    case ChatOpenFinished(:final attachmentId, :final result):
      if (!state.opening.contains(attachmentId)) return StepNext.stay(state);
      final done = state.copyWith(
        opening: {...state.opening}..remove(attachmentId),
      );
      return StepNext(switch (result) {
        Ok() => done,
        Err(:final failure) => _notify(done, failure),
      });
  }
}

SupportChatNext _pageLoaded(
  SupportChatState state,
  ChatThreadLoaded thread,
  ChatPageLoaded loaded,
) {
  final refresh = thread.refresh;
  if (refresh case ChatRefreshing(:final ticket, :final again)
      when ticket == loaded.ticket) {
    switch (loaded.result) {
      case Ok(:final value):
        final merged = _withThread(
          state,
          thread.copyWith(refresh: const ChatRefreshIdle()),
          value,
        );
        if (!again) return StepNext(merged, const [ChatNewestShown()]);
        final next = _refresh(merged, merged.thread as ChatThreadLoaded);
        return StepNext(next.state, [const ChatNewestShown(), ...next.effects]);
      case Err(:final failure):
        final idle = state.copyWith(
          thread: thread.copyWith(refresh: const ChatRefreshIdle()),
        );
        return again
            ? _refresh(idle, idle.thread as ChatThreadLoaded)
            : StepNext(_notify(idle, failure));
    }
  }
  final older = thread.older;
  if (older case ChatOlderLoading(:final ticket, :final page)
      when ticket == loaded.ticket) {
    switch (loaded.result) {
      case Ok(:final value):
        final next = ChatThreadLoaded(
          thread.messages,
          nextPage: value.length < supportChatPageSize ? null : page + 1,
          refresh: thread.refresh,
        );
        return StepNext(_withThread(state, next, value));
      case Err():
        // Not shown: the thread on screen stays usable and the user can ask
        // for older messages again.
        return StepNext(
          state.copyWith(thread: thread.copyWith(older: const ChatOlderIdle())),
        );
    }
  }
  return StepNext.stay(state);
}

SupportChatNext _refresh(SupportChatState state, ChatThreadLoaded thread) =>
    switch (thread.refresh) {
      ChatRefreshIdle() => StepNext(
        state.copyWith(
          thread: thread.copyWith(refresh: ChatRefreshing(state.tickets + 1)),
          tickets: state.tickets + 1,
        ),
        [ChatFetchPage(state.tickets + 1, 1)],
      ),
      ChatRefreshing(:final ticket, again: false) => StepNext(
        state.copyWith(
          thread: thread.copyWith(refresh: ChatRefreshing(ticket, again: true)),
        ),
      ),
      ChatRefreshing(again: true) => StepNext.stay(state),
    };

/// Merges [page] into [thread] by key (CHAT-2, CHAT-3) and drops the sent
/// messages the page shows for the first time (CHAT-6).
SupportChatState _withThread(
  SupportChatState state,
  ChatThreadLoaded thread,
  List<SupportChatMessage> page,
) {
  final byKey = <String, SupportChatMessage>{
    for (final m in thread.messages) supportChatMessageKey(m): m,
  };
  final fresh = <SupportChatMessage>[];
  for (final message in page) {
    final key = supportChatMessageKey(message);
    if (!byKey.containsKey(key)) fresh.add(message);
    byKey[key] = message;
  }
  final messages = byKey.values.toList()
    ..sort((a, b) {
      final at = a.createdAt;
      final bt = b.createdAt;
      if (at == null && bt == null) return 0;
      if (at == null) return 1;
      if (bt == null) return -1;
      return bt.compareTo(at);
    });
  final outgoing = [...state.outgoing];
  for (final message in fresh) {
    if (message.isAdmin != false) continue;
    final index = outgoing.indexWhere(
      (o) => o is ChatOutgoingSent && o.text == message.text?.trim(),
    );
    if (index >= 0) outgoing.removeAt(index);
  }
  return state.copyWith(
    thread: ChatThreadLoaded(
      messages,
      nextPage: thread.nextPage,
      refresh: thread.refresh,
      older: thread.older,
    ),
    outgoing: outgoing,
  );
}

SupportChatState _notify(
  SupportChatState state,
  ExchangeSupportChatFailure failure,
) => state.copyWith(notice: ChatNotice((state.notice?.id ?? 0) + 1, failure));

String _withLine(String text, String line) {
  if (text.contains(line)) return text;
  if (text.trim().isEmpty) return line;
  return '$text\n$line';
}
