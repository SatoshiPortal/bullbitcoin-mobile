import 'package:receive/receive.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_swap_limits_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

class _Limits extends Mock implements GetSwapLimitsAndFeesUsecase {}

void main() {
  for (final liquid in [false, true]) {
    test(
      'loads limits for the admitted ${liquid ? 'Liquid' : 'Bitcoin'} chain',
      () async {
        final limits = _Limits();
        final type = liquid
            ? SwapType.lightningToLiquid
            : SwapType.lightningToBitcoin;
        when(() => limits.execute(type)).thenAnswer(
          (_) async => const Ok((
            SwapLimits(min: 1000, max: 100000),
            SwapFees(boltzPercent: 0.5),
          )),
        );
        final result = await GetReceiveSwapLimitsUsecase(limits)
            .execute(isLiquid: liquid);
        expect(result, isA<Ok<SwapLimits, ReceiveFailure>>());
        if (result case Ok(:final value)) {
          expect(value.min, 1000);
          expect(value.max, 100000);
        }
        verify(() => limits.execute(type)).called(1);
      },
    );
  }

  test('maps a provider lookup failure to the receive boundary', () async {
    final limits = _Limits();
    when(() => limits.execute(SwapType.lightningToLiquid)).thenAnswer(
      (_) async => const Err(SwapsBoltzUnavailableFailure('unavailable')),
    );
    expect(
      await GetReceiveSwapLimitsUsecase(limits).execute(isLiquid: true),
      isA<Err<SwapLimits, ReceiveFailure>>(),
    );
  });
}
