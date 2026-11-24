import 'package:swap_feature/swap_feature.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/retry_swaps_on_refresh_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapActivity extends Mock implements SwapActivity {}

void main() {
  test('a refresh retries the ongoing swaps through the swap facade', () async {
    final swaps = _MockSwapActivity();
    when(swaps.retryOngoingSwaps).thenAnswer((_) async {});

    await RetrySwapsOnRefreshUsecase(swaps).execute();

    verify(swaps.retryOngoingSwaps).called(1);
  });
}
