import 'dart:async';

import 'package:preferences/preferences.dart' hide Environment;
import 'package:preferences/preferences.dart' as settings;
import 'package:swaps/src/swap_engine_switcher.dart';
import 'package:swaps/src/switchable_swap_engine.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockStore extends Mock implements SwapStore {}

class _MockBoltz extends Mock implements BoltzSwapRepository {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSwapWatcher extends Mock implements SwapWatcher {}

class _Engine {
  final store = _MockStore();
  final boltz = _MockBoltz();
  final updates = StreamController<Swap>.broadcast();

  _Engine({required NetworkEnv environment}) {
    when(() => boltz.isTestnet).thenReturn(environment == NetworkEnv.testnet);
    when(() => boltz.environment).thenReturn(environment);
    when(() => boltz.updates).thenAnswer((_) => updates.stream);
    when(() => boltz.close()).thenAnswer((_) async => boltz.dispose());
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
      final mainnet = _Engine(environment: NetworkEnv.mainnet);
      final testnet = _Engine(environment: NetworkEnv.testnet);
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
    late StreamController<Result<settings.Environment, PreferencesFailure>>
    environments;
    late List<NetworkEnv> builds;
    late SwapEngineSwitcher switcher;

    setUp(() {
      mainnet = _Engine(environment: NetworkEnv.mainnet);
      testnet = _Engine(environment: NetworkEnv.testnet);
      repository = SwitchableSwapEngine(mainnet.parts);
      settingsRepository = _MockSettingsRepository();
      watcher = _MockSwapWatcher();
      environments =
          StreamController<
            Result<settings.Environment, PreferencesFailure>
          >.broadcast();
      builds = [];
      when(() => settingsRepository.environmentChangeStream)
          .thenAnswer((_) => environments.stream);
      when(() => watcher.stop()).thenAnswer((_) async => const Ok(null));
      when(() => watcher.drained).thenAnswer((_) => Future.value());
      when(() => watcher.isRunning).thenReturn(true);
      when(() => watcher.start()).thenAnswer((_) async {});
      switcher = SwapEngineSwitcher(
        settingsRepository: settingsRepository,
        engine: repository,
        swapWatcher: watcher,
        build: ({required environment}) async {
          builds.add(environment);
          return environment == NetworkEnv.testnet
              ? testnet.parts
              : mainnet.parts;
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
      environments.add(const Ok(settings.Environment.testnet));
      await pumpEventQueue();

      expect(builds, [NetworkEnv.testnet]);
      expect(repository.isTestnet, isTrue);
      verifyInOrder([() => watcher.stop(), () => watcher.start()]);
    });

    test(
      'failed notification keeps the current engine and later success resumes',
      () async {
        environments.add(const Err(PreferencesReadFailure()));
        await pumpEventQueue();
        expect(builds, isEmpty);
        expect(repository.isTestnet, isFalse);
        verifyNever(() => watcher.stop());
        environments.add(const Ok(settings.Environment.testnet));
        await pumpEventQueue();
        expect(builds, [NetworkEnv.testnet]);
        expect(repository.isTestnet, isTrue);
      },
    );

    test('suspending the session waits for the drain and a rebuild cannot '
        'restart the driver', () async {
      final drain = Completer<void>();
      when(() => watcher.drained).thenAnswer((_) => drain.future);
      when(() => watcher.suspend()).thenReturn(null);
      var confirmed = false;
      final suspending = switcher.suspendSession().whenComplete(
        () => confirmed = true,
      );
      verify(() => watcher.suspend()).called(1);
      final rebuilt = switcher.rebuild(
        environment: NetworkEnv.testnet,
        waitForCompletion: true,
      );
      await pumpEventQueue();
      expect(confirmed, isFalse, reason: 'the driver has not drained yet');

      drain.complete();
      await suspending;
      await rebuilt;
      expect(confirmed, isTrue);
      expect(repository.isTestnet, isTrue);
      verifyNever(() => watcher.start());

      switcher.resumeSession();
      await pumpEventQueue();
      verify(() => watcher.start()).called(1);
      switcher.resumeSession();
      await pumpEventQueue();
      verifyNever(() => watcher.start());
    });

    test('resuming before the stop is confirmed starts nothing', () async {
      final drain = Completer<void>();
      when(() => watcher.drained).thenAnswer((_) => drain.future);
      when(() => watcher.suspend()).thenReturn(null);
      final suspending = switcher.suspendSession();
      switcher.resumeSession();
      await pumpEventQueue();
      verifyNever(() => watcher.start());
      drain.complete();
      await suspending;
      verifyNever(() => watcher.start());
    });

    test('a switch to the network already in use does nothing', () async {
      environments.add(const Ok(settings.Environment.mainnet));
      await pumpEventQueue();

      expect(builds, isEmpty);
      verifyNever(() => watcher.stop());
    });

    test('queued rebuilds skip targets superseded before admission', () async {
      await Future.wait([
        switcher.rebuild(environment: NetworkEnv.testnet),
        switcher.rebuild(environment: NetworkEnv.mainnet),
      ]);

      expect(builds, [NetworkEnv.mainnet]);
      expect(repository.isTestnet, isFalse);
    });

    test(
      'a failed build keeps the old engine suspended without restarting',
      () async {
        final failing = SwapEngineSwitcher(
          settingsRepository: settingsRepository,
          engine: repository,
          swapWatcher: watcher,
          build: ({required environment}) async => throw Exception('boom'),
        );

        final result = await failing.rebuild(environment: NetworkEnv.testnet);

        expect(result, isA<Err<void, SwapsFailure>>());
        expect(repository.isTestnet, isFalse);
        verifyNever(() => watcher.start());
        expect(
          await repository.createBitcoinToLightningSwap(
            walletId: 'unused',
            invoice: 'unused',
          ),
          isA<Err<LnSendSwap, SwapsFailure>>(),
        );
      },
    );
  });
}
