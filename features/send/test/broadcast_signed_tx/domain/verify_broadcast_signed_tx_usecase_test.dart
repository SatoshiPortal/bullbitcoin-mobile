import 'package:primitives/primitives.dart';
import 'package:send/src/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:send/src/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spend/spend.dart';
import 'package:spend/testing.dart';

class _RefusingSpend extends FakeSpend {
  @override
  Result<void, SpendFailure> verifyExternalBitcoin({
    required String unsignedPsbt,
    required String signedTransaction,
    required bool isPsbt,
  }) => const Err(SpendSignedTransactionMismatchFailure());
}

void main() {
  test('maps verification failures to broadcast failures', () async {
    final usecase = VerifyBroadcastSignedTxUsecase(_RefusingSpend());

    final result = await usecase.execute(
      unsignedPsbt: 'unsigned',
      signedTransaction: 'signed',
      isPsbt: true,
    );

    expect(result, isA<Err<void, BroadcastSignedTxFailure>>());
    final failure = (result as Err<void, BroadcastSignedTxFailure>).failure;
    expect(failure, isA<InvalidTransactionFailure>());
    expect(failure.logMessage, isNull);
  });
}
