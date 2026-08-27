import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/verify_signed_tx_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
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
        SignedTransactionVerificationFailure('transaction mismatch'),
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
