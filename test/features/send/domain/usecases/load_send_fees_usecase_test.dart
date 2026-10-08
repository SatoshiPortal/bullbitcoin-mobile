import 'package:bb_mobile/core/fees/domain/fees_entity.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/load_send_fees_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetNetworkFeesUsecase extends Mock
    implements GetNetworkFeesUsecase {}

void main() {
  late _MockGetNetworkFeesUsecase getNetworkFeesUsecase;
  late LoadSendFeesUsecase usecase;

  const liquidFees = FeeOptions(
    fastest: RelativeFee(25),
    economic: RelativeFee(25),
    slow: RelativeFee(25),
    minRelay: RelativeFee(25),
  );
  const liveBitcoinFees = FeeOptions(
    fastest: RelativeFee(1000),
    economic: RelativeFee(750),
    slow: RelativeFee(500),
    minRelay: RelativeFee(250),
  );
  const previousBitcoinFees = FeeOptions(
    fastest: RelativeFee(2000),
    economic: RelativeFee(1500),
    slow: RelativeFee(1000),
    minRelay: RelativeFee(250),
  );

  setUp(() {
    getNetworkFeesUsecase = _MockGetNetworkFeesUsecase();
    usecase = LoadSendFeesUsecase(getNetworkFeesUsecase);
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: true),
    ).thenAnswer((_) async => liquidFees);
  });

  test('returns live Bitcoin rates and canonical Liquid rates', () async {
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: false),
    ).thenAnswer((_) async => liveBitcoinFees);

    final result = await usecase.execute();
    expect(result, isA<Ok<SendFeeRates, SendFailure>>());
    final rates = (result as Ok<SendFeeRates, SendFailure>).value;

    expect(rates.bitcoin, liveBitcoinFees);
    expect(rates.liquid, liquidFees);
    expect(rates.usingFallbackBitcoinFees, isFalse);
  });

  test('uses one sat/vbyte Bitcoin rates when no live rates exist', () async {
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: false),
    ).thenThrow(GetNetworkFeesException('mempool unavailable'));

    final result = await usecase.execute();
    expect(result, isA<Ok<SendFeeRates, SendFailure>>());
    final rates = (result as Ok<SendFeeRates, SendFailure>).value;

    expect(rates.bitcoin.fastest, const RelativeFee(250));
    expect(rates.bitcoin.economic, const RelativeFee(250));
    expect(rates.bitcoin.slow, const RelativeFee(250));
    expect(rates.bitcoin.minRelay, const RelativeFee(25));
    expect(rates.liquid, liquidFees);
    expect(rates.usingFallbackBitcoinFees, isTrue);
  });

  test('preserves previously loaded Bitcoin rates on fetch failure', () async {
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: false),
    ).thenThrow(GetNetworkFeesException('mempool unavailable'));

    final result = await usecase.execute(
      previousBitcoinFees: previousBitcoinFees,
    );
    expect(result, isA<Ok<SendFeeRates, SendFailure>>());
    final rates = (result as Ok<SendFeeRates, SendFailure>).value;

    expect(rates.bitcoin, previousBitcoinFees);
    expect(rates.liquid, liquidFees);
    expect(rates.usingFallbackBitcoinFees, isTrue);
  });

  test('preserves Liquid rates when refreshing them fails', () async {
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: true),
    ).thenThrow(GetNetworkFeesException('settings unavailable'));
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: false),
    ).thenAnswer((_) async => liveBitcoinFees);

    final result = await usecase.execute(previousLiquidFees: liquidFees);
    expect(result, isA<Ok<SendFeeRates, SendFailure>>());
    final rates = (result as Ok<SendFeeRates, SendFailure>).value;

    expect(rates.bitcoin, liveBitcoinFees);
    expect(rates.liquid, liquidFees);
    expect(rates.usingFallbackBitcoinFees, isFalse);
  });

  test('maps a Liquid fee failure when no prior rates exist', () async {
    when(
      () => getNetworkFeesUsecase.execute(isLiquid: true),
    ).thenThrow(GetNetworkFeesException('settings unavailable'));

    final result = await usecase.execute();

    expect(result, isA<Err<SendFeeRates, SendFailure>>());
    expect(
      (result as Err<SendFeeRates, SendFailure>).failure,
      isA<SendFeesUnavailableFailure>(),
    );
    verifyNever(() => getNetworkFeesUsecase.execute(isLiquid: false));
  });
}
