import 'dart:async';

import 'package:bull_exchange/src/support_chat/domain/usecases/watch_support_chat_pushes_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test(
    'passes on message pushes only, never other kinds or failures',
    () async {
      final socket =
          StreamController<Result<NotificationMessage, ExchangeFailure>>();
      final pushes = WatchSupportChatPushesUsecase(
        exchangeForTesting(
          notifications: (
            messages: () => socket.stream,
            connect: (_) async => fail('unexpected connect'),
            reconnect: (_) async => fail('unexpected reconnect'),
            disconnect: () => fail('unexpected disconnect'),
            close: () async {},
          ),
        ),
      ).execute().toList();
      socket
        ..add(
          const Ok(NotificationMessage(kind: NotificationMessageKind.balance)),
        )
        ..add(const Err(ExchangeNetworkFailure('socket')))
        ..add(
          const Ok(
            NotificationMessage(
              kind: NotificationMessageKind.message,
              event: 'e',
            ),
          ),
        );
      await socket.close();
      final got = await pushes;
      expect(got.map((m) => (m.kind, m.event)), [
        (NotificationMessageKind.message, 'e'),
      ]);
    },
  );
}
