import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinReceiver extends Mock implements PayjoinReceiver {}

class _MockPayjoinSender extends Mock implements PayjoinSender {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

const _rawReason = 'directory 502: <html>nginx/1.24.0 upstream</html>';

PayjoinReceiverSession _session() => PayjoinReceiverSession(
  status: PayjoinStatus.started,
  id: 'session-1',
  network: BitcoinNetwork.mainnet,
  walletId: 'wallet-1',
  payjoinUri: 'bitcoin:bc1qaddress?pj=https://payjo.in',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 1)),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      StartPayjoinReceiver(
        walletId: 'wallet-1',
        network: BitcoinNetwork.mainnet,
        address: 'bc1qaddress',
      ),
    );
  });

  group('ReceiveWithPayjoinUsecase', () {
    test('returns the session on success', () async {
      final receiver = _MockPayjoinReceiver();
      final session = _session();
      when(() => receiver.start(any())).thenAnswer(
        (_) async => Ok<PayjoinReceiverSession, PayjoinFailure>(session),
      );

      final result = await ReceiveWithPayjoinUsecase(
        receiver,
      ).execute(walletId: 'wallet-1', address: 'bc1qaddress');

      expect(result, isA<Ok<PayjoinReceiverSession, ReceiveFailure>>());
    });

    test('maps a package failure to a sanitized failure and keeps the raw '
        'reason out of everything but logMessage', () async {
      final receiver = _MockPayjoinReceiver();
      when(() => receiver.start(any())).thenAnswer(
        (_) async => const Err<PayjoinReceiverSession, PayjoinFailure>(
          PayjoinRelayUnavailableFailure(_rawReason),
        ),
      );

      final result = await ReceiveWithPayjoinUsecase(
        receiver,
      ).execute(walletId: 'wallet-1', address: 'bc1qaddress');

      switch (result) {
        case Ok():
          fail('a package failure must not be reported as a session');
        case Err(:final failure):
          // Dedicated variant, not the catch-all: the receive still works
          // without payjoin, so the bloc must be able to tell it apart.
          expect(failure, isA<ReceivePayjoinUnavailableFailure>());
          expect(failure.logMessage, _rawReason);
      }
    });
  });

  group('BroadcastOriginalTransactionUsecase', () {
    test('maps the unavailable fallback to its own variant', () async {
      final sender = _MockPayjoinSender();
      when(() => sender.broadcastOriginal('session-1')).thenAnswer(
        (_) async => const Err<PayjoinSession, PayjoinFailure>(
          PayjoinFallbackUnavailableFailure(_rawReason),
        ),
      );

      final result = await BroadcastOriginalTransactionUsecase(
        sender,
      ).execute('session-1');

      switch (result) {
        case Ok():
          fail('an unavailable fallback must not be reported as success');
        case Err(:final failure):
          // Distinct from the generic broadcast failure: the bloc absorbs
          // this one silently, because the watchers converge the screen.
          expect(failure, isA<ReceiveBroadcastOriginalTxUnavailableFailure>());
      }
    });

    test('maps any other package failure to the broadcast failure', () async {
      final sender = _MockPayjoinSender();
      when(() => sender.broadcastOriginal('session-1')).thenAnswer(
        (_) async => const Err<PayjoinSession, PayjoinFailure>(
          PayjoinBroadcastFailure(_rawReason),
        ),
      );

      final result = await BroadcastOriginalTransactionUsecase(
        sender,
      ).execute('session-1');

      switch (result) {
        case Ok():
          fail('a package failure must not be reported as success');
        case Err(:final failure):
          expect(failure, isA<ReceiveBroadcastOriginalTxFailure>());
          expect(failure.logMessage, _rawReason);
      }
    });
  });

  group('WatchPayjoinUsecase', () {
    test(
      'yields a sanitized failure instead of throwing on the stream',
      () async {
        final sessions = _MockPayjoinSessions();
        when(() => sessions.watch(sessionIds: {'session-1'})).thenAnswer(
          (_) => Stream.value(
            const Err<PayjoinSession, PayjoinFailure>(
              PayjoinStorageFailure(_rawReason),
            ),
          ),
        );

        final updates = WatchPayjoinUsecase(
          sessions,
        ).execute(ids: ['session-1']);

        // Yielded, not thrown: an error on this stream would cancel the
        // subscription and freeze the payjoin state on the receive screen.
        final first = await updates.first;
        switch (first) {
          case Ok():
            fail('a package failure must not be reported as a session update');
          case Err(:final failure):
            expect(failure, isA<ReceivePayjoinUnavailableFailure>());
            expect(failure.logMessage, _rawReason);
        }
      },
    );

    test('a failed update does not end the stream', () async {
      final sessions = _MockPayjoinSessions();
      final session = _session();
      when(() => sessions.watch(sessionIds: {session.id})).thenAnswer(
        (_) => Stream.fromIterable([
          const Err<PayjoinSession, PayjoinFailure>(PayjoinStorageFailure()),
          Ok<PayjoinSession, PayjoinFailure>(session),
        ]),
      );

      final updates = await WatchPayjoinUsecase(
        sessions,
      ).execute(ids: [session.id]).toList();

      expect(updates, hasLength(2));
      expect(updates.last, isA<Ok<PayjoinSession, ReceiveFailure>>());
    });
  });
}
