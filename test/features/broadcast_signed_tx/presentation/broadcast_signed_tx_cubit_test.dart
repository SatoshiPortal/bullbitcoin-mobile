import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/verify_signed_tx_usecase.dart';
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

  const unsignedPsbt =
      'cHNidP8BAKQCAAAAA6DLc9RAdKwWQb/7Nrq1FyAtDQ3e0w5E4LkLpcrwBL0aAAAAAAD9////78NG2vqjywKaa0QHfo6C44o1+odXeWZ43FfHy4bLdxABAAAAAP3///8rhueJha90HzgJ6alnJ1uvi0Zbq0JQoXnwDb0Cjn79DwAAAAAA/f///wHWCBAAAAAAABYAFDraKFKubXzlSvRQy8V4X+TwKhLXAAAAAE8BBDWHzwQJeplqgAAAAqmHnnoRR+XJd7gJt/PhLazKeWAfCBLJ4/OF/s0PqqF1AzK8fcttOUsU2k9a6Valj6kLb/Bh2gB7YuxenNz7LY5PFJkKc60wAACAAQAAgAAAAIACAACATwEENYfPBEgFouKAAAACOeERUyCmIJuSdQNDB1mxkahw4tc2UCtjxJQoQGnRCtQCZUSXwQF+nA8dl/RG6U1b9ViWJxkzNrDCCagYEWch72cUrnhJ4jAAAIABAACAAAAAgAIAAIAAAQErckUPAAAAAAAiACDwHjagvyTvVDVn+RqxW0xaMLODBm2IVCwDBQm5uK8rDQEFR1IhAi/hk/Tz0aHcNwsVyv86bqQj30sUexPlc738CqJg+flLIQKmgeTdVjPh9P+MPnsTPbFRcGGLPAO3iTyYBR7eYQC4VlKuIgYCL+GT9PPRodw3CxXK/zpupCPfSxR7E+VzvfwKomD5+UscrnhJ4jAAAIABAACAAAAAgAIAAIABAAAACgAAACIGAqaB5N1WM+H0/4w+exM9sVFwYYs8A7eJPJgFHt5hALhWHJkKc60wAACAAQAAgAAAAIACAACAAQAAAAoAAAAAAQErMHUAAAAAAAAiACAUS+ztgOw4wxEOYDdQEZp42Ii3sA39MdXZMWolM3s9VgEFR1IhAmdcnz6cgLhxNS0Lv3mz7OVOGunGsAlEsekZiQRDLDXHIQLfPg77+MKPe073vgkXRfWAZMxohe3ysPahJ0jIFl3GU1KuIgYCZ1yfPpyAuHE1LQu/ebPs5U4a6cawCUSx6RmJBEMsNcccrnhJ4jAAAIABAACAAAAAgAIAAIAAAAAAQgAAACIGAt8+Dvv4wo97Tve+CRdF9YBkzGiF7fKw9qEnSMgWXcZTHJkKc60wAACAAQAAgAAAAIACAACAAAAAAEIAAAAAAQEr8FUAAAAAAAAiACCcheUwIAj6XLtEe5QO+fTi25/ZvJGX9MuZkpghbW3VMgEFR1IhAkhWBpUeAB+UbbJc8f1fkEMEZgIChQVpMdJnD05uBtU4IQMUAdnwr2UVz6AhNBI5j6an4wHRGVX3uhSLaWy2qS70xlKuIgYCSFYGlR4AH5Rtslzx/V+QQwRmAgKFBWkx0mcPTm4G1TgcmQpzrTAAAIABAACAAAAAgAIAAIAAAAAARAAAACIGAxQB2fCvZRXPoCE0EjmPpqfjAdEZVfe6FItpbLapLvTGHK54SeIwAACAAQAAgAAAAIACAACAAAAAAEQAAAAAAA==';
  const firstSignedTrimmedPsbt =
      'cHNidP8BAKQCAAAAA6DLc9RAdKwWQb/7Nrq1FyAtDQ3e0w5E4LkLpcrwBL0aAAAAAAD9////78NG2vqjywKaa0QHfo6C44o1+odXeWZ43FfHy4bLdxABAAAAAP3///8rhueJha90HzgJ6alnJ1uvi0Zbq0JQoXnwDb0Cjn79DwAAAAAA/f///wHWCBAAAAAAABYAFDraKFKubXzlSvRQy8V4X+TwKhLXAAAAAAAiAgKmgeTdVjPh9P+MPnsTPbFRcGGLPAO3iTyYBR7eYQC4VkcwRAIga3QJaZWl+pwWMjMc2PjxNIeFHeg6TF5bb57VYY5qg5cCIGRT9zijaAwbPkBMDqmKQSjEmqWSiAEDkRznqZYggIRGAQAiAgLfPg77+MKPe073vgkXRfWAZMxohe3ysPahJ0jIFl3GU0cwRAIgFEHGf3EbOMs/MPoWmbm/rBqSKyaST4XC+7WLqEsukgUCIFtimNwjtrGq4oI0QbIfJNC2HuedHKE9PyO7HULWTUfHAQAiAgJIVgaVHgAflG2yXPH9X5BDBGYCAoUFaTHSZw9ObgbVOEcwRAIgAsQjpMwk1Hz+LOIc4WWcR4dGA7h/IIqUPpqvVZup1HgCIDkKf/vx5xUQnI3ISjv5/vMd5qpXkMdy6mv8bnn881/pAQAA';
  const secondSignedTrimmedPsbt =
      'cHNidP8BAKQCAAAAA6DLc9RAdKwWQb/7Nrq1FyAtDQ3e0w5E4LkLpcrwBL0aAAAAAAD9////78NG2vqjywKaa0QHfo6C44o1+odXeWZ43FfHy4bLdxABAAAAAP3///8rhueJha90HzgJ6alnJ1uvi0Zbq0JQoXnwDb0Cjn79DwAAAAAA/f///wHWCBAAAAAAABYAFDraKFKubXzlSvRQy8V4X+TwKhLXAAAAAAAiAgIv4ZP089Gh3DcLFcr/Om6kI99LFHsT5XO9/AqiYPn5S0cwRAIgMJcGjoczA/ht/oTuE30a5StXa9l72t5+jayaURudfnECIGw+ymYS2RDszHL+KXRuoiNjvAUiIIKE7wa7+RKORevBAQAiAgJnXJ8+nIC4cTUtC795s+zlThrpxrAJRLHpGYkEQyw1x0cwRAIgH5pFuC079UUXzPJU1ya57Lak9Yc4NkAttmOEsNphd/cCIBnVkzO/wVfD5dxWKXbqdHazwUirh2zcY1MIH1skRqkbAQAiAgMUAdnwr2UVz6AhNBI5j6an4wHRGVX3uhSLaWy2qS70xkcwRAIgVrv+vZ9iG1njv8wrSCuhhLIlkMRqk4lxnHBRMHTzVWUCIELRLHVXUTyL0rFWA8aNADWjkOB/pepeQst7u2GryIylAQAA';

  test('finalizes a SeedSigner-trimmed PSBT before broadcasting', () async {
    final signedTrimmedPsbt = bdk.Psbt(
      psbtBase64: firstSignedTrimmedPsbt,
    ).combine(other: bdk.Psbt(psbtBase64: secondSignedTrimmedPsbt)).serialize();
    final broadcast = _MockBroadcastBitcoinTransactionUsecase();
    when(
      () => broadcast.execute(any(), isPsbt: any(named: 'isPsbt')),
    ).thenAnswer((_) async => 'txid');
    final cubit = BroadcastSignedTxCubit(
      broadcastBitcoinTransactionUsecase: broadcast,
      verifySignedTxUsecase: VerifyBroadcastSignedTxUsecase(
        VerifySignedTxUsecase(),
      ),
      unsignedPsbt: unsignedPsbt,
    );
    addTearDown(cubit.close);

    await cubit.onQrScanned(signedTrimmedPsbt);

    expect(cubit.state.failure, isNull);
    expect(cubit.state.transaction?.format, TxFormat.hex);
    final finalizedTransaction = cubit.state.transaction!.data;
    expect(finalizedTransaction, startsWith('02000000000103'));
    expect(finalizedTransaction.length, greaterThan(500));

    await cubit.broadcastTransaction();

    verify(
      () => broadcast.execute(finalizedTransaction, isPsbt: false),
    ).called(1);
    expect(cubit.state.isBroadcasted, isTrue);
  });

  test('rejects a combined PSBT that cannot be finalized', () async {
    final cubit = BroadcastSignedTxCubit(
      broadcastBitcoinTransactionUsecase:
          _MockBroadcastBitcoinTransactionUsecase(),
      verifySignedTxUsecase: VerifyBroadcastSignedTxUsecase(
        VerifySignedTxUsecase(),
      ),
      unsignedPsbt: unsignedPsbt,
    );
    addTearDown(cubit.close);

    await cubit.onQrScanned(firstSignedTrimmedPsbt);

    expect(cubit.state.transaction, isNull);
    expect(cubit.state.failure, isA<PsbtFinalizationFailure>());
  });
}
