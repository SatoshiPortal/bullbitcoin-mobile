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

void main() {
  late _MockPayjoinSessions sessions;
  setUp(() {
    sessions = _MockPayjoinSessions();
    when(() => sessions.byId(any())).thenAnswer((_) async => const Ok(null));
  });

  test('forwards a session update as Ok', () async {
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

  test('a live completion supersedes an older pending snapshot', () async {
    final events = StreamController<Result<PayjoinSession, PayjoinFailure>>();
    addTearDown(events.close);
    final snapshot = Completer<Result<PayjoinSession?, PayjoinFailure>>();
    final pending = _session();
    final completed = _session(status: PayjoinStatus.completed);
    when(
      () => sessions.watch(sessionIds: {pending.id}),
    ).thenAnswer((_) => events.stream);
    when(() => sessions.byId(pending.id)).thenAnswer((_) => snapshot.future);
    final seen = <PayjoinSession>[];
    final subscription = WatchPayjoinUsecase(sessions)
        .execute(ids: [pending.id])
        .listen((result) {
          if (result case core.Ok(:final value)) seen.add(value);
        });
    events.add(Ok(completed));
    await Future<void>.delayed(Duration.zero);
    snapshot.complete(Ok(pending));
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(seen, [completed]);
    expect(events.hasListener, isFalse);
  });
}
