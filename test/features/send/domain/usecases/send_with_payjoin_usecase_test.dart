import 'package:bb_mobile/features/send/domain/usecases/retry_payjoin_proposal_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart' as core;
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/send_with_payjoin_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPayjoinSender extends Mock implements PayjoinSender {}

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

Future<core.Result<PayjoinSenderSession, SendFailure>> _start(
  PayjoinSender sender,
) => SendWithPayjoinUsecase(sender).execute(
  walletId: 'wallet-1',
  network: BitcoinNetwork.mainnet,
  bip21: 'bitcoin:bc1qaddress?pj=https://payjo.in/session',
  unsignedOriginalPsbt: 'cHNidP8=',
  amountSat: 10000,
  networkFeesSatPerVb: 2,
);

void main() {
  test(
    'proposal retry forwards only the retained session id and maps refusal',
    () async {
      final sender = _MockPayjoinSender();
      when(
        () => sender.retryProposal('same-session'),
      ).thenAnswer((_) async => const Err(PayjoinSpendBlockedFailure()));
      final result = await RetryPayjoinProposalUsecase(
        sender,
      ).execute('same-session');
      expect(result, isA<core.Err<PayjoinSession, SendFailure>>());
      expect((result as core.Err).failure, isA<SendPayjoinPausedFailure>());
      verify(() => sender.retryProposal('same-session')).called(1);
      verifyNoMoreInteractions(sender);
    },
  );

  test('regtest is refused before creating a sender session', () async {
    final sender = _MockPayjoinSender();
    final result = await SendWithPayjoinUsecase(sender).execute(
      walletId: 'regtest-wallet',
      network: BitcoinNetwork.regtest,
      bip21: 'bitcoin:bcrt1unused?pj=https://example.invalid',
      unsignedOriginalPsbt: 'unused',
      amountSat: 10000,
      networkFeesSatPerVb: 1,
    );
    expect(
      (result as core.Err).failure,
      isA<SendTransactionConfirmationFailure>(),
    );
    verifyZeroInteractions(sender);
  });

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

  for (final busy in [true, false]) {
    test('a refused spend keeps its reason: busy=$busy', () async {
      final sender = _MockPayjoinSender();
      when(() => sender.start(any())).thenAnswer(
        (_) async => Err<PayjoinSenderSession, PayjoinFailure>(
          PayjoinSpendBlockedFailure(busy: busy),
        ),
      );

      final result = await _start(sender);

      expect(
        (result as core.Err).failure,
        isA<SendSpendBlockedFailure>().having((f) => f.busy, 'busy', busy),
      );
    });
  }

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
}
