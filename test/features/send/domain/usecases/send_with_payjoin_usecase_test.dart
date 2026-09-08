import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSender extends Mock implements PayjoinSender {}

class _MockPayjoinSessions extends Mock implements PayjoinSessions {}

class _MockPayjoinLifecycle extends Mock implements PayjoinLifecycle {}

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

Future<core.Result<PayjoinSenderSession, SendFailure>> _start(
  PayjoinSender sender, {
  PayjoinSessions? sessions,
  PayjoinLifecycle? lifecycle,
}) {
  final lookup = sessions ?? _MockPayjoinSessions();
  if (sessions == null) {
    when(() => lookup.byId(any())).thenAnswer((_) async => const Ok(null));
  }
  final recovery = lifecycle ?? _MockPayjoinLifecycle();
  if (lifecycle == null) {
    when(recovery.resume).thenAnswer((_) async => const Ok(null));
  }
  return SendWithPayjoinUsecase(sender, lookup, recovery).execute(
    walletId: 'wallet-1',
    isTestnet: false,
    bip21: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
    unsignedOriginalPsbt: 'cHNidP8=',
    amountSat: 10000,
    networkFeesSatPerVb: 2,
  );
}

void main() {
  setUpAll(() {
    // StartPayjoinSender is a final class, so mocktail needs a real instance
    // as the fallback rather than a Fake subclass.
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

  test('returns the started session', () async {
    final sender = _MockPayjoinSender();
    final session = _session();
    when(() => sender.start(any())).thenAnswer(
      (_) async => Ok<PayjoinSenderSession, PayjoinFailure>(session),
    );

    final result = await _start(sender);

    expect(result, isA<core.Ok<PayjoinSenderSession, SendFailure>>());
    expect(
      (result as core.Ok<PayjoinSenderSession, SendFailure>).value,
      session,
    );
  });

  test('sanitizes a package failure into a confirmation failure', () async {
    final sender = _MockPayjoinSender();
    when(() => sender.start(any())).thenAnswer(
      (_) async => const Err<PayjoinSenderSession, PayjoinFailure>(
        PayjoinStorageFailure(),
      ),
    );

    final result = await _start(sender);

    switch (result) {
      case core.Ok():
        fail('a failed payjoin start must not look like a started session');
      case core.Err(:final failure):
        // Confirmation, not build: the transaction exists and the user can
        // retry from the confirm screen.
        expect(failure, isA<SendTransactionConfirmationFailure>());
    }
  });
  for (final status in [
    PayjoinStatus.requested,
    PayjoinStatus.completed,
    PayjoinStatus.aborted,
  ]) {
    test(
      'resumes a $status payment without publishing another original',
      () async {
        final sender = _MockPayjoinSender();
        final sessions = _MockPayjoinSessions();
        final session = _session(status: status);
        final lifecycle = _MockPayjoinLifecycle();
        var current = session;
        when(lifecycle.resume).thenAnswer((_) async {
          current = _session(status: PayjoinStatus.completed);
          return const Ok(null);
        });
        when(
          () => sessions.byId(session.id),
        ).thenAnswer((_) async => Ok(current));

        final result = await _start(
          sender,
          sessions: sessions,
          lifecycle: lifecycle,
        );

        expect(
          (result as core.Ok<PayjoinSenderSession, SendFailure>).value,
          current,
        );
        verifyZeroInteractions(sender);
        if (status == PayjoinStatus.requested) {
          verify(lifecycle.resume).called(1);
          expect(current.status, PayjoinStatus.completed);
        } else {
          verifyZeroInteractions(lifecycle);
        }
      },
    );
  }

  test(
    'does not publish when the previous outcome cannot be checked',
    () async {
      final sender = _MockPayjoinSender();
      final sessions = _MockPayjoinSessions();
      when(
        () => sessions.byId(any()),
      ).thenAnswer((_) async => const Err(PayjoinStorageFailure()));

      final result = await _start(sender, sessions: sessions);

      expect(
        (result as core.Err<PayjoinSenderSession, SendFailure>).failure,
        isA<SendPersistenceFailure>(),
      );
      verifyZeroInteractions(sender);
    },
  );
}
