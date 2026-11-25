import 'dart:async';

import 'package:bull_exchange/src/support_chat/presentation/support_unread_bloc.dart';
import 'package:bull_exchange/src/support_chat/presentation/support_unread_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'a',
);
const _message = NotificationMessage(kind: NotificationMessageKind.message);

/// Scripted answers, one queue per call.
final class _Server {
  final reads = <Completer<ExchangeRead<int>>>[];
  final marks = <Completer<ExchangeWrite<void>>>[];

  Future<ExchangeRead<int>> read(ExchangeSession _) {
    final answer = Completer<ExchangeRead<int>>();
    reads.add(answer);
    return answer.future;
  }

  Future<ExchangeWrite<void>> mark(ExchangeSession _) {
    final answer = Completer<ExchangeWrite<void>>();
    marks.add(answer);
    return answer.future;
  }
}

void main() {
  late _Server server;
  late StreamController<ExchangeAccess> access;
  late StreamController<NotificationMessage> messages;
  ExchangeAccess current = const ExchangeAccessDisabled();

  SupportUnreadBloc build() {
    final bloc = SupportUnreadBloc(
      readCount: server.read,
      markRead: server.mark,
      currentAccess: () => current,
      accessChanges: access.stream,
      supportMessages: messages.stream,
    );
    addTearDown(bloc.close);
    return bloc;
  }

  int badge(SupportUnreadBloc bloc) => supportUnreadBadge(bloc.state);

  setUp(() {
    server = _Server();
    access = StreamController<ExchangeAccess>.broadcast();
    messages = StreamController<NotificationMessage>.broadcast();
    current = const ExchangeAccessDisabled();
  });

  test('the count follows sign-in and new messages', () async {
    final bloc = build();
    await pumpEventQueue();
    expect(bloc.state, const UnreadSignedOut());

    access.add(const ExchangeAccessSignedIn(_a));
    await pumpEventQueue();
    expect(bloc.state, const UnreadReading(_a, 0));
    server.reads.single.complete(const ReadGot(2));
    await pumpEventQueue();
    expect(badge(bloc), 2);

    messages.add(_message);
    await pumpEventQueue();
    server.reads.last.complete(const ReadGot(3));
    await pumpEventQueue();
    expect(badge(bloc), 3);

    messages.add(_message);
    await pumpEventQueue();
    server.reads.last.complete(
      const ReadUnreachable('offline', isNetwork: true),
    );
    await pumpEventQueue();
    expect(
      bloc.state,
      const UnreadStale(_a, 2, 3, UnreadProblem.unreachable),
      reason: 'a failed re-read keeps the last count, named stale',
    );

    access.add(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    await pumpEventQueue();
    expect(bloc.state, const UnreadSignedOut());
  });

  test('a first read that fails is unavailable, not zero', () async {
    current = const ExchangeAccessSignedIn(_a);
    final bloc = build();
    await pumpEventQueue();
    server.reads.single.complete(const ReadMalformed('negative'));
    await pumpEventQueue();
    expect(bloc.state, const UnreadUnavailable(_a, 0, UnreadProblem.malformed));
  });

  test(
    'opening the chat clears the badge and confirms with the server',
    () async {
      current = const ExchangeAccessSignedIn(_a);
      final bloc = build();
      await pumpEventQueue();
      server.reads.single.complete(const ReadGot(4));
      await pumpEventQueue();
      expect(badge(bloc), 4);

      bloc.add(const UnreadChatShown());
      await pumpEventQueue();
      expect(badge(bloc), 0);
      expect(server.marks, hasLength(1));

      server.marks.single.complete(const WriteDone(null));
      await pumpEventQueue();
      expect(badge(bloc), 0);
      server.reads.last.complete(const ReadGot(1));
      await pumpEventQueue();
      expect(badge(bloc), 1);
    },
  );

  test(
    'a count read before the chat opened cannot restore the badge',
    () async {
      current = const ExchangeAccessSignedIn(_a);
      final bloc = build();
      await pumpEventQueue();
      bloc.add(const UnreadChatShown());
      await pumpEventQueue();
      server.reads.first.complete(const ReadGot(5));
      await pumpEventQueue();
      expect(badge(bloc), 0);
      expect(bloc.state, isA<UnreadMarking>());
    },
  );

  test('a mark that fails reads the real count again', () async {
    current = const ExchangeAccessSignedIn(_a);
    final bloc = build();
    await pumpEventQueue();
    server.reads.single.complete(const ReadGot(4));
    await pumpEventQueue();
    bloc.add(const UnreadChatShown());
    await pumpEventQueue();
    server.marks.single.complete(const WriteOutcomeUnknown('timeout'));
    await pumpEventQueue();
    server.reads.last.complete(const ReadGot(4));
    await pumpEventQueue();
    expect(badge(bloc), 4);
  });
}
