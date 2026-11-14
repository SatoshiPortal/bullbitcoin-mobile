import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/send/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/features/send/public/send_facade.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockVerifySignedTxUsecase extends Mock
    implements VerifySignedTxUsecase {}

void main() {
  test('maps verification failures to broadcast failures', () async {
    final verifier = _MockVerifySignedTxUsecase();
    when(
      () => verifier.execute(
        unsignedPsbt: 'unsigned',
        signedTransaction: 'signed',
        isPsbt: true,
      ),
    ).thenAnswer(
      (_) async => const Err(
        SendTransactionConfirmationFailure(logMessage: 'transaction mismatch'),
      ),
    );
    final usecase = VerifyBroadcastSignedTxUsecase(
      SendFacade(
        bitcoin: (_, {required walletId, required isPsbt, required network}) =>
            throw UnimplementedError('verification only'),
        liquid: (_) => throw UnimplementedError('verification only'),
        verifySignedTxUsecase: verifier,
      ),
    );

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
