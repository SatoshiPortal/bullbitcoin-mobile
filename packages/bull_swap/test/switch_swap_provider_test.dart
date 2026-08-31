import 'package:bull_swap/bull_swap.dart';
import 'package:drift/native.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

class _FakeProbe implements PendingSwapsProbe {
  bool active;
  _FakeProbe(this.active);
  @override
  Future<bool> hasActiveSwaps() async => active;
}

class _NullFactory implements SwapProviderFactory {
  @override
  SwapProvider create(SwapProviderConfig config) => throw UnimplementedError();
}

void main() {
  late SwapDatabase db;
  late SwapProviderStore store;
  late SwapProviderResolver resolver;

  const bull = SwapProviderConfig(
    id: 'bull',
    kind: SwapProviderKind.bull,
    name: 'Bull Bitcoin',
    isBuiltIn: true,
  );
  const boltz = SwapProviderConfig(
    id: 'boltz-default',
    kind: SwapProviderKind.boltz,
    name: 'Boltz',
    baseUrl: 'api.boltz.exchange',
    isBuiltIn: true,
  );

  setUp(() async {
    db = SwapDatabase.forTesting(NativeDatabase.memory());
    var counter = 0;
    store = SwapProviderStore(db, now: () => counter++);
    resolver = SwapProviderResolver(store, _NullFactory());
    await store.ensureSeeded([bull, boltz], bull.id);
  });

  tearDown(() => db.close());

  test('blocks switching while a swap is in progress', () async {
    final switcher = SwitchSwapProvider(store, _FakeProbe(true), resolver);

    final result = await switcher.call(boltz.id);

    expect(result, isA<Err<SwapProviderConfig, SwapFailure>>());
    expect((result as Err).failure, isA<SwapSwitchBlockedFailure>());
    expect((await store.active())!.id, 'bull');
  });

  test('switches when no swap is in progress', () async {
    final switcher = SwitchSwapProvider(store, _FakeProbe(false), resolver);

    final result = await switcher.call(boltz.id);

    expect(result, isA<Ok<SwapProviderConfig, SwapFailure>>());
    expect((await store.active())!.id, 'boltz-default');
  });

  test('rejects an unknown provider', () async {
    final switcher = SwitchSwapProvider(store, _FakeProbe(false), resolver);
    final result = await switcher.call('nope');
    expect((result as Err).failure, isA<SwapProviderMisconfiguredFailure>());
  });
}
