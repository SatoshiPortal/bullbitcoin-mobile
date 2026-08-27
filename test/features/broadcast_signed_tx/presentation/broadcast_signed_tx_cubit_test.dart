import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/verify_broadcast_signed_tx_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

class _MockVerifySignedTxUsecase extends Mock
    implements VerifyBroadcastSignedTxUsecase {}

void main() {
  const psbt =
      'cHNidP8BAFICAAAAARERERERERERERERERERERERERERERERERERERERERERAAAAAAD9////'
      'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
      'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

  test('maps signed transaction verification failures', () async {
    final verifier = _MockVerifySignedTxUsecase();
    when(
      () => verifier.execute(
        unsignedPsbt: psbt,
        signedTransaction: psbt,
        isPsbt: true,
      ),
    ).thenAnswer(
      (_) async => const Err(InvalidTransactionFailure('transaction mismatch')),
    );
    final cubit = BroadcastSignedTxCubit(
      broadcastBitcoinTransactionUsecase:
          _MockBroadcastBitcoinTransactionUsecase(),
      verifySignedTxUsecase: verifier,
      unsignedPsbt: psbt,
    );
    addTearDown(cubit.close);

    await cubit.tryParseTransaction(psbt);

    expect(cubit.state.transaction, isNull);
    expect(cubit.state.failure, isA<InvalidTransactionFailure>());
    verify(
      () => verifier.execute(
        unsignedPsbt: psbt,
        signedTransaction: psbt,
        isPsbt: true,
      ),
    ).called(1);
  });

  test('allows programmer errors from verification to propagate', () async {
    final verifier = _MockVerifySignedTxUsecase();
    when(
      () => verifier.execute(
        unsignedPsbt: psbt,
        signedTransaction: psbt,
        isPsbt: true,
      ),
    ).thenThrow(StateError('programmer defect'));
    final cubit = BroadcastSignedTxCubit(
      broadcastBitcoinTransactionUsecase:
          _MockBroadcastBitcoinTransactionUsecase(),
      verifySignedTxUsecase: verifier,
      unsignedPsbt: psbt,
    );
    addTearDown(cubit.close);

    await expectLater(
      cubit.tryParseTransaction(psbt),
      throwsA(isA<StateError>()),
    );

    expect(cubit.state.transaction, isNull);
    expect(cubit.state.failure, isNull);
  });

  test('parses transaction hex before verification', () async {
    final parsedPsbt = bdk.Psbt(psbtBase64: psbt);
    final extractedTx = parsedPsbt.extractTx();
    final rawTx = hex.encode(extractedTx.serialize());
    extractedTx.dispose();
    parsedPsbt.dispose();

    final verifier = _MockVerifySignedTxUsecase();
    when(
      () => verifier.execute(
        unsignedPsbt: psbt,
        signedTransaction: rawTx,
        isPsbt: false,
      ),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = BroadcastSignedTxCubit(
      broadcastBitcoinTransactionUsecase:
          _MockBroadcastBitcoinTransactionUsecase(),
      verifySignedTxUsecase: verifier,
      unsignedPsbt: psbt,
    );
    addTearDown(cubit.close);

    await cubit.tryParseTransaction(rawTx);

    expect(cubit.state.transaction?.format, TxFormat.hex);
    expect(cubit.state.failure, isNull);
  });

  test(
    'standalone transaction import does not require an original PSBT',
    () async {
      final verifier = _MockVerifySignedTxUsecase();
      final cubit = BroadcastSignedTxCubit(
        broadcastBitcoinTransactionUsecase:
            _MockBroadcastBitcoinTransactionUsecase(),
        verifySignedTxUsecase: verifier,
      );
      addTearDown(cubit.close);

      await cubit.tryParseTransaction(psbt);

      expect(cubit.state.transaction, isNotNull);
      expect(cubit.state.failure, isNull);
      verifyNever(
        () => verifier.execute(
          unsignedPsbt: any(named: 'unsignedPsbt'),
          signedTransaction: any(named: 'signedTransaction'),
          isPsbt: any(named: 'isPsbt'),
        ),
      );
    },
  );
}
