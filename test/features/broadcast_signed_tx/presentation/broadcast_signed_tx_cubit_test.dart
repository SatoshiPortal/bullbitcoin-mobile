import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/type.dart';
import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/presentation/broadcast_signed_tx_cubit.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBroadcastBitcoinTransactionUsecase extends Mock
    implements BroadcastBitcoinTransactionUsecase {}

void main() {
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
      request: const BroadcastSignedTxRequest(unsignedPsbt: unsignedPsbt),
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
      request: const BroadcastSignedTxRequest(unsignedPsbt: unsignedPsbt),
    );
    addTearDown(cubit.close);

    await cubit.onQrScanned(firstSignedTrimmedPsbt);

    expect(cubit.state.transaction, isNull);
    expect(cubit.state.failure, isA<PsbtFinalizationFailure>());
  });

  late _MockBroadcastBitcoinTransactionUsecase broadcastUsecase;

  setUp(() {
    broadcastUsecase = _MockBroadcastBitcoinTransactionUsecase();
  });

  BroadcastSignedTxCubit buildCubit() => BroadcastSignedTxCubit(
    broadcastBitcoinTransactionUsecase: broadcastUsecase,
    request: const BroadcastSignedTxRequest(collectSignerResult: true),
  );

  group('signer result collection', () {
    test('stores the signer result for authoritative validation', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.tryParseTransaction('signer-result');

      expect(cubit.state.collectedSignerResult, 'signer-result');
      expect(cubit.state.failure, isNull);
    });

    test('collects a non-BBQR signer QR directly', () async {
      final cubit = buildCubit();
      addTearDown(cubit.close);

      await cubit.onQrScanned('signer-result');

      expect(cubit.state.collectedSignerResult, 'signer-result');
    });
  });
}
