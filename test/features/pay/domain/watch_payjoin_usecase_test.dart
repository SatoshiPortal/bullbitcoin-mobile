import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/watch_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

PayjoinSenderSession _session() => PayjoinSenderSession(
  status: PayjoinStatus.requested,
  uri: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
  network: BitcoinNetwork.mainnet,
  walletId: 'wallet-1',
  amount: Sats.fromInt(10000),
  originalTransactionId: 'original-txid',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

void main() {
  test('publishes updates for only the requested session', () async {
    final sessions = _MockPayjoinSessions();
    final payjoin = _session();
    when(
      () => sessions.byId(payjoin.id),
    ).thenAnswer((_) async => Ok<PayjoinSession?, PayjoinFailure>(payjoin));
    when(
      () => sessions.watch(sessionIds: {payjoin.id}),
    ).thenAnswer((_) => const Stream.empty());

    final updates = WatchPayjoinUsecase(sessions).execute(payjoin.id);

    expect(
      (await updates.single as Ok<PayjoinSession, PayFailure>).value,
      payjoin,
    );
    verify(() => sessions.byId(payjoin.id)).called(1);
    verify(() => sessions.watch(sessionIds: {payjoin.id})).called(1);
  });

  test('maps a package failure to a value, never a thrown error', () async {
    final sessions = _MockPayjoinSessions();
    when(
      () => sessions.byId('session-1'),
    ).thenAnswer((_) async => const Ok<PayjoinSession?, PayjoinFailure>(null));
    when(() => sessions.watch(sessionIds: {'session-1'})).thenAnswer(
      (_) => Stream.value(
        const Err<PayjoinSession, PayjoinFailure>(PayjoinStorageFailure()),
      ),
    );

    final updates = WatchPayjoinUsecase(sessions).execute('session-1');

    // A watcher failure must arrive as a value the bloc can switch on, and it
    // must end the stream so the caller decides whether to re-subscribe.
    final emitted = await updates.toList();

    expect(emitted, hasLength(1));
    expect(
      (emitted.single as Err<PayjoinSession, PayFailure>).failure,
      isA<PayUnexpectedFailure>(),
    );
  });

  test('a throwing session store becomes a value too', () async {
    // The store reports its own problems as Err, but if it ever throws the
    // stream would carry an error the caller has no arm for — the watch would
    // die without a resubscribe.
    final sessions = _MockPayjoinSessions();
    when(() => sessions.byId('session-1')).thenThrow(StateError('db closed'));

    final updates = WatchPayjoinUsecase(sessions).execute('session-1');
    final emitted = await updates.toList();

    expect(emitted, hasLength(1));
    expect(
      (emitted.single as Err<PayjoinSession, PayFailure>).failure,
      isA<PayUnexpectedFailure>(),
    );
  });
}
