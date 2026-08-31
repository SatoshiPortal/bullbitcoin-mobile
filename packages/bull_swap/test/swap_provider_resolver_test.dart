import 'package:bull_swap/bull_swap.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

class _StubProvider implements SwapProvider {
  @override
  final SwapProviderConfig config;
  _StubProvider(this.config);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _CountingFactory implements SwapProviderFactory {
  int calls = 0;
  @override
  SwapProvider create(SwapProviderConfig config) {
    calls++;
    return _StubProvider(config);
  }
}

void main() {
  late SwapDatabase db;
  late SwapProviderStore store;
  late _CountingFactory factory;
  late SwapProviderResolver resolver;

  const bull = SwapProviderConfig(
    id: 'bull',
    kind: SwapProviderKind.bull,
    name: 'Bull Bitcoin',
    isBuiltIn: true,
  );

  setUp(() async {
    db = SwapDatabase.forTesting(NativeDatabase.memory());
    var counter = 0;
    store = SwapProviderStore(db, now: () => counter++);
    factory = _CountingFactory();
    resolver = SwapProviderResolver(store, factory);
    await store.ensureSeeded([bull], bull.id);
  });

  tearDown(() => db.close());

  test('resolveActive returns the provider for the active config', () async {
    final provider = await resolver.resolveActive();
    expect(provider.config.id, 'bull');
  });

  test('caches provider instances per config', () async {
    await resolver.resolveActive();
    await resolver.resolveActive();
    expect(factory.calls, 1);
  });

  test('invalidate rebuilds instances', () async {
    await resolver.resolveActive();
    resolver.invalidate();
    await resolver.resolveActive();
    expect(factory.calls, 2);
  });
}
