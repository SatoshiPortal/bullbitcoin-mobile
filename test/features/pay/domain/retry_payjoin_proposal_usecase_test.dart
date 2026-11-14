import 'package:bb_mobile/features/pay/domain/pay_failure.dart';
import 'package:bb_mobile/features/pay/domain/retry_payjoin_proposal_usecase.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Sender extends Mock implements PayjoinSender {}

void main() {
  test(
    'retries the same session and maps refusal to a feature failure',
    () async {
      final sender = _Sender();
      final session = PayjoinSenderSession(
        status: PayjoinStatus.proposed,
        uri: 'bitcoin:fixture?pj=https://example.com',
        network: BitcoinNetwork.testnet,
        walletId: 'wallet',
        createdAt: DateTime(2026),
        expiresAt: DateTime(2027),
        amount: Sats.fromInt(1000),
        originalTransactionId: 'original',
        hasProposal: true,
        spendFailure: const PayjoinSpendBlockedFailure(),
      );
      final usecase = RetryPayjoinProposalUsecase(sender);
      when(
        () => sender.retryProposal(session.id),
      ).thenAnswer((_) async => Ok(session));
      final result = await usecase.execute(session.id);
      expect((result as Ok<PayjoinSession, PayFailure>).value, same(session));
      when(
        () => sender.retryProposal(session.id),
      ).thenAnswer((_) async => const Err(PayjoinSpendBlockedFailure()));
      final refusal = await usecase.execute(session.id);
      expect(
        (refusal as Err<PayjoinSession, PayFailure>).failure,
        isA<PayPayjoinPausedFailure>(),
      );
      verify(() => sender.retryProposal(session.id)).called(2);
      verifyNoMoreInteractions(sender);
    },
  );
}
