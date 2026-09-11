import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_send_signed_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVerifySignedTxUsecase extends Mock
    implements VerifySignedTxUsecase {}

void main() {
  test('maps verification failures to send failures', () async {
    final verifier = _MockVerifySignedTxUsecase();
    when(
      () => verifier.execute(
        unsignedPsbt: 'unsigned',
        signedTransaction: 'signed',
      ),
    ).thenAnswer(
      (_) async => const Err(
        SignedTransactionVerificationFailure('transaction mismatch'),
      ),
    );
    final usecase = VerifySendSignedTxUsecase(verifier);

    final result = await usecase.execute(
      unsignedPsbt: 'unsigned',
      signedTransaction: 'signed',
    );

    expect(result, isA<Err<void, SendFailure>>());
    final failure = (result as Err<void, SendFailure>).failure;
    expect(failure, isA<SendTransactionConfirmationFailure>());
    expect(failure.logMessage, 'transaction mismatch');
  });
}
