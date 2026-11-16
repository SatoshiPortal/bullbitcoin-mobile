import 'package:bb_mobile/features/sell/domain/get_adoptable_payjoin_sender_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/watch_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSender extends Mock implements PayjoinSender {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

PayjoinSenderSession _session({
  PayjoinStatus status = PayjoinStatus.requested,
  String walletId = 'wallet-1',
  int amountSat = 100000,
}) => PayjoinSenderSession(
  status: status,
  uri: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
  network: BitcoinNetwork.mainnet,
  walletId: walletId,
  amount: Sats.fromInt(amountSat),
  originalTransactionId: 'original-txid',
  createdAt: DateTime(2026),
  expiresAt: DateTime(2026).add(const Duration(minutes: 5)),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      StartPayjoinSender(
        walletId: 'wallet-1',
        network: BitcoinNetwork.mainnet,
        bip21Uri: 'bitcoin:bc1qaddress',
        unsignedOriginalPsbt: 'cHNidP8=',
        amount: Sats.fromInt(1),
        feeRate: FeeRate(1),
      ),
    );
  });

  group('SendWithPayjoinUsecase', () {
    Future<Result<PayjoinSenderSession, SellFailure>> start(
      PayjoinSender sender,
    ) => SendWithPayjoinUsecase(sender).execute(
      walletId: 'wallet-1',
      network: BitcoinNetwork.mainnet,
      bip21: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
      unsignedOriginalPsbt: 'cHNidP8=',
      amountSat: 100000,
      networkFeesSatPerVb: 2,
    );

    test('returns the started session', () async {
      final sender = _MockPayjoinSender();
      final session = _session();
      when(() => sender.start(any())).thenAnswer(
        (_) async => Ok<PayjoinSenderSession, PayjoinFailure>(session),
      );

      final result = await start(sender);

      expect((result as Ok<PayjoinSenderSession, SellFailure>).value, session);
    });

    test('a kept session after a failed post is reported as such', () async {
      final sender = _MockPayjoinSender();
      when(() => sender.start(any())).thenAnswer(
        (_) async => const Err<PayjoinSenderSession, PayjoinFailure>(
          PayjoinSenderKeptFailure(
            'sender-orig-txid',
            'Sender start failed; session kept',
          ),
        ),
      );

      final result = await start(sender);

      expect(
        (result as Err<PayjoinSenderSession, SellFailure>).failure,
        isA<SellPayjoinSessionKeptFailure>(),
      );
    });

    test('sanitizes a payjoin package failure', () async {
      final sender = _MockPayjoinSender();
      when(() => sender.start(any())).thenAnswer(
        (_) async => const Err<PayjoinSenderSession, PayjoinFailure>(
          PayjoinStorageFailure(),
        ),
      );

      final result = await start(sender);

      switch (result) {
        case Ok():
          fail('a failed start must not look like a live session');
        case Err(:final failure):
          // No PayjoinFailure may escape into the sell feature.
          expect(failure, isA<SellFailure>());
          expect(failure, isNot(isA<PayjoinFailure>()));
      }
    });
  });

  group('WatchPayjoinUsecase', () {
    test('forwards an update as Ok', () async {
      final sessions = _MockPayjoinSessions();
      final session = _session();
      when(
        () => sessions.byId(session.id),
      ).thenAnswer((_) async => Ok<PayjoinSession?, PayjoinFailure>(session));
      when(() => sessions.watch(sessionIds: {session.id})).thenAnswer(
        (_) => const Stream<Result<PayjoinSession, PayjoinFailure>>.empty(),
      );

      final first = await WatchPayjoinUsecase(sessions)
          .execute(session.id)
          .first;

      expect(first, isA<Ok<PayjoinSession, SellFailure>>());
    });

    test('yields a sanitized failure instead of throwing', () async {
      final sessions = _MockPayjoinSessions();
      when(() => sessions.byId('session-1')).thenAnswer(
        (_) async =>
            const Err<PayjoinSession?, PayjoinFailure>(PayjoinStorageFailure()),
      );

      final first = await WatchPayjoinUsecase(sessions)
          .execute('session-1')
          .first;

      // Yielded, not thrown: an error would tear down the subscription and
      // leave a settling sale looking stuck.
      switch (first) {
        case Ok():
          fail('a storage failure must not look like a session update');
        case Err(:final failure):
          expect(failure, isA<SellUnexpectedFailure>());
      }
    });
  });

  group('GetAdoptablePayjoinSenderUsecase', () {
    Future<Result<PayjoinSenderSession?, SellFailure>> adopt(
      PayjoinSessions sessions,
    ) => GetAdoptablePayjoinSenderUsecase(sessions).execute(
      sessionId: _session().id,
      walletId: 'wallet-1',
      amountSat: 100000,
    );

    test('returns this payin\'s ongoing session', () async {
      final sessions = _MockPayjoinSessions();
      final session = _session();
      when(
        () => sessions.byId(session.id),
      ).thenAnswer((_) async => Ok<PayjoinSession?, PayjoinFailure>(session));

      final result = await adopt(sessions);

      expect((result as Ok<PayjoinSenderSession?, SellFailure>).value, session);
    });

    test('an absent session is Ok(null), not a failure', () async {
      final sessions = _MockPayjoinSessions();
      when(() => sessions.byId(_session().id)).thenAnswer(
        (_) async => const Ok<PayjoinSession?, PayjoinFailure>(null),
      );

      final result = await adopt(sessions);

      expect((result as Ok<PayjoinSenderSession?, SellFailure>).value, isNull);
    });

    // The session stream never replays a terminal row, so adopting one would
    // leave the payin waiting on a settlement that already happened; a live
    // row of another wallet or amount is an earlier attempt on the link.
    for (final (name, session) in [
      ('completed', _session(status: PayjoinStatus.completed)),
      ('aborted', _session(status: PayjoinStatus.aborted)),
      ('expired', _session(status: PayjoinStatus.expired)),
      ('another wallet\'s', _session(walletId: 'wallet-2')),
      ('another amount\'s', _session(amountSat: 1)),
    ]) {
      test('a $name session is not adoptable', () async {
        final sessions = _MockPayjoinSessions();
        when(
          () => sessions.byId(session.id),
        ).thenAnswer((_) async => Ok<PayjoinSession?, PayjoinFailure>(session));

        final result = await adopt(sessions);

        expect(
          (result as Ok<PayjoinSenderSession?, SellFailure>).value,
          isNull,
        );
      });
    }

    test('an unreadable session is a failure, not a bare null', () async {
      final sessions = _MockPayjoinSessions();
      when(() => sessions.byId(_session().id)).thenAnswer(
        (_) async =>
            const Err<PayjoinSession?, PayjoinFailure>(PayjoinStorageFailure()),
      );

      final result = await adopt(sessions);

      // "No session" and "could not tell" must stay distinguishable: on the
      // payjoin-start failure path that difference decides whether re-arming
      // Confirm could pay the same order twice.
      switch (result) {
        case Ok():
          fail('an unreadable session must not read as definitively absent');
        case Err(:final failure):
          expect(failure, isA<SellUnexpectedFailure>());
          expect(failure, isNot(isA<PayjoinFailure>()));
      }
    });
  });
}
