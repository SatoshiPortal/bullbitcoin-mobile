import 'package:bull_exchange/src/support_chat/domain/support_chat_state.dart';
import 'package:bull_exchange/src/support_chat/domain/support_chat_event.dart';
import 'package:bull_exchange/src/support_chat/domain/support_chat_effect.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

final _m1 = SupportChatMessage(
  messageId: '1',
  text: 'welcome',
  isAdmin: true,
  createdAt: DateTime(2026, 1, 1),
);
final _m2 = SupportChatMessage(
  messageId: '2',
  text: 'old',
  isAdmin: false,
  createdAt: DateTime(2026, 1, 2),
);
final _m3 = SupportChatMessage(
  messageId: '3',
  text: 'hi',
  isAdmin: false,
  createdAt: DateTime(2026, 1, 3),
);
const _att = SupportChatMessageAttachment(attachmentId: 'p1', fileName: 'a');
const _logAtt = SupportChatMessageAttachment(
  attachmentId: 'temp_logs_1',
  fileName: 'x.BullLog.y.txt',
);
const _line = 'Here are my logs';
const _loadFailure = ExchangeChatLoadMessagesFailure();

SupportChatState _l({
  List<SupportChatMessage>? messages,
  int? nextPage = 2,
  ChatRefresh refresh = const ChatRefreshIdle(),
  ChatOlder older = const ChatOlderIdle(),
  ChatComposer composer = const ChatComposer(),
  List<ChatOutgoing> outgoing = const [],
  Set<String> opening = const {},
  ChatNotice? notice,
  int tickets = 3,
}) => SupportChatState(
  thread: ChatThreadLoaded(
    messages ?? [_m2, _m1],
    nextPage: nextPage,
    refresh: refresh,
    older: older,
  ),
  composer: composer,
  outgoing: outgoing,
  opening: opening,
  notice: notice,
  tickets: tickets,
);

final _states = <SupportChatState>[
  const SupportChatState(thread: ChatThreadLoading(1), tickets: 1), // 0
  const SupportChatState(
    thread: ChatThreadLoadFailed(_loadFailure),
    tickets: 1,
  ), // 1
  _l(), // 2
  _l(refresh: const ChatRefreshing(3)), // 3
  _l(refresh: const ChatRefreshQueued(3)), // 4
  _l(older: const ChatOlderLoading(3, 2)), // 5
  _l(nextPage: null), // 6
  _l(composer: const ChatComposer(text: 'hi')), // 7
  _l(composer: const ChatComposer(attaching: ChatAttachPicking())), // 8
  _l(
    composer: const ChatComposer(
      text: 'help',
      attaching: ChatAttachBuildingLogs(_line),
    ),
  ), // 9
  _l(outgoing: const [ChatOutgoingSending('local-3', 'hi', [])]), // 10
  _l(outgoing: const [ChatOutgoingSent('local-3', 'hi', [])]), // 11
  _l(opening: const {'a1'}), // 12
  _l(
    composer: const ChatComposer(text: 'hi', attachments: [_att]),
  ), // 13
];

/// Every state's composer with [text], for the draft row.
SupportChatState _typed(SupportChatState s, String text) => SupportChatState(
  thread: s.thread,
  composer: ChatComposer(
    text: text,
    attachments: s.composer.attachments,
    attaching: s.composer.attaching,
  ),
  outgoing: s.outgoing,
  opening: s.opening,
  notice: s.notice,
  tickets: s.tickets,
);

SupportChatState _composer(SupportChatState s, ChatComposer composer) =>
    SupportChatState(
      thread: s.thread,
      composer: composer,
      outgoing: s.outgoing,
      opening: s.opening,
      notice: s.notice,
      tickets: s.tickets,
    );

final _all = List.generate(_states.length, (i) => i);
final _attachIdle = [0, 1, 2, 3, 4, 5, 6, 7, 10, 11, 12, 13];

final _table = <String, (SupportChatEvent, Map<int, SupportChatState>)>{
  'first page': (
    ChatPageLoaded(1, Ok([_m2, _m1])),
    {
      0: SupportChatState(
        thread: ChatThreadLoaded([_m2, _m1], nextPage: null),
        tickets: 1,
      ),
    },
  ),
  'first page failed (CHAT-5)': (
    const ChatPageLoaded(1, Err(_loadFailure)),
    {
      0: const SupportChatState(
        thread: ChatThreadLoadFailed(_loadFailure),
        tickets: 1,
      ),
    },
  ),
  'page for ticket 3 (CHAT-2: merged, never replaced)': (
    ChatPageLoaded(3, Ok([_m3, _m2])),
    {
      3: _l(messages: [_m3, _m2, _m1]),
      4: _l(
        messages: [_m3, _m2, _m1],
        refresh: const ChatRefreshing(4),
        tickets: 4,
      ),
      5: _l(messages: [_m3, _m2, _m1], nextPage: null),
    },
  ),
  'page for ticket 3 failed': (
    const ChatPageLoaded(3, Err(_loadFailure)),
    {
      3: _l(notice: const ChatNotice(1, _loadFailure)),
      4: _l(refresh: const ChatRefreshing(4), tickets: 4),
      5: _l(),
    },
  ),
  'page, stale ticket (CHAT-4)': (ChatPageLoaded(9, Ok([_m3])), {}),
  'retry': (
    const ChatRetryPressed(),
    {1: const SupportChatState(thread: ChatThreadLoading(2), tickets: 2)},
  ),
  'pushed': (
    const ChatPushed(),
    {
      for (final i in [2, 6, 7, 8, 9, 10, 11, 12, 13])
        i: SupportChatState(
          thread: (_states[i].thread as ChatThreadLoaded).copyWith(
            refresh: const ChatRefreshing(4),
          ),
          composer: _states[i].composer,
          outgoing: _states[i].outgoing,
          opening: _states[i].opening,
          tickets: 4,
        ),
      3: _l(refresh: const ChatRefreshQueued(3)),
      5: _l(
        older: const ChatOlderLoading(3, 2),
        refresh: const ChatRefreshing(4),
        tickets: 4,
      ),
    },
  ),
  'older requested (CHAT-10)': (
    const ChatOlderRequested(),
    {
      for (final i in [2, 3, 4, 7, 8, 9, 10, 11, 12, 13])
        i: SupportChatState(
          thread: (_states[i].thread as ChatThreadLoaded).copyWith(
            older: const ChatOlderLoading(4, 2),
          ),
          composer: _states[i].composer,
          outgoing: _states[i].outgoing,
          opening: _states[i].opening,
          tickets: 4,
        ),
    },
  ),
  'draft changed': (
    const ChatDraftChanged('x'),
    {for (final i in _all) i: _typed(_states[i], 'x')},
  ),
  'attach pressed': (
    const ChatAttachPressed(),
    {
      for (final i in _attachIdle)
        i: _composer(
          _states[i],
          _states[i].composer.copyWith(attaching: const ChatAttachPicking()),
        ),
    },
  ),
  'attachments picked': (
    const ChatAttachmentsPicked(Ok([_att])),
    {
      8: _l(composer: const ChatComposer(attachments: [_att])),
    },
  ),
  'picking failed': (
    const ChatAttachmentsPicked(Err(ExchangeChatPickImagesFailure())),
    {8: _l(notice: const ChatNotice(1, ExchangeChatPickImagesFailure()))},
  ),
  'logs pressed': (
    const ChatLogsPressed(_line),
    {
      for (final i in _attachIdle)
        i: _composer(
          _states[i],
          _states[i].composer.copyWith(
            attaching: const ChatAttachBuildingLogs(_line),
          ),
        ),
    },
  ),
  'logs built (CHAT-8: the line is appended, nothing overwritten)': (
    const ChatLogsBuilt(Ok(_logAtt)),
    {
      9: _l(
        composer: const ChatComposer(
          text: 'help\n$_line',
          attachments: [_logAtt],
        ),
      ),
    },
  ),
  'logs failed': (
    const ChatLogsBuilt(Err(ExchangeChatAttachLogsFailure())),
    {
      9: _l(
        composer: const ChatComposer(text: 'help'),
        notice: const ChatNotice(1, ExchangeChatAttachLogsFailure()),
      ),
    },
  ),
  'attachment removed': (
    const ChatAttachmentRemoved(_att),
    {13: _l(composer: const ChatComposer(text: 'hi'))},
  ),
  'send pressed': (
    const ChatSendPressed(),
    {
      for (final i in [0, 1, 2, 3, 4, 5, 6, 8, 11, 12])
        i: _composer(
          _states[i],
          _states[i].composer.copyWith(
            problem: () => const ExchangeChatMessageEmptyFailure(),
          ),
        ),
      7: _l(
        outgoing: const [ChatOutgoingSending('local-4', 'hi', [])],
        tickets: 4,
      ),
      9: _l(
        composer: const ChatComposer(attaching: ChatAttachBuildingLogs(_line)),
        outgoing: const [ChatOutgoingSending('local-4', 'help', [])],
        tickets: 4,
      ),
      13: _l(
        outgoing: const [
          ChatOutgoingSending('local-4', 'hi', [_att]),
        ],
        tickets: 4,
      ),
    },
  ),
  'send accepted (CHAT-6: no sleep, the thread confirms it)': (
    const ChatSendAnswered('local-3', Ok(null)),
    {
      10: _l(
        outgoing: const [ChatOutgoingSent('local-3', 'hi', [])],
        refresh: const ChatRefreshing(4),
        tickets: 4,
      ),
    },
  ),
  'send failed': (
    const ChatSendAnswered('local-3', Err(ExchangeChatSendMessageFailure())),
    {
      10: _l(
        composer: const ChatComposer(
          text: 'hi',
          problem: ExchangeChatSendMessageFailure(),
        ),
      ),
    },
  ),
  'open pressed (CHAT-9: one entry per attachment)': (
    const ChatOpenPressed('a1'),
    {
      for (final i in _all)
        if (i != 12)
          i: SupportChatState(
            thread: _states[i].thread,
            composer: _states[i].composer,
            outgoing: _states[i].outgoing,
            opening: const {'a1'},
            tickets: _states[i].tickets,
          ),
    },
  ),
  'opened': (const ChatOpenFinished('a1', Ok(null)), {12: _l()}),
  'open failed': (
    const ChatOpenFinished('a1', Err(ExchangeChatLoadAttachmentFailure())),
    {12: _l(notice: const ChatNotice(1, ExchangeChatLoadAttachmentFailure()))},
  ),
};

void main() {
  group('every (state, event) pair', () {
    for (final MapEntry(key: name, value: (event, changes)) in _table.entries) {
      for (final (index, state) in _states.indexed) {
        test('$name from state $index', () {
          final next = state.next(event);
          if (changes[index] case final expected?) {
            expect(next.state, expected);
          } else {
            expect(identical(next.state, state), isTrue);
            expect(next.effects, isEmpty);
          }
        });
      }
    }
  });

  group('effects', () {
    test('start loads the first page and keeps the draft', () {
      expect(
        supportChatStart(draft: 'hello'),
        StepNext<SupportChatState, SupportChatEffect>(
          const SupportChatState(
            thread: ChatThreadLoading(1),
            composer: ChatComposer(text: 'hello'),
            tickets: 1,
          ),
          const [ChatFetchPage(1, 1)],
        ),
      );
    });

    test('a push refreshes page 1, older asks for the next page', () {
      expect((_states[2]).next(const ChatPushed()).effects, const [
        ChatFetchPage(4, 1),
      ]);
      expect((_states[2]).next(const ChatOlderRequested()).effects, const [
        ChatFetchPage(4, 2),
      ]);
    });

    test('the newest page on screen tells that every message was seen', () {
      expect((_states[0]).next(ChatPageLoaded(1, Ok([_m1]))).effects, const [
        ChatNewestShown(),
      ]);
      expect(
        (_states[0]).next(const ChatPageLoaded(1, Err(_loadFailure))).effects,
        isEmpty,
      );
      final refreshing = (_states[2]).next(const ChatPushed()).state;
      expect(refreshing.next(ChatPageLoaded(4, Ok([_m2, _m1]))).effects, const [
        ChatNewestShown(),
      ]);
      expect(
        refreshing.next(const ChatPageLoaded(4, Err(_loadFailure))).effects,
        isNot(contains(const ChatNewestShown())),
      );
      expect(
        (_states[5]).next(ChatPageLoaded(3, Ok([_m2, _m1]))).effects,
        isEmpty,
        reason: 'an older page is not the newest one',
      );
    });

    test('send, pick, logs and open start their effect', () {
      expect((_states[13]).next(const ChatSendPressed()).effects, const [
        ChatSend('local-4', 'hi', [_att]),
      ]);
      expect((_states[2]).next(const ChatAttachPressed()).effects, const [
        ChatPickImages(),
      ]);
      expect((_states[2]).next(const ChatLogsPressed(_line)).effects, const [
        ChatBuildLogs(),
      ]);
      expect((_states[2]).next(const ChatOpenPressed('a1')).effects, const [
        ChatOpenAttachment('a1'),
      ]);
    });
  });

  group('the thread', () {
    test('a sent message leaves the outgoing list when the thread shows it '
        '(CHAT-6)', () {
      final refreshing = (_states[11]).next(const ChatPushed()).state;
      final merged = refreshing.next(ChatPageLoaded(4, Ok([_m3, _m2]))).state;
      expect(merged.outgoing, isEmpty);
      expect((merged.thread as ChatThreadLoaded).messages, [_m3, _m2, _m1]);
    });

    test('an overlapping older page adds no duplicates (CHAT-3)', () {
      final older = (_states[5]).next(ChatPageLoaded(3, Ok([_m2, _m1]))).state;
      expect((older.thread as ChatThreadLoaded).messages, [_m2, _m1]);
    });

    test('a full page leaves older pages to load', () {
      final page = [
        for (var i = 0; i < supportChatPageSize; i++)
          SupportChatMessage(
            messageId: 'p$i',
            isAdmin: true,
            createdAt: DateTime(2025, 1, 1, i),
          ),
      ];
      final loaded = (_states[0]).next(ChatPageLoaded(1, Ok(page))).state;
      expect((loaded.thread as ChatThreadLoaded).nextPage, 2);
    });

    test('messages without an id are kept, not dropped or crashed on '
        '(CHAT-7)', () {
      final anonymous = SupportChatMessage(
        text: 'no id',
        isAdmin: true,
        createdAt: DateTime(2026, 2, 1),
      );
      final loaded = (_states[0])
          .next(ChatPageLoaded(1, Ok([anonymous])))
          .state;
      expect((loaded.thread as ChatThreadLoaded).messages, [anonymous]);
    });
  });

  test('every part of the state is reachable from the start', () {
    final seen = <String>{};
    final start = supportChatStart();
    final queue = <(SupportChatState, List<SupportChatEffect>)>[
      (start.state, start.effects),
    ];
    final visited = <SupportChatState>{};
    while (queue.isNotEmpty && visited.length < 2000) {
      final (state, effects) = queue.removeAt(0);
      if (!visited.add(state)) continue;
      seen.addAll(_kinds(state));
      for (final event in [
        ..._userEvents,
        for (final e in effects) ..._answers(e),
      ]) {
        final next = state.next(event);
        if (!identical(next.state, state)) {
          queue.add((next.state, next.effects));
        }
      }
    }
    expect(seen, containsAll(_everyKind));
  });
}

const _everyKind = {
  'ChatThreadLoading',
  'ChatThreadLoadFailed',
  'ChatThreadLoaded',
  'ChatRefreshIdle',
  'ChatRefreshing',
  'ChatRefreshQueued',
  'ChatOlderIdle',
  'ChatOlderLoading',
  'ChatAttachIdle',
  'ChatAttachPicking',
  'ChatAttachBuildingLogs',
  'ChatOutgoingSending',
  'ChatOutgoingSent',
  'opening',
  'notice',
};

Set<String> _kinds(SupportChatState state) => {
  state.thread.runtimeType.toString(),
  if (state.thread case ChatThreadLoaded(:final refresh, :final older)) ...{
    refresh.runtimeType.toString(),
    older.runtimeType.toString(),
  },
  state.composer.attaching.runtimeType.toString(),
  for (final o in state.outgoing) o.runtimeType.toString(),
  if (state.opening.isNotEmpty) 'opening',
  if (state.notice != null) 'notice',
};

const _userEvents = <SupportChatEvent>[
  ChatRetryPressed(),
  ChatPushed(),
  ChatOlderRequested(),
  ChatDraftChanged('hi'),
  ChatAttachPressed(),
  ChatLogsPressed(_line),
  ChatSendPressed(),
  ChatOpenPressed('a1'),
];

List<SupportChatEvent> _answers(SupportChatEffect effect) => switch (effect) {
  ChatFetchPage(:final ticket, :final page) => [
    ChatPageLoaded(
      ticket,
      Ok([
        for (var i = 0; i < supportChatPageSize; i++)
          SupportChatMessage(
            messageId: 'm$page-$i',
            text: 'hi',
            isAdmin: false,
            createdAt: DateTime(2026, 1, page, i),
          ),
      ]),
    ),
    ChatPageLoaded(ticket, const Err(_loadFailure)),
  ],
  ChatNewestShown() => [],
  ChatPickImages() => [
    const ChatAttachmentsPicked(Ok([_att])),
  ],
  ChatBuildLogs() => [const ChatLogsBuilt(Ok(_logAtt))],
  ChatSend(:final localId) => [ChatSendAnswered(localId, const Ok(null))],
  ChatOpenAttachment(:final attachmentId) => [
    ChatOpenFinished(
      attachmentId,
      const Err(ExchangeChatLoadAttachmentFailure()),
    ),
  ],
};
