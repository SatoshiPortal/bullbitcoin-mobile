import 'package:primitives/primitives.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swaps/swaps.dart';
import 'package:test/test.dart';

abstract interface class _Host {
  Future<Result<AutoSwap, AutoswapFailure>> readSettings();
  Future<SwapRoute> getRoute();
}

class _MockHost extends Mock implements _Host {}

abstract interface class _Provider {
  Future<Result<String, AutoswapFailure>> execute(AutoSwap settings);
}

class _MockProvider extends Mock implements _Provider {}

void main() {
  late _MockHost host;
  late _MockProvider boltz;
  late _MockProvider exchange;
  late Autoswap usecase;

  const valid = AutoSwap(
    enabled: true,
    showWarning: false,
    balanceThresholdSats: 100000,
    triggerBalanceSats: 200000,
    recipientWalletId: 'bitcoin-wallet',
  );

  setUpAll(() => registerFallbackValue(const AutoSwap()));

  setUp(() {
    host = _MockHost();
    boltz = _MockProvider();
    exchange = _MockProvider();
    usecase = Autoswap.open(
      readSettings: host.readSettings,
      resolveRoute: host.getRoute,
      runBoltz: boltz.execute,
      runExchange: exchange.execute,
    );
    when(host.readSettings).thenAnswer((_) async => const Ok(valid));
    when(host.getRoute).thenAnswer((_) async => SwapRoute.boltz);
    when(() => boltz.execute(any()))
        .thenAnswer((_) async => const Ok('boltz-swap'));
    when(() => exchange.execute(any()))
        .thenAnswer((_) async => const Ok('exchange-order'));
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
    when(host.getRoute).thenAnswer((_) async => SwapRoute.exchange);

    expect(okValue(await usecase.execute()), 'exchange-order');
    verifyNever(() => boltz.execute(any()));
  });

  test('Boltz unreachable without the fallback stays a failure', () async {
    when(() => boltz.execute(any()))
        .thenAnswer((_) async => const Err(AutoswapBoltzUnavailableFailure()));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapBoltzUnavailableFailure>());
    verifyNever(() => exchange.execute(any()));
  });

  test('falls back to the exchange when Boltz cannot take the transfer '
      'and the fallback is on', () async {
    when(host.getRoute)
        .thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);
    for (final failure in const <AutoswapFailure>[
      AutoswapBoltzUnavailableFailure(),
      AutoswapAmountOutOfBoundsFailure(),
    ]) {
      when(() => boltz.execute(any())).thenAnswer((_) async => Err(failure));

      expect(okValue(await usecase.execute()), 'exchange-order');
    }
  });

  test('never falls back once Boltz has created a swap', () async {
    when(host.getRoute)
        .thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);
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
    when(host.readSettings)
        .thenAnswer((_) async => Ok(valid.copyWith(showWarning: true)));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapDisabledFailure>());
    verifyNever(() => boltz.execute(any()));
    verifyNever(() => exchange.execute(any()));
  });

  test('does not call a provider with invalid settings', () async {
    when(host.readSettings)
        .thenAnswer((_) async => Ok(valid.copyWith(recipientWalletId: null)));

    final result = await usecase.execute();

    expect((result as Err).failure, isA<AutoswapInvalidSettingsFailure>());
    verifyNever(() => boltz.execute(any()));
  });

  test('refuses an unsupported network before resolving the route', () async {
    const failure = AutoswapUnsupportedNetworkFailure();
    when(host.readSettings).thenAnswer((_) async => const Err(failure));

    expect(
      await usecase.execute(),
      isA<Err<String, AutoswapFailure>>().having(
        (result) => result.failure,
        'failure',
        same(failure),
      ),
    );
    verifyNever(host.getRoute);
    verifyNever(() => boltz.execute(any()));
    verifyNever(() => exchange.execute(any()));
  });

  test(
    'does not contact either provider if resolving the route throws',
    () async {
      when(host.getRoute)
          .thenAnswer((_) async => throw const FormatException());

      expect(
        await usecase.execute(),
        isA<Err<String, AutoswapFailure>>().having(
          (result) => result.failure,
          'failure',
          isA<AutoswapExecutionFailure>(),
        ),
      );
      verifyNever(() => boltz.execute(any()));
      verifyNever(() => exchange.execute(any()));
    },
  );

  test('does not fall back if Boltz throws instead of refusing', () async {
    when(host.getRoute)
        .thenAnswer((_) async => SwapRoute.boltzWithExchangeFallback);
    when(() => boltz.execute(any())).thenAnswer(
      (_) async => throw const FormatException('private provider response'),
    );

    expect(
      await usecase.execute(),
      isA<Err<String, AutoswapFailure>>().having(
        (result) => result.failure,
        'failure',
        isA<AutoswapExecutionFailure>().having(
          (failure) => failure.logMessage,
          'safe log message',
          'FormatException',
        ),
      ),
    );
    verify(() => boltz.execute(valid)).called(1);
    verifyNever(() => exchange.execute(any()));
  });
}
