import 'dart:async';

import 'package:bull_exchange/src/support_chat/domain/support_chat_machine.dart';
import 'package:bull_exchange/src/support_chat/presentation/support_chat_bloc.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../support_chat_usecase_fakes.dart';

Never _unused(String call) => throw StateError('$call was not expected');

/// Builds the bloc over fakes; every call lands in [calls].
SupportChatBloc _bloc({
  required List<String> calls,
  ChatResult<List<SupportChatMessage>> Function()? readPage,
  ChatResult<void> Function()? send,
  Stream<NotificationMessage>? pushes,
  String? draft,
}) => SupportChatBloc(
  getMessages: FakeGetSupportChatMessagesUsecase(({page, pageSize}) {
    calls.add('page $page size $pageSize');
    return readPage == null ? _unused('page') : readPage();
  }),
  sendMessage: FakeSendSupportChatMessageUsecase(({
    required text,
    attachments = const [],
  }) {
    calls.add('send $text ${attachments.length}');
    return send == null ? _unused('send') : send();
  }),
  pickImages: FakePickImageAttachmentsUsecase(() => _unused('pick')),
  createLogAttachment: FakeCreateLogAttachmentUsecase(() => _unused('logs')),
  openAttachment: FakeOpenSupportChatAttachmentUsecase((_) => _unused('open')),
  watchPushes: FakeWatchSupportChatPushesUsecase(
    () => pushes ?? const Stream.empty(),
  ),
  onNewestShown: () => calls.add('newest shown'),
  draft: draft,
);

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

const _message = SupportChatMessage(messageId: 'm1', text: 'hello');

void main() {
  test(
    'reads the first page and tells the newest messages were shown',
    () async {
      final calls = <String>[];
      final bloc = _bloc(
        calls: calls,
        readPage: () async => const Ok([_message]),
      );
      addTearDown(bloc.close);
      await _settle();
      expect(calls, ['page 1 size $supportChatPageSize', 'newest shown']);
      expect(bloc.state.thread, isA<ChatThreadLoaded>());
    },
  );

  test('a message push reads the first page again', () async {
    final calls = <String>[];
    final pushes = StreamController<NotificationMessage>();
    final bloc = _bloc(
      calls: calls,
      readPage: () async => const Ok([_message]),
      pushes: pushes.stream,
    );
    addTearDown(bloc.close);
    await _settle();
    calls.clear();
    pushes.add(
      const NotificationMessage(kind: NotificationMessageKind.message),
    );
    await _settle();
    expect(calls.first, 'page 1 size $supportChatPageSize');
    await pushes.close();
  });

  test('sends the draft with its attachments', () async {
    final calls = <String>[];
    final bloc = _bloc(
      calls: calls,
      readPage: () async => const Ok([_message]),
      send: () async => const Ok(null),
      draft: ' hi ',
    );
    addTearDown(bloc.close);
    await _settle();
    calls.clear();
    bloc.add(const ChatSendPressed());
    await _settle();
    expect(calls.first, 'send hi 0');
    expect(bloc.state.outgoing.single, isA<ChatOutgoingSent>());
  });

  test('a page arriving after close is dropped (CHAT-1)', () async {
    final release = Completer<Result<List<SupportChatMessage>, Never>>();
    final bloc = _bloc(calls: [], readPage: () => release.future);
    final loading = bloc.state;
    await bloc.close();
    release.complete(const Ok([_message]));
    await _settle();
    expect(bloc.state, same(loading));
  });
}
