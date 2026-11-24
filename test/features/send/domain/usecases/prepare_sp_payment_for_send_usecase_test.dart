import 'package:fees/fees.dart';
import 'package:send/send.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:silent/silent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Sp extends Mock implements Silent {}

void main() {
  test('rejects an absolute fee before preparing a Silent Payment', () async {
    final sp = _Sp();
    when(
      () => sp.preparePayment(
        recipients: const [],
        feerateSatVb: BigInt.from(5000),
      ),
    ).thenAnswer((_) async => const Err(SilentUnexpected()));
    final result = await PrepareSpPaymentForSendUsecase(sp)
        .execute(recipients: const [], fee: const NetworkFee.absolute(5000));
    expect(
      result,
      isA<Err<SilentTxDraft, SendFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<SendTransactionBuildFailure>(),
      ),
    );
    verifyZeroInteractions(sp);
  });

  for (final fee in [
    null,
    const NetworkFee.relativeSatPerKwu(1),
    const NetworkFee.relativeSatPerKwu(500),
  ]) {
    test('preserves the relative fee and relay floor for $fee', () async {
      final sp = _Sp();
      final expected = fee == null || fee.value < 1 ? BigInt.one : BigInt.two;
      when(
        () => sp.preparePayment(recipients: const [], feerateSatVb: expected),
      ).thenAnswer((_) async => const Err(SilentUnexpected()));
      await PrepareSpPaymentForSendUsecase(sp)
          .execute(recipients: const [], fee: fee);
      verify(
        () => sp.preparePayment(recipients: const [], feerateSatVb: expected),
      ).called(1);
    });
  }
}
