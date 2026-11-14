import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/core/swaps/domain/usecases/get_auto_swap_settings_usecase.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_failure.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bb_mobile/features/autoswap/domain/usecases/execute_autoswap_usecase.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetSettings extends Mock implements GetAutoSwapSettingsUsecase {}

class _MockSwapFacade extends Mock implements SwapFacade {}

class _MockProvider extends Mock implements AutoswapProviderPort {}

void main() {
  late _MockGetSettings getSettings;
  late _MockSwapFacade swapFacade;
  late _MockProvider boltz;
  late _MockProvider exchange;
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
    swapFacade = _MockSwapFacade();
    boltz = _MockProvider();
    exchange = _MockProvider();
    usecase = ExecuteAutoswapUsecase(
      getSettings,
      swapFacade,
      boltzProvider: boltz,
      exchangeProvider: exchange,
    );
    when(() => getSettings.execute()).thenAnswer((_) async => valid);
    when(() => swapFacade.getRoute()).thenAnswer((_) async => SwapRoute.boltz);
    when(
      () => boltz.execute(any()),
    ).thenAnswer((_) async => const Ok('boltz-swap'));
    when(
      () => exchange.execute(any()),
    ).thenAnswer((_) async => const Ok('exchange-order'));
  });

  String? okValue(Result<String, AutoswapFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err() => null,
  };

  test('runs Boltz by default', () async {
    expect(okValue(await usecase.execute()), 'boltz-swap');
    verifyNever(() => exchange.execute(any()));
  });

  test('runs the exchange when the route is exchange-only', () async {
    when(
      () => swapFacade.getRoute(),
    ).thenAnswer((_) async => SwapRoute.exchange);

    expect(okValue(await usecase.execute()), 'exchange-order');
    verifyNever(() => boltz.execute(any()));
  });

  test('Boltz unreachable without the fallback stays a failure', () async {
    when(
      () => boltz.execute(any()),
    ).thenAnswer((_) async => const Err(AutoswapBoltzUnavailableFailure()));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapBoltzUnavailableFailure>());
    verifyNever(() => exchange.execute(any()));
  });

  test('falls back to the exchange when Boltz cannot take the transfer '
      'and the fallback is on', () async {
    when(
      () => swapFacade.getRoute(),
    ).thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);
    for (final failure in const <AutoswapFailure>[
      AutoswapBoltzUnavailableFailure(),
      AutoswapAmountOutOfBoundsFailure(),
    ]) {
      when(() => boltz.execute(any())).thenAnswer((_) async => Err(failure));

      expect(okValue(await usecase.execute()), 'exchange-order');
    }
  });

  test('never falls back once Boltz has created a swap', () async {
    when(
      () => swapFacade.getRoute(),
    ).thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);
    for (final failure in const <AutoswapFailure>[
      AutoswapPendingFailure(),
      AutoswapPayinMismatchFailure(),
      AutoswapTargetBalanceFailure(),
      AutoswapExecutionFailure(),
    ]) {
      when(() => boltz.execute(any())).thenAnswer((_) async => Err(failure));

      final result = await usecase.execute();

      expect((result as Err).failure, failure);
    }
    verifyNever(() => exchange.execute(any()));
  });

  test('does not call a provider while consent is pending', () async {
    when(
      () => getSettings.execute(),
    ).thenAnswer((_) async => valid.copyWith(showWarning: true));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapDisabledFailure>());
    verifyNever(() => boltz.execute(any()));
    verifyNever(() => exchange.execute(any()));
  });

  test('does not call a provider with invalid settings', () async {
    when(
      () => getSettings.execute(),
    ).thenAnswer((_) async => valid.copyWith(recipientWalletId: null));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapInvalidSettingsFailure>());
    verifyNever(() => boltz.execute(any()));
  });
}
