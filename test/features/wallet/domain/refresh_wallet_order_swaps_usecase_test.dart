import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:bb_mobile/features/wallet/domain/refresh_wallet_order_swaps_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapFacade extends Mock implements SwapFacade {}

void main() {
  test('refreshes Exchange orders through the public facade', () async {
    final facade = _MockSwapFacade();
    when(facade.refreshOrders).thenAnswer((_) async => const Ok(null));
    final usecase = RefreshWalletOrderSwapsUsecase(facade);

    expect(await usecase.execute(), isTrue);

    verify(facade.refreshOrders).called(1);
  });
}
