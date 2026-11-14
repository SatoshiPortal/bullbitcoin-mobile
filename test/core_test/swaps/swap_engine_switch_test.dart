import 'dart:async';

import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart'
    as settings;
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:bb_mobile/core/swaps/switchable_swap_repository.dart';
import 'package:boltz_swaps/boltz_swaps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements BoltzSwapRepository {}

class _MockDatasource extends Mock implements BoltzDatasource {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSwapWatcher extends Mock implements SwapWatcher {}

class _Engine {
  final repository = _MockRepository();
  final datasource = _MockDatasource();
  final updates = StreamController<Swap>.broadcast();

  _Engine({required bool isTestnet}) {
    when(() => repository.isTestnet).thenReturn(isTestnet);
    when(() => repository.updates).thenAnswer((_) => updates.stream);
    when(() => repository.ongoing()).thenAnswer((_) async => []);
  }

  SwapEngineParts get parts => (repository: repository, datasource: datasource);
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
  group('SwitchableSwapRepository', () {
    test('forwards to the current engine and moves on replace', () async {
      final mainnet = _Engine(isTestnet: false);
      final testnet = _Engine(isTestnet: true);
      final repository = SwitchableSwapRepository(mainnet.parts);
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
      verify(() => mainnet.repository.ongoing()).called(1);
      verify(() => testnet.repository.ongoing()).called(1);
      verify(() => mainnet.datasource.dispose()).called(1);
      verifyNever(() => testnet.datasource.dispose());
    });
  });

  group('SwapEngineSwitcher', () {
    late _Engine mainnet;
    late _Engine testnet;
    late SwitchableSwapRepository repository;
    late _MockSettingsRepository settingsRepository;
    late _MockSwapWatcher watcher;
    late StreamController<settings.Environment> environments;
    late List<bool> builds;
    late SwapEngineSwitcher switcher;

    setUp(() {
      mainnet = _Engine(isTestnet: false);
      testnet = _Engine(isTestnet: true);
      repository = SwitchableSwapRepository(mainnet.parts);
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
        swapRepository: repository,
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
          swapRepository: repository,
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
