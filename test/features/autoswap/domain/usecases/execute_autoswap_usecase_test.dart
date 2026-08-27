import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/execute_autoswap_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettings extends Mock implements GetAutoSwapSettingsUsecase {}

class _MockProvider extends Mock implements AutoswapProviderPort {}

void main() {
  late _MockGetSettings getSettings;
  late _MockProvider provider;
  late ExecuteAutoswapUsecase usecase;

  const valid = AutoSwap(
    enabled: true,
    showWarning: false,
    balanceThresholdSats: 100000,
    triggerBalanceSats: 200000,
    recipientWalletId: 'bitcoin-wallet',
  );

  setUpAll(() => registerFallbackValue(const AutoSwap()));

  setUp(() {
    getSettings = _MockGetSettings();
    provider = _MockProvider();
    usecase = ExecuteAutoswapUsecase(getSettings, provider);
  });

  test('delegates valid settings to the active provider', () async {
    when(() => getSettings.execute()).thenAnswer((_) async => valid);
    when(() => provider.execute(valid)).thenAnswer((_) async => const Ok('id'));

    expect(await usecase.execute(), const Ok<String, AutoswapFailure>('id'));
    verify(() => provider.execute(valid)).called(1);
  });

  test('does not call the provider while consent is pending', () async {
    when(
      () => getSettings.execute(),
    ).thenAnswer((_) async => valid.copyWith(showWarning: true));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapDisabledFailure>());
    verifyNever(() => provider.execute(any()));
  });

  test('does not call the provider with invalid settings', () async {
    when(
      () => getSettings.execute(),
    ).thenAnswer((_) async => valid.copyWith(recipientWalletId: null));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapInvalidSettingsFailure>());
    verifyNever(() => provider.execute(any()));
  });
}
