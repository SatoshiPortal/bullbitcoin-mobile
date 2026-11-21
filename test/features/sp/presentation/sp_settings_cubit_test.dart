import 'dart:async';

import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_backend_defaults_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/load_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/update_sp_backend_config_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_connection_status.dart';
import 'package:bb_mobile/features/sp/domain/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/presentation/sp_notification_console_text.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUpdateSpBackendConfigUsecase extends Mock
    implements UpdateSpBackendConfigUsecase {}

class _MockWatchSpNotificationLogUsecase extends Mock
    implements WatchSpNotificationLogUsecase {}

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockSpBackendProbe extends Mock implements SpBackendProbePort {}

SpNotifLogLine _line(SpNotification notification) =>
    SpNotifLogLine(time: DateTime(2026, 6, 24), notification: notification);

void main() {
  setUpAll(() {
    registerFallbackValue(BitcoinNetwork.regtest);
    registerFallbackValue(SpBackendKind.blindbit);
  });

  // Stub the mock repo's backend test to run the injected blindbit/electrum
  // probes, mirroring the real adapter's try/catch mapping.
  void stubTestBackend(
    _MockSpBackendProbe probe, {
    Future<void> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
  }) {
    when(() => probe.testBackend(any(), any())).thenAnswer((inv) async {
      final kind = inv.positionalArguments[0] as SpBackendKind;
      final url = inv.positionalArguments[1] as String;
      try {
        switch (kind) {
          case SpBackendKind.blindbit:
            await (testBlindbit ?? (({required String url}) async {}))(
              url: url,
            );
          case SpBackendKind.electrum:
            await (testElectrum ?? (({required String url}) async {}))(
              url: url,
            );
        }
        return const Ok<bool, SpFailure>(true);
      } catch (e) {
        return Err<void, SpFailure>(
          SpBackendUnreachable('SP backend test failed ($url): $e'),
        );
      }
    });
  }

  late _MockWatchSpNotificationLogUsecase logUsecase;
  late StreamController<SpNotifLogLine> logController;
  late _MockUpdateSpBackendConfigUsecase updateUsecase;

  SpSettingsCubit build({
    List<SpNotifLogLine> seed = const [],
    Future<void> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
  }) {
    when(() => logUsecase.execute())
        .thenReturn((log: seed, updates: logController.stream));
    final configRepo = _MockSpBackendConfigRepository();
    final probe = _MockSpBackendProbe();
    when(() => configRepo.fetch())
        .thenAnswer((_) async => const Ok<SpBackendConfig?, SpFailure>(null));
    when(() => probe.fetchRegtestDefaults()).thenAnswer(
      (_) async => const Ok<SpBackendDefaults, SpFailure>(
        SpBackendDefaults(
          blindbitUrl: 'http://127.0.0.1:8000',
          electrumUrl: 'tcp://127.0.0.1:50001',
        ),
      ),
    );
    stubTestBackend(
      probe,
      testBlindbit: testBlindbit,
      testElectrum: testElectrum,
    );
    updateUsecase = _MockUpdateSpBackendConfigUsecase();
    return SpSettingsCubit(
      updateSpBackendConfigUsecase: updateUsecase,
      watchNotificationLogUsecase: logUsecase,
      testSpBackendUsecase: TestSpBackendUsecase(probe: probe),
      loadSpBackendConfigUsecase: LoadSpBackendConfigUsecase(
        configRepository: configRepo,
      ),
      getSpBackendDefaultsUsecase: GetSpBackendDefaultsUsecase(probe: probe),
    );
  }

  void stubUpdate({SpFailure? failure, bool changed = true}) {
    final stub = when(
      () => updateUsecase.execute(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
      ),
    );
    if (failure != null) {
      stub.thenAnswer((_) async => Err<bool, SpFailure>(failure));
    } else {
      stub.thenAnswer((_) async => Ok<bool, SpFailure>(changed));
    }
  }

  void verifyNeverUpdate() {
    verifyNever(
      () => updateUsecase.execute(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
      ),
    );
  }

  setUp(() {
    logUsecase = _MockWatchSpNotificationLogUsecase();
    logController = StreamController<SpNotifLogLine>.broadcast();
  });

  tearDown(() => logController.close());

  group('SpSettingsCubit', () {
    test(
      'initial state is a placeholder until initialized from a network',
      () async {
        final cubit = build();
        // Construction does not block on backend defaults: URLs are empty until
        // initFromNetwork or setNetwork provides the network to load.
        expect(cubit.state.network, BitcoinNetwork.mainnet);
        expect(cubit.state.blindbitUrl, isEmpty);
        expect(cubit.state.isFetchingDefaults, isTrue);

        await cubit.setNetwork(BitcoinNetwork.regtest);

        expect(cubit.state.blindbitUrl, 'http://127.0.0.1:8000');
        expect(cubit.state.electrumUrl, 'tcp://127.0.0.1:50001');
        expect(cubit.state.isFetchingDefaults, isFalse);
        await cubit.close();
      },
    );

    test('setNetwork to regtest pre-fills default URLs', () async {
      final cubit = build();
      await cubit.setNetwork(BitcoinNetwork.mainnet);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.staticDefaults(BitcoinNetwork.mainnet)!.blindbitUrl,
      );

      await cubit.setNetwork(BitcoinNetwork.regtest);

      expect(cubit.state.network, BitcoinNetwork.regtest);
      expect(cubit.state.blindbitUrl, 'http://127.0.0.1:8000');
      expect(cubit.state.electrumUrl, 'tcp://127.0.0.1:50001');
      await cubit.close();
    });

    test(
      'initFromNetwork loads the stored custom config over defaults',
      () async {
        when(() => logUsecase.execute())
            .thenReturn((log: const [], updates: logController.stream));
        final configRepo = _MockSpBackendConfigRepository();
        final probe = _MockSpBackendProbe();
        when(() => configRepo.fetch()).thenAnswer(
          (_) async => Ok<SpBackendConfig?, SpFailure>(
            SpBackendConfig(
              network: BitcoinNetwork.mainnet,
              blindbitUrl: 'https://custom.blindbit',
              electrumUrl: 'ssl://custom.electrum:50002',
            ),
          ),
        );
        when(() => probe.fetchRegtestDefaults()).thenAnswer(
          (_) async => const Ok<SpBackendDefaults, SpFailure>(
            SpBackendDefaults(
              blindbitUrl: 'http://127.0.0.1:8000',
              electrumUrl: 'tcp://127.0.0.1:50001',
            ),
          ),
        );
        stubTestBackend(probe);
        final cubit = SpSettingsCubit(
          updateSpBackendConfigUsecase: _MockUpdateSpBackendConfigUsecase(),
          watchNotificationLogUsecase: logUsecase,
          testSpBackendUsecase: TestSpBackendUsecase(probe: probe),
          loadSpBackendConfigUsecase: LoadSpBackendConfigUsecase(
            configRepository: configRepo,
          ),
          getSpBackendDefaultsUsecase: GetSpBackendDefaultsUsecase(
            probe: probe,
          ),
        );

        await cubit.initFromNetwork(BitcoinNetwork.regtest);

        expect(cubit.state.network, BitcoinNetwork.mainnet);
        expect(cubit.state.blindbitUrl, 'https://custom.blindbit');
        expect(cubit.state.electrumUrl, 'ssl://custom.electrum:50002');
        await cubit.close();
      },
    );
  });

  group('SpSettingsCubit console', () {
    test('seeds console from the buffered log', () async {
      final cubit = build(seed: [_line(const SpScanStarted(1, 2))]);
      expect(cubit.state.console.map((l) => l.notification.consoleText), [
        'ScanStarted 1 -> 2',
      ]);
      await cubit.close();
    });

    test('appends new lines from the stream', () async {
      final cubit = build();
      expect(cubit.state.console, isEmpty);

      logController.add(_line(SpNewOutput('abc', Sats.fromInt(100))));
      await Future.delayed(Duration.zero);

      expect(cubit.state.console.map((l) => l.notification.consoleText), [
        'NewOutput abc 100sat',
      ]);
      await cubit.close();
    });

    test('console survives a network change', () async {
      final cubit = build(seed: [_line(const SpScanCompleted())]);
      await cubit.setNetwork(BitcoinNetwork.mainnet);
      expect(cubit.state.console.map((l) => l.notification.consoleText), [
        'ScanCompleted',
      ]);
      await cubit.close();
    });

    test('clearConsole empties the console', () async {
      final cubit = build(seed: [_line(const SpScanCompleted())]);
      cubit.clearConsole();
      expect(cubit.state.console, isEmpty);
      await cubit.close();
    });
  });

  group('SpSettingsCubit saveBackendConfig', () {
    test('unchanged settings do not signal a wallet reload', () async {
      final cubit = build();
      stubUpdate(changed: false);
      await cubit.setNetwork(BitcoinNetwork.regtest);
      await cubit.testBlindbit();
      await cubit.testElectrum();

      await cubit.saveBackendConfig();

      expect(cubit.state.saved, isFalse);
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.error, isNull);
      await cubit.close();
    });

    test('success sets saved and clears isSaving', () async {
      final cubit = build();
      stubUpdate();
      // Fill the URLs from the regtest defaults, then pass both connection
      // tests so canSave is satisfied.
      await cubit.setNetwork(BitcoinNetwork.regtest);
      await cubit.testBlindbit();
      await cubit.testElectrum();
      expect(cubit.state.canSave, isTrue);

      await cubit.saveBackendConfig();

      expect(cubit.state.saved, isTrue);
      expect(cubit.state.isSaving, isFalse);
      verify(
        () => updateUsecase.execute(
          network: BitcoinNetwork.regtest,
          blindbitUrl: 'http://127.0.0.1:8000',
          electrumUrl: 'tcp://127.0.0.1:50001',
        ),
      ).called(1);
      await cubit.close();
    });

    test('an update failure sets error and clears isSaving', () async {
      final cubit = build();
      stubUpdate(failure: const SpUnexpected('recreate failed'));
      await cubit.setNetwork(BitcoinNetwork.regtest);
      await cubit.testBlindbit();
      await cubit.testElectrum();

      await cubit.saveBackendConfig();

      expect(cubit.state.error, isA<SpUnexpected>());
      expect(cubit.state.isSaving, isFalse);
      expect(cubit.state.saved, isFalse);
      await cubit.close();
    });

    test('the canSave gate no-ops and never calls recreate when tests have not '
        'passed', () async {
      final cubit = build();
      stubUpdate();
      await cubit.setNetwork(BitcoinNetwork.regtest);
      // No testBlindbit()/testElectrum(): the conn tests stay untested.
      expect(cubit.state.canSave, isFalse);

      await cubit.saveBackendConfig();

      verifyNeverUpdate();
      expect(cubit.state.saved, isFalse);
      expect(cubit.state.isSaving, isFalse);
      await cubit.close();
    });
  });

  group('SpSettingsCubit connection tests', () {
    test(
      'a failed blindbit connection test stores the error and blocks save',
      () async {
        final cubit = build(
          testBlindbit: ({required String url}) async =>
              throw Exception('blindbit down'),
        );
        stubUpdate();
        await cubit.setNetwork(BitcoinNetwork.regtest);

        await cubit.testBlindbit();
        await cubit.testElectrum();

        expect(cubit.state.blindbitStatus, SpConnectionStatus.failed);
        expect(cubit.state.blindbitStatusError, isA<SpBackendUnreachable>());
        expect(cubit.state.electrumStatus, SpConnectionStatus.ok);
        expect(cubit.state.canSave, isFalse);

        await cubit.saveBackendConfig();

        verifyNeverUpdate();
        await cubit.close();
      },
    );

    test(
      'a failed electrum connection test stores the error and blocks save',
      () async {
        final cubit = build(
          testElectrum: ({required String url}) async =>
              throw Exception('electrum down'),
        );
        stubUpdate();
        await cubit.setNetwork(BitcoinNetwork.regtest);

        await cubit.testBlindbit();
        await cubit.testElectrum();

        expect(cubit.state.electrumStatus, SpConnectionStatus.failed);
        expect(cubit.state.electrumStatusError, isA<SpBackendUnreachable>());
        expect(cubit.state.blindbitStatus, SpConnectionStatus.ok);
        expect(cubit.state.canSave, isFalse);

        await cubit.saveBackendConfig();

        verifyNeverUpdate();
        await cubit.close();
      },
    );
  });
}
