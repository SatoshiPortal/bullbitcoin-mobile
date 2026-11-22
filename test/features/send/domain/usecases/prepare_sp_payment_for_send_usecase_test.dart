import 'package:fees/fees.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_sp_payment_for_send_usecase.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _Sp extends Mock implements SpFacade {}

void main() {
  test('rejects an absolute fee before preparing a Silent Payment', () async {
    final sp = _Sp();
    when(
      () => sp.preparePayment(
        recipients: const [],
        feerateSatVb: BigInt.from(5000),
      ),
    ).thenAnswer((_) async => const Err(SpUnexpected()));
    final result = await PrepareSpPaymentForSendUsecase(sp)
        .execute(recipients: const [], fee: const NetworkFee.absolute(5000));
    expect(
      result,
      isA<Err<SpTxDraft, SendFailure>>().having(
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
      ).thenAnswer((_) async => const Err(SpUnexpected()));
      await PrepareSpPaymentForSendUsecase(sp)
          .execute(recipients: const [], fee: fee);
      verify(
        () => sp.preparePayment(recipients: const [], feerateSatVb: expected),
      ).called(1);
    });
  }
}
