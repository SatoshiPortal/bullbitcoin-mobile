import 'package:bb_mobile/features/sell/domain/get_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/send_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/watch_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSender extends Mock implements PayjoinSender {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

PayjoinSenderSession _session() => PayjoinSenderSession(
  status: PayjoinStatus.requested,
  uri: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
  network: BitcoinNetwork.mainnet,
  walletId: 'wallet-1',
  amount: Sats.fromInt(100000),
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
      isTestnet: false,
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

      final first = await WatchPayjoinUsecase(
        sessions,
      ).execute(session.id).first;

      expect(first, isA<Ok<PayjoinSession, SellFailure>>());
    });

    test('yields a sanitized failure instead of throwing', () async {
      final sessions = _MockPayjoinSessions();
      when(() => sessions.byId('session-1')).thenAnswer(
        (_) async =>
            const Err<PayjoinSession?, PayjoinFailure>(PayjoinStorageFailure()),
      );

      final first = await WatchPayjoinUsecase(
        sessions,
      ).execute('session-1').first;

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

  group('GetPayjoinUsecase', () {
    test('returns the persisted session', () async {
      final sessions = _MockPayjoinSessions();
      final session = _session();
      when(
        () => sessions.byId(session.id),
      ).thenAnswer((_) async => Ok<PayjoinSession?, PayjoinFailure>(session));

      final result = await GetPayjoinUsecase(sessions).execute(session.id);

      switch (result) {
        case Ok(:final value):
          expect(value, session);
        case Err():
          fail("a readable session must not be reported as a failure");
      }
    });

    test('an absent session is Ok(null), not a failure', () async {
      final sessions = _MockPayjoinSessions();
      when(() => sessions.byId('session-1')).thenAnswer(
        (_) async => const Ok<PayjoinSession?, PayjoinFailure>(null),
      );

      final result = await GetPayjoinUsecase(sessions).execute('session-1');

      switch (result) {
        case Ok(:final value):
          expect(value, isNull);
        case Err():
          fail("a definitively absent session is not a failure");
      }
    });

    test('an unreadable session is a failure, not a bare null', () async {
      final sessions = _MockPayjoinSessions();
      when(() => sessions.byId('session-1')).thenAnswer(
        (_) async =>
            const Err<PayjoinSession?, PayjoinFailure>(PayjoinStorageFailure()),
      );

      final result = await GetPayjoinUsecase(sessions).execute('session-1');

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
