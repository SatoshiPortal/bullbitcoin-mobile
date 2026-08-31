import 'package:bb_mobile/features/swap/presentation/swap_provider_settings_cubit.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockStore extends Mock implements SwapProviderStore {}

class _MockSwitch extends Mock implements SwitchSwapProvider {}

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
  late _MockSwitch switcher;

  SwapProviderSettingsCubit build() =>
      SwapProviderSettingsCubit(store, switcher);

  setUp(() {
    store = _MockStore();
    switcher = _MockSwitch();
  });

  test('load exposes providers and the active id', () async {
    when(() => store.all()).thenAnswer((_) async => [_bull, _boltz]);
    when(() => store.active()).thenAnswer((_) async => _bull);

    final cubit = build();
    await cubit.load();

    expect(cubit.state.providers, [_bull, _boltz]);
    expect(cubit.state.activeId, 'bull');
    expect(cubit.state.isLoading, isFalse);
    await cubit.close();
  });

  test('select updates the active id on success', () async {
    when(
      () => switcher.call('boltz'),
    ).thenAnswer((_) async => const Ok(_boltz));

    final cubit = build();
    await cubit.select('boltz');

    expect(cubit.state.activeId, 'boltz');
    expect(cubit.state.isSwitching, isFalse);
    expect(cubit.state.failure, isNull);
    await cubit.close();
  });

  test('select flags a blocked switch', () async {
    when(
      () => switcher.call('boltz'),
    ).thenAnswer((_) async => const Err(SwapSwitchBlockedFailure('mid-swap')));

    final cubit = build();
    await cubit.select('boltz');

    expect(cubit.state.failure, isA<SwapSwitchBlockedFailure>());
    expect(cubit.state.switchBlocked, isTrue);
    await cubit.close();
  });

  test(
    'select surfaces a non-blocking failure without the blocked flag',
    () async {
      when(() => switcher.call('boltz')).thenAnswer(
        (_) async => const Err(SwapProviderMisconfiguredFailure('no url')),
      );

      final cubit = build();
      await cubit.select('boltz');

      expect(cubit.state.failure, isA<SwapProviderMisconfiguredFailure>());
      expect(cubit.state.switchBlocked, isFalse);
      await cubit.close();
    },
  );
}
