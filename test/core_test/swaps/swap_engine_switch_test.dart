import 'dart:async';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart'
    as settings;
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:bb_mobile/core/swaps/switchable_swap_engine.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStore extends Mock implements SwapStore {}

class _MockBoltz extends Mock implements BoltzSwapRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSwapWatcher extends Mock implements SwapWatcher {}

class _Engine {
  final store = _MockStore();
  final boltz = _MockBoltz();
  final updates = StreamController<Swap>.broadcast();

  _Engine({required bool isTestnet}) {
    when(() => boltz.isTestnet).thenReturn(isTestnet);
    when(() => boltz.updates).thenAnswer((_) => updates.stream);
    when(() => store.ongoing()).thenAnswer((_) async => const Ok([]));
  }

  SwapEngineParts get parts => (store: store, boltz: boltz);
}

Swap _swap(String id) => Swap.lnReceive(
  id: id,
  keyIndex: 0,
  type: SwapType.lightningToLiquid,
  status: SwapStatus.pending,
  environment: Environment.testnet,
  creationTime: DateTime.utc(2026),
  receiveWalletId: 'w',
  invoice: 'lntb1',
);

void main() {
  group('SwitchableSwapEngine', () {
    test('forwards to the current engine and moves on replace', () async {
      final mainnet = _Engine(isTestnet: false);
      final testnet = _Engine(isTestnet: true);
      final repository = SwitchableSwapEngine(mainnet.parts);
      final seen = <String>[];
      final sub = repository.updates.listen((swap) => seen.add(swap.id));
      addTearDown(sub.cancel);

      await repository.ongoing();
      mainnet.updates.add(_swap('main-1'));
      await pumpEventQueue();

      await repository.replace(testnet.parts);
      await repository.ongoing();
      mainnet.updates.add(_swap('main-late'));
      testnet.updates.add(_swap('test-1'));
      await pumpEventQueue();

      expect(repository.isTestnet, isTrue);
      expect(seen, ['main-1', 'test-1']);
      verify(() => mainnet.store.ongoing()).called(1);
      verify(() => testnet.store.ongoing()).called(1);
      verify(() => mainnet.boltz.dispose()).called(1);
      verifyNever(() => testnet.boltz.dispose());
    });
  });

  group('SwapEngineSwitcher', () {
    late _Engine mainnet;
    late _Engine testnet;
    late SwitchableSwapEngine repository;
    late _MockSettingsRepository settingsRepository;
    late _MockSwapWatcher watcher;
    late StreamController<settings.Environment> environments;
    late List<bool> builds;
    late SwapEngineSwitcher switcher;

    setUp(() {
      mainnet = _Engine(isTestnet: false);
      testnet = _Engine(isTestnet: true);
      repository = SwitchableSwapEngine(mainnet.parts);
      settingsRepository = _MockSettingsRepository();
      watcher = _MockSwapWatcher();
      environments = StreamController<settings.Environment>.broadcast();
      builds = [];
      when(
        () => settingsRepository.environmentChangeStream,
      ).thenAnswer((_) => environments.stream);
      when(() => watcher.stop()).thenAnswer((_) async {});
      when(() => watcher.start()).thenAnswer((_) async {});
      switcher = SwapEngineSwitcher(
        settingsRepository: settingsRepository,
        engine: repository,
        swapWatcher: watcher,
        build: ({required isTestnet}) async {
          builds.add(isTestnet);
          return isTestnet ? testnet.parts : mainnet.parts;
        },
      );
      switcher.start();
      addTearDown(() async {
        await switcher.dispose();
        await environments.close();
      });
    });

    test('switching to testnet stops the watcher, swaps the engine and '
        'restarts the watcher', () async {
      environments.add(settings.Environment.testnet);
      await pumpEventQueue();

      expect(builds, [true]);
      expect(repository.isTestnet, isTrue);
      verifyInOrder([() => watcher.stop(), () => watcher.start()]);
    });

    test('a switch to the network already in use does nothing', () async {
      environments.add(settings.Environment.mainnet);
      await pumpEventQueue();

      expect(builds, isEmpty);
      verifyNever(() => watcher.stop());
    });

    test('rebuilds run one after another', () async {
      await Future.wait([
        switcher.rebuild(isTestnet: true),
        switcher.rebuild(isTestnet: false),
      ]);

      expect(builds, [true, false]);
      expect(repository.isTestnet, isFalse);
    });

    test(
      'a failed build keeps the old engine and the watcher running',
      () async {
        final failing = SwapEngineSwitcher(
          settingsRepository: settingsRepository,
          engine: repository,
          swapWatcher: watcher,
          build: ({required isTestnet}) async => throw Exception('boom'),
        );

        await failing.rebuild(isTestnet: true);

        expect(repository.isTestnet, isFalse);
        verify(() => watcher.start()).called(1);
      },
    );
  });
}
