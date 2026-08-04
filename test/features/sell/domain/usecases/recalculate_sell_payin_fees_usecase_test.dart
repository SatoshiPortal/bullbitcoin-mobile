import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_address.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/prepare_bitcoin_send_usecase.dart';
import 'package:bb_mobile/features/sell/domain/sell_failure.dart';
import 'package:bb_mobile/features/sell/domain/usecases/recalculate_sell_payin_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/calculate_liquid_absolute_fees_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/prepare_liquid_send_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAddressAtIndexUsecase extends Mock
    implements GetAddressAtIndexUsecase {}

class MockGetNetworkFeesUsecase extends Mock implements GetNetworkFeesUsecase {}

class MockPrepareBitcoinSendUsecase extends Mock
    implements PrepareBitcoinSendUsecase {}

class MockPrepareLiquidSendUsecase extends Mock
    implements PrepareLiquidSendUsecase {}

class MockCalculateBitcoinAbsoluteFeesUsecase extends Mock
    implements CalculateBitcoinAbsoluteFeesUsecase {}

class MockCalculateLiquidAbsoluteFeesUsecase extends Mock
    implements CalculateLiquidAbsoluteFeesUsecase {}

class MockWallet extends Mock implements Wallet {}

class MockFeeOptions extends Mock implements FeeOptions {}

void main() {
  late MockGetAddressAtIndexUsecase getAddress;
  late MockGetNetworkFeesUsecase getNetworkFees;
  late MockPrepareBitcoinSendUsecase prepareBitcoin;
  late MockPrepareLiquidSendUsecase prepareLiquid;
  late MockCalculateBitcoinAbsoluteFeesUsecase calculateBitcoin;
  late MockCalculateLiquidAbsoluteFeesUsecase calculateLiquid;
  late RecalculateSellPayinFeesUsecase usecase;

  setUpAll(() {
    registerFallbackValue(const RelativeFee(1));
  });

  setUp(() {
    getAddress = MockGetAddressAtIndexUsecase();
    getNetworkFees = MockGetNetworkFeesUsecase();
    prepareBitcoin = MockPrepareBitcoinSendUsecase();
    prepareLiquid = MockPrepareLiquidSendUsecase();
    calculateBitcoin = MockCalculateBitcoinAbsoluteFeesUsecase();
    calculateLiquid = MockCalculateLiquidAbsoluteFeesUsecase();
    usecase = RecalculateSellPayinFeesUsecase(
      getAddressAtIndexUsecase: getAddress,
      getNetworkFeesUsecase: getNetworkFees,
      prepareBitcoinSendUsecase: prepareBitcoin,
      prepareLiquidSendUsecase: prepareLiquid,
      calculateBitcoinAbsoluteFeesUsecase: calculateBitcoin,
      calculateLiquidAbsoluteFeesUsecase: calculateLiquid,
    );

    final address = WalletAddress(
      walletId: 'wallet-1',
      index: 0,
      address: 'bc1qtest',
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    when(
      () => getAddress.execute(
        walletId: any(named: 'walletId'),
        index: any(named: 'index'),
      ),
    ).thenAnswer((_) async => address);
  });

  Wallet wallet({required bool isLiquid}) {
    final w = MockWallet();
    when(() => w.id).thenReturn('wallet-1');
    when(() => w.isLiquid).thenReturn(isLiquid);
    return w;
  }

  group('RecalculateSellPayinFeesUsecase', () {
    test('returns Ok(fees) on the bitcoin path', () async {
      final feeOptions = MockFeeOptions();
      when(() => feeOptions.fastest).thenReturn(const RelativeFee(2));
      when(
        () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
      ).thenAnswer((_) async => feeOptions);
      when(
        () => prepareBitcoin.execute(
          walletId: any(named: 'walletId'),
          address: any(named: 'address'),
          amountSat: any(named: 'amountSat'),
          networkFee: any(named: 'networkFee'),
          selectedInputs: any(named: 'selectedInputs'),
          replaceByFee: any(named: 'replaceByFee'),
        ),
      ).thenAnswer(
        (_) async => (unsignedPsbt: 'psbt', txSize: 110, isToSelf: false),
      );
      when(
        () => calculateBitcoin.execute(psbt: any(named: 'psbt')),
      ).thenAnswer((_) async => 321);

      final result = await usecase.execute(
        wallet: wallet(isLiquid: false),
        amountSat: 50000,
      );

      expect(result, isA<Ok>());
      expect((result as Ok).value, 321);
    });

    test(
      'maps an infrastructure throw to SellPrepareTransactionFailure — raw in logMessage only, no leak',
      () async {
        when(
          () => getNetworkFees.execute(isLiquid: any(named: 'isLiquid')),
        ).thenThrow(Exception('fee svc boom'));

        final result = await usecase.execute(
          wallet: wallet(isLiquid: false),
          amountSat: 50000,
        );

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<SellPrepareTransactionFailure>());
        expect(
          (failure as SellPrepareTransactionFailure).logMessage,
          contains('fee svc boom'),
        );
      },
    );
  });
}
