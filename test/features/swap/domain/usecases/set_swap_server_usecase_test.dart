import 'dart:async';

import 'package:bb_mobile/core/swaps/switchable_swap_engine.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_server.dart';
import 'package:bb_mobile/core/swaps/domain/repositories/swap_server_setting_repository.dart';
import 'package:bb_mobile/core/swaps/swap_engine_switcher.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/swap/domain/swap_failure.dart';
import 'package:bb_mobile/features/swap/domain/usecases/set_swap_server_usecase.dart';
import 'package:swaps/swaps.dart' hide Environment;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSwapServerSettingRepository extends Mock
    implements SwapServerSettingRepository {}

class _MockSettingsRepository extends Mock implements Preferences {}

class _MockSwapEngineSwitcher extends Mock implements SwapEngineSwitcher {}

class _MockSwapStore extends Mock implements SwapStore {}

class _MockBoltz extends Mock implements BoltzSwapRepository {}

class _MockWatcher extends Mock implements SwapWatcher {}

void main() {
  late _MockSwapServerSettingRepository serverSettings;
  late _MockSettingsRepository settingsRepository;
  late _MockSwapEngineSwitcher switcher;
  late _MockSwapStore swaps;
  late SetSwapServerUsecase usecase;

  setUpAll(() => registerFallbackValue(SwapServer.mainnetDefault));

  void stubEnvironment(Environment environment) =>
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => Ok(
          SettingsEntity(
            environment: environment,
            bitcoinUnit: BitcoinUnit.sats,
            currencyCode: 'USD',
          ),
        ),
      );

  setUp(() {
    serverSettings = _MockSwapServerSettingRepository();
    settingsRepository = _MockSettingsRepository();
    switcher = _MockSwapEngineSwitcher();
    swaps = _MockSwapStore();
    when(() => swaps.ongoing()).thenAnswer((_) async => const Ok([]));
    when(() => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')))
        .thenAnswer((_) async {});
    when(
      () => switcher.rebuild(
        environment: any(named: 'environment'),
        waitForCompletion: true,
      ),
    ).thenAnswer((_) async => const Ok(null));
    stubEnvironment(Environment.mainnet);
    usecase = SetSwapServerUsecase(
      swapServerSettingRepository: serverSettings,
      settingsRepository: settingsRepository,
      swapEngineSwitcher: switcher,
      swapStore: swaps,
    );
  });

  SwapFailure? failureOf(Result<SwapServer, SwapFailure> result) =>
      switch (result) {
        Ok() => null,
        Err(:final failure) => failure,
      };

  test('stores a valid server and moves the engine onto it', () async {
    final result = await usecase.execute('https://boltz.example.com/v2');

    expect(failureOf(result), isNull);
    final saved = verify(
      () => serverSettings.save(captureAny(), isTestnet: false),
    ).captured.single;
    expect((saved as SwapServer).host, 'boltz.example.com/v2');
    verify(
      () => switcher.rebuild(
        environment: NetworkEnv.mainnet,
        waitForCompletion: true,
      ),
    ).called(1);
  });

  test('settings wait for a slow rebuild after saving the server', () async {
    final provider = _MockBoltz();
    final watcher = _MockWatcher();
    final updates = StreamController<Swap>.broadcast();
    when(() => provider.isTestnet).thenReturn(false);
    when(() => provider.environment).thenReturn(NetworkEnv.mainnet);
    when(() => provider.updates).thenAnswer((_) => updates.stream);
    when(() => provider.close()).thenAnswer((_) async {});
    when(() => watcher.stop()).thenAnswer((_) async => const Ok(null));
    when(() => watcher.drained).thenAnswer((_) => Future.value());
    when(() => watcher.start()).thenAnswer((_) async {});
    when(() => watcher.isRunning).thenReturn(true);
    final engine = SwitchableSwapEngine((store: swaps, boltz: provider));
    final entered = Completer<void>();
    final release = Completer<void>();
    final realSwitcher = SwapEngineSwitcher(
      settingsRepository: settingsRepository,
      engine: engine,
      swapWatcher: watcher,
      build: ({required environment}) async {
        entered.complete();
        await release.future;
        return (store: swaps, boltz: provider);
      },
    );
    final saving = SetSwapServerUsecase(
      swapServerSettingRepository: serverSettings,
      settingsRepository: settingsRepository,
      swapEngineSwitcher: realSwitcher,
      swapStore: swaps,
    );
    var returned = false;
    final result = saving.execute('https://boltz.example.com/v2').then((value) {
      returned = true;
      return value;
    });
    addTearDown(() async {
      if (!release.isCompleted) release.complete();
      await result;
      await realSwitcher.dispose();
      await updates.close();
    });
    await entered.future;
    verify(() => serverSettings.save(any(), isTestnet: false)).called(1);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(
      returned,
      isFalse,
      reason: 'Saving succeeded; a slow active rebuild is not a busy-server refusal',
    );
    release.complete();
    expect(failureOf(await result), isNull);
    verify(() => watcher.start()).called(1);
  });

  test('stores a testnet server under testnet', () async {
    stubEnvironment(Environment.testnet);

    final result = await usecase.execute('boltz.example.com/v2');

    expect(failureOf(result), isNull);
    verify(() => serverSettings.save(any(), isTestnet: true)).called(1);
    verify(
      () => switcher.rebuild(
        environment: NetworkEnv.testnet,
        waitForCompletion: true,
      ),
    ).called(1);
  });

  test('refuses an address it cannot parse', () async {
    final result = await usecase.execute('not a host');

    expect(failureOf(result), isA<SwapValidationFailure>());
    verifyNever(
      () => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')),
    );
    verifyNever(
      () => switcher.rebuild(
        environment: any(named: 'environment'),
        waitForCompletion: true,
      ),
    );
  });

  test('refuses a plaintext server on mainnet', () async {
    final result = await usecase.execute('http://10.0.2.2:9001/v2');

    expect(failureOf(result), isA<SwapValidationFailure>());
    verifyNever(
      () => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')),
    );
  });

  test('allows a plaintext server on testnet', () async {
    stubEnvironment(Environment.testnet);

    final result = await usecase.execute('http://10.0.2.2:9001/v2');

    expect(failureOf(result), isNull);
  });

  Swap openSwap(DateTime creationTime) => Swap.lnReceive(
    id: 'open-1',
    keyIndex: 0,
    type: SwapType.lightningToLiquid,
    status: SwapStatus.pending,
    environment: SwapEnvironment.mainnet,
    creationTime: creationTime,
    receiveWalletId: 'w',
    invoice: 'lnbc1',
  );

  test('refuses a change while swaps on the current server are open', () async {
    when(() => swaps.ongoing()).thenAnswer(
      (_) async =>
          Ok([openSwap(DateTime.now().subtract(const Duration(hours: 2)))]),
    );

    final result = await usecase.execute('boltz.example.com/v2');

    expect(failureOf(result), isA<SwapServerBusyFailure>());
    verifyNever(
      () => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')),
    );
    verifyNever(
      () => switcher.rebuild(
        environment: any(named: 'environment'),
        waitForCompletion: true,
      ),
    );
  });

  test('a swap older than a day does not pin the server', () async {
    when(() => swaps.ongoing()).thenAnswer(
      (_) async =>
          Ok([openSwap(DateTime.now().subtract(const Duration(days: 2)))]),
    );

    final result = await usecase.execute('boltz.example.com/v2');

    expect(failureOf(result), isNull);
    verify(
      () => switcher.rebuild(
        environment: NetworkEnv.mainnet,
        waitForCompletion: true,
      ),
    ).called(1);
  });

  test('a failed write is a storage failure and leaves the engine', () async {
    when(() => serverSettings.save(any(), isTestnet: any(named: 'isTestnet')))
        .thenThrow(const SwapServerSettingException());

    final result = await usecase.execute('boltz.example.com/v2');

    expect(failureOf(result), isA<SwapStorageFailure>());
    verifyNever(
      () => switcher.rebuild(
        environment: any(named: 'environment'),
        waitForCompletion: true,
      ),
    );
  });
  test(
    'regtest refuses server edits before preferences or engine mutation',
    () async {
      stubEnvironment(Environment.regtest);
      final result = await usecase.execute('https://other.example/v2');
      expect(failureOf(result), isA<SwapUnsupportedNetworkFailure>());
      verifyZeroInteractions(serverSettings);
      verifyZeroInteractions(swaps);
      verifyZeroInteractions(switcher);
    },
  );
}
