import 'package:preferences/testing.dart';
import 'package:primitives/primitives.dart' show NetworkEnv, Ok;

import 'dart:async';

import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';

import 'package:preferences/preferences.dart' as settings;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swaps/swaps.dart';

import 'support/real_swap_backends.dart';
import '../../support/preferences_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final rapid in [false, true]) {
    test(
      'R1 real settings and engine agree after ${rapid ? 'rapid round trip' : 'single switch control'}',
      () async {
        final appDb = await createPreferencesDatabase();
        await appDb.customStatement(
          'UPDATE settings SET is_superuser = 1, is_dev_mode_enabled = 1 '
          'WHERE id = 1',
        );
        final preferences = PreferencesTesting.fromDao(PreferencesDao(appDb));
        final swapDb = BoltzSwapsDatabase(NativeDatabase.memory());
        final storage = SwapStorage(
          rows: DriftSwapRowStore(swapDb),
          secrets: ReproKeychainBackend().capability,
        );
        SwapEngineParts parts(NetworkEnv environment) => (
          store: SwapStoreImpl(storage: storage, environment: environment),
          boltz: BoltzSwapRepository.connect(
            url: 'http://127.0.0.1:1',
            storage: storage,
            environment: environment,
            electrum: ReproElectrumBackend(),
            lockupChain: ReproChainBackend(),
            newAddressFor: (_) async => throw StateError('No swap is created'),
            walletTx: (_, {required walletId}) async => null,
            walletTxs: (_, {bool sync = false}) async => const [],
            fastestFee: ({
              required txSize,
              required isLiquid,
              required environment,
            }) async => 1,
            wallets: ({required environment}) async => const [],
            swapMasterKeySource: ({required environment}) async => null,
          ),
        );
        final mainnet = parts(NetworkEnv.mainnet);
        final testnet = parts(NetworkEnv.testnet);
        final engine = SwitchableSwapEngine(mainnet);
        final watcher = SwapWatcher(
          store: engine,
          resolvers: {SwapProvider.boltz: engine},
        );
        final buildEntered = Completer<void>();
        final buildRelease = Completer<void>();
        final built = Completer<void>();
        final switcher = SwapEngineSwitcher(
          settingsRepository: preferences,
          engine: engine,
          swapWatcher: watcher,
          build: ({required environment}) async {
            if (environment == NetworkEnv.testnet) {
              if (!buildEntered.isCompleted) buildEntered.complete();
              await buildRelease.future;
            }
            if (!built.isCompleted) built.complete();
            return environment == NetworkEnv.testnet ? testnet : mainnet;
          },
        );
        addTearDown(() async {
          if (!buildRelease.isCompleted) buildRelease.complete();
          await switcher.dispose();
          await watcher.stop();
          mainnet.boltz.dispose();
          testnet.boltz.dispose();
          await preferences.close();
          await swapDb.close();
          await appDb.close();
        });
        switcher.start();

        expect(
          await preferences.setEnvironment(settings.Environment.testnet),
          isA<Ok>(),
        );
        await buildEntered.future.timeout(const Duration(seconds: 3));
        if (rapid) {
          expect(
            await preferences.setEnvironment(settings.Environment.mainnet),
            isA<Ok>(),
          );
          await pumpEventQueue();
        }
        buildRelease.complete();
        await built.future;
        await pumpEventQueue();

        expect(
          ((await preferences.fetch()).fold(
            (value) => value,
            (failure) => throw Exception('Preferences read failed'),
          )).environment,
          rapid ? settings.Environment.mainnet : settings.Environment.testnet,
        );
        expect(
          engine.isTestnet,
          !rapid,
          reason:
              'The real setting returned to mainnet while the first build '
              'was pending; the latest requested environment must win',
        );
      },
    );
  }
}
