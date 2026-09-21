import 'package:bb_mobile/core/utils/result.dart' as bb;
import 'package:bb_mobile/features/transactions/application/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/get_payjoin_by_tx_id_usecase.dart';
import 'package:bb_mobile/features/transactions/application/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/transactions/domain/transaction_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinNetwork, Err, Ok, Result, Sats;

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockPayjoinSender extends Mock implements PayjoinSender {}

PayjoinSenderSession _session() => PayjoinSenderSession(
  status: PayjoinStatus.requested,
  uri: 'bitcoin:tb1qsender?pj=https://payjo.in',
  network: BitcoinNetwork.testnet,
  walletId: 'w1',
  originalTransactionId: 'orig-txid',
  amount: Sats.fromInt(50000),
  createdAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2026).add(const Duration(minutes: 1)),
  hasProposal: false,
);

/// The reason a failure carries must stay in `logMessage`, which only the log
/// sees. These assertions pin the *type* the UI switches on; asserting the
/// string would enshrine a developer message as a user-facing contract.
void main() {
  late _MockPayjoinSessions sessions;
  late _MockPayjoinSender sender;

  setUp(() {
    sessions = _MockPayjoinSessions();
    sender = _MockPayjoinSender();
  });

  group('GetPayjoinByIdUsecase', () {
    test('returns the session when one is stored', () async {
      final session = _session();
      when(
        () => sessions.byId('pj-1'),
      ).thenAnswer((_) async => Ok<PayjoinSession?, PayjoinFailure>(session));

      final result = await GetPayjoinByIdUsecase(sessions).execute('pj-1');

      expect(result, isA<bb.Ok<PayjoinSession, TransactionFailure>>());
      expect((result as bb.Ok).value, session);
    });

    test('maps a missing session to not-found, not a raw failure', () async {
      when(() => sessions.byId('pj-1')).thenAnswer(
        (_) async => const Ok<PayjoinSession?, PayjoinFailure>(null),
      );

      final result = await GetPayjoinByIdUsecase(sessions).execute('pj-1');

      expect((result as bb.Err).failure, isA<TransactionNotFoundFailure>());
    });

    test('sanitizes a storage failure into the transaction family', () async {
      when(() => sessions.byId('pj-1')).thenAnswer(
        (_) async => const Err<PayjoinSession?, PayjoinFailure>(
          PayjoinStorageFailure('sqlite disk image is malformed'),
        ),
      );

      final result = await GetPayjoinByIdUsecase(sessions).execute('pj-1');

      final failure = (result as bb.Err).failure as TransactionFailure;
      expect(failure, isA<TransactionUnexpectedFailure>());
      // The foreign reason must not survive into what the UI can reach.
      expect(failure.logMessage, isNot(contains('sqlite disk image')));
    });
  });

  group('GetPayjoinByTxIdUsecase', () {
    test('returns the first matching session', () async {
      final session = _session();
      when(() => sessions.byTransactionId('tx-1')).thenAnswer(
        (_) async => Ok<List<PayjoinSession>, PayjoinFailure>([session]),
      );

      final result = await GetPayjoinByTxIdUsecase(sessions).execute('tx-1');

      expect((result as bb.Ok).value, session);
    });

    test('maps an empty result to not-found', () async {
      when(() => sessions.byTransactionId('tx-1')).thenAnswer(
        (_) async => const Ok<List<PayjoinSession>, PayjoinFailure>([]),
      );

      final result = await GetPayjoinByTxIdUsecase(sessions).execute('tx-1');

      expect((result as bb.Err).failure, isA<TransactionNotFoundFailure>());
    });

    test('sanitizes a lookup failure', () async {
      when(() => sessions.byTransactionId('tx-1')).thenAnswer(
        (_) async => const Err<List<PayjoinSession>, PayjoinFailure>(
          PayjoinRelayUnavailableFailure('relay 503 from payjo.in'),
        ),
      );

      final result = await GetPayjoinByTxIdUsecase(sessions).execute('tx-1');

      final failure = (result as bb.Err).failure as TransactionFailure;
      expect(failure, isA<TransactionUnexpectedFailure>());
      expect(failure.logMessage, isNot(contains('payjo.in')));
    });
  });

  group('BroadcastOriginalTransactionUsecase', () {
    test('returns the updated session on success', () async {
      final session = _session();
      when(
        () => sender.broadcastOriginal(session.id),
      ).thenAnswer((_) async => Ok<PayjoinSession, PayjoinFailure>(session));

      final result = await BroadcastOriginalTransactionUsecase(
        sender,
      ).execute(session);

      expect((result as bb.Ok).value, session);
    });

    test(
      'keeps fallback-unavailable distinct — the UI words it differently',
      () async {
        final session = _session();
        when(() => sender.broadcastOriginal(session.id)).thenAnswer(
          (_) async => const Err<PayjoinSession, PayjoinFailure>(
            PayjoinFallbackUnavailableFailure(),
          ),
        );

        final result = await BroadcastOriginalTransactionUsecase(
          sender,
        ).execute(session);

        expect(
          (result as bb.Err).failure,
          isA<TransactionPayjoinFallbackUnavailableFailure>(),
        );
      },
    );

    test('sanitizes every other broadcast failure', () async {
      final session = _session();
      when(() => sender.broadcastOriginal(session.id)).thenAnswer(
        (_) async => const Err<PayjoinSession, PayjoinFailure>(
          PayjoinProtocolRejectedFailure('bad-txns-inputs-missingorspent'),
        ),
      );

      final result = await BroadcastOriginalTransactionUsecase(
        sender,
      ).execute(session);

      final failure = (result as bb.Err).failure as TransactionFailure;
      expect(failure, isA<TransactionPayjoinBroadcastFailure>());
      // A node rejection reason is exactly the kind of string #1895 forbids.
      expect(failure.logMessage, isNot(contains('bad-txns')));
    });

    test(
      'canExecute reports false rather than propagating a failure',
      () async {
        final session = _session();
        when(() => sender.canBroadcastOriginal(session.id)).thenAnswer(
          (_) async =>
              const Err<bool, PayjoinFailure>(PayjoinStorageFailure('locked')),
        );

        expect(
          await BroadcastOriginalTransactionUsecase(sender).canExecute(session),
          isFalse,
        );
      },
    );
  });

  group('WatchPayjoinUsecase', () {
    test('emits a Result per event instead of throwing', () async {
      final session = _session();
      when(
        () => sessions.watch(sessionIds: any(named: 'sessionIds')),
      ).thenAnswer(
        (_) => Stream<Result<PayjoinSession, PayjoinFailure>>.fromIterable([
          Ok(session),
          const Err(PayjoinStorageFailure('db closed mid-watch')),
        ]),
      );

      final emitted = await WatchPayjoinUsecase(
        sessions,
      ).execute(ids: ['pj-1']).toList();

      expect(emitted.first, isA<bb.Ok<PayjoinSession, TransactionFailure>>());
      final failure = (emitted.last as bb.Err).failure as TransactionFailure;
      expect(failure, isA<TransactionUnexpectedFailure>());
      expect(failure.logMessage, isNot(contains('db closed')));
    });

    test('turns a raw stream error into a failure value, not a zone error', () {
      // The cubit listens without an onError, so an error event escaping this
      // use case would become an unhandled zone error.
      when(
        () => sessions.watch(sessionIds: any(named: 'sessionIds')),
      ).thenAnswer(
        (_) => Stream<Result<PayjoinSession, PayjoinFailure>>.error(
          StateError('session store closed'),
        ),
      );

      expect(
        WatchPayjoinUsecase(sessions).execute(),
        emitsInOrder([
          isA<bb.Err<PayjoinSession, TransactionFailure>>().having(
            (e) => e.failure,
            'failure',
            isA<TransactionUnexpectedFailure>(),
          ),
          emitsDone,
        ]),
      );
    });
  });
}
