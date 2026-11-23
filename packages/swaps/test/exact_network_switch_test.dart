import 'dart:async';

import 'package:preferences/preferences.dart';
import 'package:swaps/src/swap_engine_switcher.dart';
import 'package:swaps/src/switchable_swap_engine.dart';
import 'package:preferences/preferences.dart' as settings;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:swaps/swaps.dart';

class _Settings extends Mock implements Preferences {}

class _Store extends Mock implements SwapStore {}

class _Boltz extends Mock implements BoltzSwapRepository {}

class _Watcher extends Mock implements SwapWatcher {}

const _legacy = bool.fromEnvironment('LEGACY_SWITCHER_BASELINE');

void main() {
  for (final origin in [NetworkEnv.testnet, NetworkEnv.regtest]) {
    final target = origin == NetworkEnv.testnet
        ? NetworkEnv.regtest
        : NetworkEnv.testnet;
    test(
      '${origin.name} to ${target.name} rebuilds the concrete engine',
      () async {
        final changes = StreamController<settings.Environment>.broadcast();
        final preferences = _Settings();
        when(() => preferences.environmentChangeStream)
            .thenAnswer((_) => (changes.stream).map((value) => Ok(value)));
        final watcher = _Watcher();
        when(watcher.stop).thenAnswer((_) async => const Ok(null));
        when(() => watcher.drained).thenAnswer((_) => Future.value());
        when(watcher.start).thenAnswer((_) async {});
        when(() => watcher.isRunning).thenReturn(true);
        final providers = <_Boltz>[];
        SwapEngineParts parts(NetworkEnv environment) {
          final provider = _Boltz();
          providers.add(provider);
          when(() => provider.environment).thenReturn(environment);
          // Exact old boolean semantics, used only by the archived source Red.
          when(() => provider.isTestnet)
              .thenReturn(environment != NetworkEnv.mainnet);
          when(() => provider.updates).thenAnswer((_) => const Stream.empty());
          when(provider.close).thenAnswer((_) async {});
          return (store: _Store(), boltz: provider);
        }

        final engine = SwitchableSwapEngine(parts(origin));
        final builds = <NetworkEnv>[];
        Future<SwapEngineParts> concrete({
          required NetworkEnv environment,
        }) async {
          builds.add(environment);
          return parts(environment);
        }

        Future<SwapEngineParts> binary({required bool isTestnet}) => concrete(
          environment: isTestnet ? NetworkEnv.testnet : NetworkEnv.mainnet,
        );
        final switcher = Function.apply(SwapEngineSwitcher.new, [], {
          #settingsRepository: preferences,
          #engine: engine,
          #swapWatcher: watcher,
          #build: _legacy ? binary : concrete,
        }) as SwapEngineSwitcher;
        addTearDown(() async {
          await switcher.dispose();
          await changes.close();
        });
        switcher.start();
        changes.add(settings.Environment.fromName(target.name));
        await pumpEventQueue(times: 30);
        expect(builds, [target]);
        expect(engine.environment, target);
        verify(watcher.stop).called(1);
        verify(watcher.start).called(1);
      },
    );
  }
}
