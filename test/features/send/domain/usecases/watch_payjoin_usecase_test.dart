import 'dart:async';

import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

PayjoinSenderSession _session({
  PayjoinStatus status = PayjoinStatus.requested,
}) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
  network: BitcoinNetwork.mainnet,
  walletId: 'wallet-1',
  amount: Sats.fromInt(10000),
  originalTransactionId: 'original-txid',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

_MockPayjoinSessions _sessions({PayjoinSession? current}) {
  final sessions = _MockPayjoinSessions();
  when(
    () => sessions.byId(any()),
  ).thenAnswer((_) async => Ok<PayjoinSession?, PayjoinFailure>(current));
  return sessions;
}

void main() {
  test('forwards a session update as Ok', () async {
    final sessions = _sessions();
    final payjoin = _session();
    when(() => sessions.watch(sessionIds: {payjoin.id})).thenAnswer(
      (_) => Stream.value(Ok<PayjoinSession, PayjoinFailure>(payjoin)),
    );

    final updates = WatchPayjoinUsecase(sessions).execute(ids: [payjoin.id]);

    final first = await updates.first;
    expect(first, isA<core.Ok<PayjoinSession, SendFailure>>());
    expect((first as core.Ok<PayjoinSession, SendFailure>).value, payjoin);
  });

  test('yields a sanitized failure instead of throwing on the stream', () async {
    final sessions = _sessions();
    when(() => sessions.watch(sessionIds: {'session-1'})).thenAnswer(
      (_) => Stream.value(
        const Err<PayjoinSession, PayjoinFailure>(PayjoinStorageFailure()),
      ),
    );

    final updates = WatchPayjoinUsecase(sessions).execute(ids: ['session-1']);

    // Yielded, not thrown: an error on this stream would cancel the
    // subscription and leave the confirm screen unable to resolve the payjoin.
    final first = await updates.first;
    switch (first) {
      case core.Ok():
        fail('a package failure must not be reported as a session update');
      case core.Err(:final failure):
        expect(failure, isA<SendTransactionConfirmationFailure>());
    }
  });

  test('a failed update does not end the stream', () async {
    final sessions = _sessions();
    final payjoin = _session();
    when(() => sessions.watch(sessionIds: {payjoin.id})).thenAnswer(
      (_) => Stream.fromIterable([
        const Err<PayjoinSession, PayjoinFailure>(PayjoinStorageFailure()),
        Ok<PayjoinSession, PayjoinFailure>(payjoin),
      ]),
    );

    final updates = await WatchPayjoinUsecase(
      sessions,
    ).execute(ids: [payjoin.id]).toList();

    expect(updates, hasLength(2));
    expect(updates.last, isA<core.Ok<PayjoinSession, SendFailure>>());
  });

  test('delivers a session that settled before the watch started', () async {
    final payjoin = _session(status: PayjoinStatus.aborted);
    final sessions = _sessions(current: payjoin);
    when(
      () => sessions.watch(sessionIds: {payjoin.id}),
    ).thenAnswer((_) => const Stream.empty());

    final updates = await WatchPayjoinUsecase(
      sessions,
    ).execute(ids: [payjoin.id]).toList();

    expect(updates, hasLength(1));
    expect(
      (updates.single as core.Ok<PayjoinSession, SendFailure>).value,
      payjoin,
    );
  });

  test('keeps an update emitted while the current state is read', () async {
    final sessions = _MockPayjoinSessions();
    final requested = _session();
    final aborted = _session(status: PayjoinStatus.aborted);
    final changes =
        StreamController<Result<PayjoinSession, PayjoinFailure>>.broadcast();
    final read = Completer<Result<PayjoinSession?, PayjoinFailure>>();
    when(() => sessions.byId(any())).thenAnswer((_) => read.future);
    when(
      () => sessions.watch(sessionIds: {requested.id}),
    ).thenAnswer((_) => changes.stream);

    final updates = <PayjoinSession>[];
    final subscription = WatchPayjoinUsecase(sessions)
        .execute(ids: [requested.id])
        .listen((result) {
          if (result case core.Ok(:final value)) updates.add(value);
        });
    await pumpEventQueue();
    changes.add(Ok(aborted));
    read.complete(Ok(requested));
    await pumpEventQueue();
    await changes.close();
    await subscription.cancel();

    expect(updates, [requested, aborted]);
  });

  test('ends after a session that was already settled', () async {
    final payjoin = _session(status: PayjoinStatus.completed);
    final sessions = _sessions(current: payjoin);
    when(() => sessions.watch(sessionIds: {payjoin.id})).thenAnswer(
      (_) =>
          StreamController<Result<PayjoinSession, PayjoinFailure>>.broadcast()
              .stream,
    );

    final updates = await WatchPayjoinUsecase(
      sessions,
    ).execute(ids: [payjoin.id]).toList();

    expect(updates, hasLength(1));
  });

  test('reports a failed read of the current state', () async {
    final sessions = _MockPayjoinSessions();
    final payjoin = _session();
    when(() => sessions.byId(any())).thenAnswer(
      (_) async =>
          const Err<PayjoinSession?, PayjoinFailure>(PayjoinStorageFailure()),
    );
    when(() => sessions.watch(sessionIds: {payjoin.id})).thenAnswer(
      (_) => Stream.value(Ok<PayjoinSession, PayjoinFailure>(payjoin)),
    );

    final updates = await WatchPayjoinUsecase(
      sessions,
    ).execute(ids: [payjoin.id]).toList();

    expect(updates, hasLength(2));
    expect(updates.first, isA<core.Err<PayjoinSession, SendFailure>>());
    expect(updates.last, isA<core.Ok<PayjoinSession, SendFailure>>());
  });
}
