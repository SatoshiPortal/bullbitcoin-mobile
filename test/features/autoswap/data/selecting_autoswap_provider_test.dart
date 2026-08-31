import 'package:bb_mobile/core/swaps/domain/entity/auto_swap.dart';
import 'package:bb_mobile/features/autoswap/data/selecting_autoswap_provider.dart';
import 'package:bb_mobile/features/autoswap/domain/autoswap_provider_port.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockStore extends Mock implements SwapProviderStore {}

class _MockPort extends Mock implements AutoswapProviderPort {}

const _settings = AutoSwap();

const _bull = SwapProviderConfig(
  id: 'bull',
  kind: SwapProviderKind.bull,
  name: 'Bull',
  isBuiltIn: true,
);

const _boltz = SwapProviderConfig(
  id: 'boltz',
  kind: SwapProviderKind.boltz,
  name: 'Boltz',
  baseUrl: 'api.boltz.exchange/v2',
);

void main() {
  late _MockStore store;
  late _MockPort bull;
  late _MockPort boltz;
  late SelectingAutoswapProvider selector;

  setUpAll(() => registerFallbackValue(const AutoSwap()));

  setUp(() {
    store = _MockStore();
    bull = _MockPort();
    boltz = _MockPort();
    selector = SelectingAutoswapProvider(store, bull, boltz);
    when(
      () => bull.execute(_settings),
    ).thenAnswer((_) async => const Ok('bull'));
    when(
      () => boltz.execute(_settings),
    ).thenAnswer((_) async => const Ok('boltz'));
  });

  test('routes to Bull when the active provider is Bull', () async {
    when(() => store.active()).thenAnswer((_) async => _bull);

    final result = await selector.execute(_settings);

    expect((result as Ok).value, 'bull');
    verify(() => bull.execute(_settings)).called(1);
    verifyNever(() => boltz.execute(_settings));
  });

  test('routes to Boltz when the active provider is Boltz', () async {
    when(() => store.active()).thenAnswer((_) async => _boltz);

    final result = await selector.execute(_settings);

    expect((result as Ok).value, 'boltz');
    verify(() => boltz.execute(_settings)).called(1);
    verifyNever(() => bull.execute(_settings));
  });

  test('defaults to Bull when there is no active provider', () async {
    when(() => store.active()).thenAnswer((_) async => null);

    final result = await selector.execute(_settings);

    expect((result as Ok).value, 'bull');
    verify(() => bull.execute(_settings)).called(1);
    verifyNever(() => boltz.execute(_settings));
  });
}
