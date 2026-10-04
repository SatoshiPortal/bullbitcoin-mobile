import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/sell/domain/prepare_sell_bitcoin_payin_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockPrepareBitcoinSend extends Mock
    implements PrepareBitcoinSendUsecase {}

class _MockCalculateBitcoinFees extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

const _rawReason = 'BdkException: InsufficientFunds needed 12345 sat';

void main() {
  late _MockPrepareBitcoinSend prepare;
  late _MockCalculateBitcoinFees calculateFees;
  late PrepareSellBitcoinPayinUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const NetworkFee.relativeSatPerKwu(1));
  });

  setUp(() {
    prepare = _MockPrepareBitcoinSend();
    calculateFees = _MockCalculateBitcoinFees();
    usecase = PrepareSellBitcoinPayinUsecase(
      prepareBitcoinSendUsecase: prepare,
      calculateBitcoinAbsoluteFeesUsecase: calculateFees,
    );
  });

  Future<Result<PreparedSellBitcoinPayin, SellFailure>> run() =>
      usecase.execute(
        walletId: 'wallet-1',
        address: 'bc1qdestination',
        networkFee: const NetworkFee.relativeSatPerKwu(2),
        amountSat: 100000,
      );

  void stubPrepare() {
    when(
      () => prepare.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenAnswer(
      (_) async => (unsignedPsbt: 'psbt', txSize: 110, isToSelf: false),
    );
  }

  test('returns the psbt together with its real fee', () async {
    stubPrepare();
    when(
      () => calculateFees.execute(psbt: any(named: 'psbt')),
    ).thenAnswer((_) async => 220);

    final value =
        (await run() as Ok<PreparedSellBitcoinPayin, SellFailure>).value;

    // Grouped on purpose: a psbt without its fee cannot be shown or committed.
    expect(value.unsignedPsbt, 'psbt');
    expect(value.txSize, 110);
    expect(value.absoluteFees, 220);
  });

  test('sanitizes a build failure', () async {
    when(
      () => prepare.execute(
        walletId: any(named: 'walletId'),
        address: any(named: 'address'),
        networkFee: any(named: 'networkFee'),
        amountSat: any(named: 'amountSat'),
        drain: any(named: 'drain'),
        selectedInputs: any(named: 'selectedInputs'),
        replaceByFee: any(named: 'replaceByFee'),
      ),
    ).thenThrow(Exception(_rawReason));

    final result = await run();

    switch (result) {
      case Ok():
        fail('a failed build must not yield a psbt');
      case Err(:final failure):
        expect(failure, isA<SellUnexpectedFailure>());
        expect(failure.logMessage, contains('InsufficientFunds'));
    }
  });

  test('a fee-measurement failure fails the whole build', () async {
    stubPrepare();
    when(
      () => calculateFees.execute(psbt: any(named: 'psbt')),
    ).thenThrow(Exception(_rawReason));

    expect(
      await run(),
      isA<Err<PreparedSellBitcoinPayin, SellFailure>>(),
      reason: 'a psbt whose fee is unknown must not reach the confirm screen',
    );
  });
}
