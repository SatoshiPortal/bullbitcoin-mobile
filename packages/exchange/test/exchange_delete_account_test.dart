import 'package:exchange/testing.dart';
import 'package:exchange/setup.dart';

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

const _testSession = ExchangeSession(
  environment: ExchangeEnvironment.mainnet,
  epoch: 1,
  sessionId: 'test',
);

class _Access extends Mock implements ExchangeAccessLifecycle {}

abstract interface class _DeletionChat {
  Future<Result<void, ExchangeFailure>> send({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  });
}

class _Request extends Mock implements _DeletionChat {}

void main() {
  late _Access access;
  late _Request request;
  late Exchange exchange;
  var epoch = 1;
  setUp(() {
    epoch = 1;
    access = _Access();
    request = _Request();
    when(() => access.current)
        .thenReturn(const ExchangeAccessSignedIn(_testSession));
    when(() => access.session).thenAnswer(
      (_) => access.current.isSignedIn
          ? ExchangeSession(
              environment: ExchangeEnvironment.mainnet,
              epoch: epoch,
              sessionId: 'test',
            )
          : null,
    );
    exchange = exchangeForTesting(
      access: access,
      chat: (
        getMessages: ({page, pageSize}) => fail('unexpected support history'),
        getAttachment: (_) => fail('unexpected attachment'),
        sendMessage: request.send,
        getUnreadCount: (_) => fail('unexpected unread count'),
        markAllRead: (_) => fail('unexpected mark read'),
      ),
    );
  });

  test('a failed request never signs out', () async {
    when(() => request.send(text: 'I want to delete my account'))
        .thenAnswer((_) async => const Err(ExchangeChatSendMessageFailure()));
    expect(
      (await exchange.deleteAccount() as Err).failure,
      isA<ExchangeAccountDeletionRequestFailure>(),
    );
    verifyNever(access.signOut);
  });

  test('a signed-out account never requests deletion', () async {
    when(() => access.current)
        .thenReturn(const ExchangeAccessSignedOut(ExchangeEnvironment.mainnet));
    expect(
      (await exchange.deleteAccount() as Err).failure,
      isA<ExchangeNotAuthenticatedFailure>(),
    );
    verifyZeroInteractions(request);
    verifyNever(access.signOut);
  });

  test('an unsupported active network does not sign out', () async {
    when(
      () => request.send(text: 'I want to delete my account'),
    ).thenAnswer((_) async => const Err(ExchangeUnsupportedNetworkFailure()));
    expect(
      (await exchange.deleteAccount() as Err).failure,
      isA<ExchangeUnsupportedNetworkFailure>(),
    );
    verifyNever(access.signOut);
  });

  test('a sign-out failure is returned', () async {
    when(() => request.send(text: 'I want to delete my account'))
        .thenAnswer((_) async => const Ok(null));
    when(access.signOut)
        .thenAnswer((_) async => const Err(ExchangeSessionClearFailure()));
    expect(
      (await exchange.deleteAccount() as Err).failure,
      isA<ExchangeSessionClearFailure>(),
    );
  });

  test('a completed request and sign-out report completion', () async {
    when(() => request.send(text: 'I want to delete my account'))
        .thenAnswer((_) async => const Ok(null));
    when(access.signOut).thenAnswer((_) async => const Ok(null));
    expect(
      (await exchange.deleteAccount() as Ok).value,
      ExchangeAccountDeletionOutcome.completed,
    );
  });

  test('an old deletion request cannot sign out the new session', () async {
    final pending = Completer<Result<void, ExchangeFailure>>();
    when(() => request.send(text: 'I want to delete my account'))
        .thenAnswer((_) => pending.future);
    final result = exchange.deleteAccount();
    epoch++;
    pending.complete(const Ok(null));
    expect((await result as Ok).value, ExchangeAccountDeletionOutcome.stale);
    verifyNever(access.signOut);
  });
}
