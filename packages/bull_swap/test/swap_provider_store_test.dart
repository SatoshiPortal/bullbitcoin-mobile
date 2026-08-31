import 'package:bull_swap/bull_swap.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';

void main() {
  late SwapDatabase db;
  late SwapProviderStore store;

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

  setUp(() {
    db = SwapDatabase.forTesting(NativeDatabase.memory());
    var counter = 0;
    store = SwapProviderStore(db, now: () => counter++);
  });

  tearDown(() => db.close());

  test('ensureSeeded inserts built-ins and sets the default active', () async {
    await store.ensureSeeded([bull, boltz], bull.id);

    final all = await store.all();
    expect(
      all.map((c) => c.id),
      containsAll(<String>['bull', 'boltz-default']),
    );
    expect((await store.active())!.id, 'bull');
  });

  test('ensureSeeded is idempotent and preserves the active choice', () async {
    await store.ensureSeeded([bull, boltz], bull.id);
    await store.setActive(boltz.id);

    await store.ensureSeeded([bull, boltz], bull.id);

    expect((await store.active())!.id, 'boltz-default');
    expect((await store.all()).length, 2);
  });

  test('setActive moves the active flag between providers', () async {
    await store.ensureSeeded([bull, boltz], bull.id);

    await store.setActive(boltz.id);
    expect((await store.active())!.id, 'boltz-default');

    await store.setActive(bull.id);
    expect((await store.active())!.id, 'bull');
  });

  test('setActive on an unknown provider throws', () async {
    await store.ensureSeeded([bull, boltz], bull.id);
    expect(() => store.setActive('nope'), throwsArgumentError);
  });

  test('addCustomBoltz persists a non-built-in boltz provider', () async {
    await store.ensureSeeded([bull, boltz], bull.id);

    final custom = await store.addCustomBoltz(
      name: 'My node',
      baseUrl: 'boltz.mydomain.com',
      id: 'custom-1',
    );

    expect(custom.kind, SwapProviderKind.boltz);
    expect(custom.isBuiltIn, isFalse);
    final stored = await store.byId('custom-1');
    expect(stored!.baseUrl, 'boltz.mydomain.com');
  });

  test('removeCustom re-homes active to a built-in', () async {
    await store.ensureSeeded([bull, boltz], bull.id);
    final custom = await store.addCustomBoltz(
      name: 'My node',
      baseUrl: 'boltz.mydomain.com',
      id: 'custom-1',
    );
    await store.setActive(custom.id);

    await store.removeCustom(custom.id);

    expect(await store.byId('custom-1'), isNull);
    expect((await store.active())!.isBuiltIn, isTrue);
  });

  test('removeCustom never deletes a built-in', () async {
    await store.ensureSeeded([bull, boltz], bull.id);
    await store.removeCustom('bull');
    expect(await store.byId('bull'), isNotNull);
  });
}
