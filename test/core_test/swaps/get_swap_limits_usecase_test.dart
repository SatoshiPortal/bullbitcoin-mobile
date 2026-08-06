import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_swap_limits_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not contact the disabled legacy provider', () async {
    const usecase = GetSwapLimitsUsecase();

    await expectLater(
      usecase.execute(type: SwapType.liquidToBitcoin),
      throwsA(isA<GetSwapLimitsException>()),
    );
  });
}
