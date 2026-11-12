import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSendFacade extends Mock implements SendFacade {}

void main() {
  test('maps verification failures to broadcast failures', () async {
    final verifier = _MockSendFacade();
    when(
      () => verifier.verifySignedTransaction(
        unsignedPsbt: 'unsigned',
        signedTransaction: 'signed',
        isPsbt: true,
      ),
    ).thenAnswer(
      (_) async => const Err(
        SendTransactionConfirmationFailure(logMessage: 'transaction mismatch'),
      ),
    );
    final usecase = VerifyBroadcastSignedTxUsecase(verifier);

    final result = await usecase.execute(
      unsignedPsbt: 'unsigned',
      signedTransaction: 'signed',
      isPsbt: true,
    );

    expect(result, isA<Err<void, BroadcastSignedTxFailure>>());
    final failure = (result as Err<void, BroadcastSignedTxFailure>).failure;
    expect(failure, isA<InvalidTransactionFailure>());
    expect(failure.logMessage, 'transaction mismatch');
  });
}
