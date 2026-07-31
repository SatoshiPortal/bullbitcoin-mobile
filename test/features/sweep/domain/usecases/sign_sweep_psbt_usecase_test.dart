import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_send_port.dart';
import 'package:bb_mobile/features/sweep/domain/sweep_failure.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/sign_sweep_psbt_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBitcoinSendPort extends Mock implements BitcoinSendPort {}

void main() {
  late _MockBitcoinSendPort sendPort;
  late SignSweepPsbtUsecase usecase;

  setUp(() {
    sendPort = _MockBitcoinSendPort();
    usecase = SignSweepPsbtUsecase(bitcoinSendPort: sendPort);
    when(
      () => sendPort.signPsbt('unsigned', walletId: 'wallet-1'),
    ).thenAnswer((_) async => 'signed');
  });

  test('returns the signed psbt when its finalized rate clears relay', () async {
    when(
      () => sendPort.getTxSize(psbt: 'signed'),
    ).thenAnswer((_) async => 141);
    when(
      () => sendPort.getTxFeeAmount(psbt: 'signed'),
    ).thenAnswer((_) async => 20);

    final result = await usecase.execute(
      walletId: 'wallet-1',
      unsignedPsbt: 'unsigned',
      floorSatPerKwu: 25,
    );

    expect((result as Ok<String, SweepFailure>).value, 'signed');
  });

  test('rejects a signed psbt below the relay floor', () async {
    when(
      () => sendPort.getTxSize(psbt: 'signed'),
    ).thenAnswer((_) async => 141);
    when(
      () => sendPort.getTxFeeAmount(psbt: 'signed'),
    ).thenAnswer((_) async => 10);

    final result = await usecase.execute(
      walletId: 'wallet-1',
      unsignedPsbt: 'unsigned',
      floorSatPerKwu: 25,
    );

    expect(
      (result as Err<String, SweepFailure>).failure,
      isA<SweepFeeTooLowFailure>(),
    );
  });

  test('maps signing exceptions to a feature failure', () async {
    when(
      () => sendPort.signPsbt('unsigned', walletId: 'wallet-1'),
    ).thenThrow(Exception('signing failed'));

    final result = await usecase.execute(
      walletId: 'wallet-1',
      unsignedPsbt: 'unsigned',
    );

    expect(
      (result as Err<String, SweepFailure>).failure,
      isA<SweepSignFailure>(),
    );
  });
}
