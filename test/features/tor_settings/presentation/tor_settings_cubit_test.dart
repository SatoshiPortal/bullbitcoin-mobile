import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_proxy_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/check_external_tor_connection_usecase.dart';
import 'package:bb_mobile/features/tor_settings/presentation/bloc/tor_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';
import 'package:bull_tor/tor_adapter.dart';

class _MockGetSettingsUsecase extends Mock implements GetSettingsUsecase {}

class _MockUpdateTorProxyUsecase extends Mock
    implements UpdateTorProxyUsecase {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockUpdateTorTransportModeUsecase extends Mock
    implements UpdateTorTransportModeUsecase {}

class _MockWatchTorConnectionUsecase extends Mock
    implements WatchTorConnectionUsecase {}

CheckExternalTorConnectionUsecase _resolverFromPort(
  ExternalTorPort port, {
  int portNumber = 9050,
}) {
  final settings = _MockGetSettingsUsecase();
  final tor = _MockTor();
  final external = _MockExternalTor();
  when(settings.execute).thenAnswer(
    (_) async => SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
      useTorProxy: true,
      torProxyPort: portNumber,
    ),
  );
  when(() => tor.external).thenReturn(external);
  when(() => external.verify(any())).thenAnswer((invocation) async {
    final endpoint = invocation.positionalArguments.single as TorProxyEndpoint;
    try {
      await port.verify(endpoint);
      return TorReady(
        TorRoute(
          source: TorSource.external,
          endpoint: endpoint,
          evidence: TorReadinessEvidence.externalSocksHandshake,
        ),
      );
    } on Exception {
      return const TorUnavailable(
        source: TorSource.external,
        failure: TorExternalProxyUnavailableFailure(),
      );
    }
  });
  return CheckExternalTorConnectionUsecase(settings, tor);
}

class _MockTor extends Mock implements Tor {}

class _MockExternalTor extends Mock implements ExternalTor {}

class _FakeExternalTorPort implements ExternalTorPort {
  bool available = true;

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    if (!available) throw Exception('proxy unavailable');
  }
}

class _BlockingExternalTorPort implements ExternalTorPort {
  Completer<void> verificationStarted = Completer<void>();
  Completer<void> releaseVerification = Completer<void>();

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    verificationStarted.complete();
    await releaseVerification.future;
    verificationStarted = Completer<void>();
    releaseVerification = Completer<void>();
  }
}

class _BlockReplacementExternalTorPort implements ExternalTorPort {
  int calls = 0;
  final verificationStarted = Completer<void>();
  final releaseVerification = Completer<void>();

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    calls++;
    if (calls == 1) return;
    verificationStarted.complete();
    await releaseVerification.future;
  }
}

class _SignalingExternalTorPort implements ExternalTorPort {
  _SignalingExternalTorPort({required this.available});

  final bool available;
  final verificationStarted = Completer<void>();

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    verificationStarted.complete();
    if (!available) throw Exception('proxy unavailable');
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      TorProxyEndpoint(host: '127.0.0.1', port: 9050),
    );
  });
  test('does not emit when settings finish loading after close', () async {
    final getSettings = _MockGetSettingsUsecase();
    final settings = Completer<SettingsEntity>();
    when(() => getSettings.execute()).thenAnswer((_) => settings.future);

    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      watchTorConnectionUsecase: _MockWatchTorConnectionUsecase(),
      checkExternalTorConnectionUsecase: _resolverFromPort(
        _FakeExternalTorPort(),
      ),
    );

    final initialization = cubit.init();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    settings.complete(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );

    await expectLater(initialization, completes);
  });

  // The port sheet validates 1-65535 but the repository does not, so a corrupted
  // or legacy stored value used to throw *after* Connecting was emitted, leaving
  // the card spinning forever with the error unhandled.
  test(
    'an out-of-range stored port reports unavailable, not a spinner',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: true,
          torProxyPort: 0,
        ),
      );

      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());

      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
        checkExternalTorConnectionUsecase: _resolverFromPort(
          _FakeExternalTorPort(),
          portNumber: 0,
        ),
      );
      addTearDown(cubit.close);

      await cubit.init();

      expect(cubit.state.connection, isA<TorUnavailable>());
    },
  );

  test(
    'does not persist external proxy activation before verification',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.setTorProxy(
          enabled: any(named: 'enabled'),
          port: any(named: 'port'),
        ),
      ).thenAnswer((_) async {});
      final externalPort = _FakeExternalTorPort()..available = false;
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: UpdateTorProxyUsecase(
          settingsRepository,
          VerifyExternalTorUsecase(externalPort),
        ),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
        checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
      );
      addTearDown(cubit.close);

      await cubit.init();
      await cubit.updateTorSettings(useTorProxy: true, torProxyPort: 9050);

      expect(cubit.state.externalProxyAttempt, isA<TorUnavailable>());
      verifyNever(
        () => settingsRepository.setTorProxy(enabled: true, port: 9050),
      );
    },
  );

  test(
    'persists a verified activation through one atomic settings update',
    () async {
      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.setTorProxy(
          enabled: any(named: 'enabled'),
          port: any(named: 'port'),
        ),
      ).thenAnswer((_) async {});
      final usecase = UpdateTorProxyUsecase(
        settingsRepository,
        VerifyExternalTorUsecase(_FakeExternalTorPort()),
      );

      final connection = await usecase.execute(
        useTorProxy: true,
        torProxyPort: 9050,
      );

      expect(connection, isA<TorReady>());
      verify(
        () => settingsRepository.setTorProxy(enabled: true, port: 9050),
      ).called(1);
    },
  );

  test('revalidates the external proxy when refreshed after resume', () async {
    final getSettings = _MockGetSettingsUsecase();
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        useTorProxy: true,
        torProxyPort: 9050,
      ),
    );
    final externalPort = _FakeExternalTorPort();
    final watchTor = _MockWatchTorConnectionUsecase();
    when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
    );
    addTearDown(cubit.close);

    await cubit.init();
    expect(cubit.state.connection, isA<TorReady>());
    externalPort.available = false;
    await cubit.onAppResumed();

    expect(cubit.state.connection, isA<TorUnavailable>());
  });

  test(
    'continues publishing embedded Tor state while settings bootstrap changes',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      final embeddedStates = StreamController<TorConnectionState>();
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => embeddedStates.stream);
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
        checkExternalTorConnectionUsecase: _resolverFromPort(
          _FakeExternalTorPort(),
        ),
      );
      addTearDown(() async {
        await cubit.close();
        await embeddedStates.close();
      });

      await cubit.init();
      final state = TorReady(
        TorRoute(
          source: TorSource.embedded,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 19050),
          evidence: TorReadinessEvidence.embeddedBootstrap,
        ),
      );
      embeddedStates.add(state);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.embeddedConnection, same(state));
    },
  );

  test('does not persist a superseded activation after disabling', () async {
    final getSettings = _MockGetSettingsUsecase();
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    final settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.setTorProxy(
        enabled: any(named: 'enabled'),
        port: any(named: 'port'),
      ),
    ).thenAnswer((_) async {});
    final externalPort = _BlockingExternalTorPort();
    final watchTor = _MockWatchTorConnectionUsecase();
    when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: UpdateTorProxyUsecase(
        settingsRepository,
        VerifyExternalTorUsecase(externalPort),
      ),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
    );
    addTearDown(cubit.close);

    await cubit.init();
    final activation = cubit.updateTorSettings(
      useTorProxy: true,
      torProxyPort: 9050,
    );
    await externalPort.verificationStarted.future;
    expect(cubit.state.useTorProxy, isFalse);
    expect(cubit.state.externalProxyAttempt, isA<TorConnecting>());
    await cubit.updateTorSettings(useTorProxy: false, torProxyPort: 9050);
    externalPort.releaseVerification.complete();
    await activation;

    verify(
      () => settingsRepository.setTorProxy(enabled: false, port: 9050),
    ).called(1);
    verifyNever(
      () => settingsRepository.setTorProxy(enabled: true, port: 9050),
    );
  });

  test('shows a separate connecting attempt for a replacement port', () async {
    final getSettings = _MockGetSettingsUsecase();
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        useTorProxy: true,
        torProxyPort: 9050,
      ),
    );
    final settingsRepository = _MockSettingsRepository();
    final externalPort = _BlockReplacementExternalTorPort();
    final verifier = VerifyExternalTorUsecase(externalPort);
    when(
      () => settingsRepository.setTorProxy(
        enabled: any(named: 'enabled'),
        port: any(named: 'port'),
      ),
    ).thenAnswer((_) async {});
    final watchTor = _MockWatchTorConnectionUsecase();
    when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: UpdateTorProxyUsecase(
        settingsRepository,
        verifier,
      ),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
    );
    addTearDown(cubit.close);

    await cubit.init();
    final activeConnection = cubit.state.connection;
    final replacement = cubit.updateTorSettings(
      useTorProxy: true,
      torProxyPort: 9051,
    );
    await externalPort.verificationStarted.future;

    expect(cubit.state.connection, same(activeConnection));
    expect(cubit.state.externalProxyAttempt, isA<TorConnecting>());
    expect(cubit.state.externalProxyAttemptPort, 9051);
    externalPort.releaseVerification.complete();
    await replacement;
    expect(cubit.state.externalProxyAttempt, isNull);
    expect(cubit.state.externalProxyAttemptPort, isNull);
  });

  test('keeps the active endpoint when a replacement port fails', () async {
    final getSettings = _MockGetSettingsUsecase();
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        useTorProxy: true,
        torProxyPort: 9050,
      ),
    );
    final settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.setTorProxy(
        enabled: any(named: 'enabled'),
        port: any(named: 'port'),
      ),
    ).thenAnswer((_) async {});
    final externalPort = _FakeExternalTorPort();
    final watchTor = _MockWatchTorConnectionUsecase();
    when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: UpdateTorProxyUsecase(
        settingsRepository,
        VerifyExternalTorUsecase(externalPort),
      ),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
    );
    addTearDown(cubit.close);

    await cubit.init();
    final activeConnection = cubit.state.connection;
    externalPort.available = false;
    await cubit.updateTorSettings(useTorProxy: true, torProxyPort: 9051);

    expect(cubit.state.useTorProxy, isTrue);
    expect(cubit.state.torProxyPort, 9050);
    expect(cubit.state.connection, same(activeConnection));
    expect(cubit.state.externalProxyAttempt, isA<TorUnavailable>());
    expect(cubit.state.externalProxyAttemptPort, 9051);
  });

  test(
    'reports a persistence failure without losing the active endpoint',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: true,
          torProxyPort: 9050,
        ),
      );
      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.setTorProxy(
          enabled: any(named: 'enabled'),
          port: any(named: 'port'),
        ),
      ).thenThrow(Exception('settings secret'));
      final externalPort = _FakeExternalTorPort();
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: UpdateTorProxyUsecase(
          settingsRepository,
          VerifyExternalTorUsecase(externalPort),
        ),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
        checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
      );
      addTearDown(cubit.close);

      await cubit.init();
      await cubit.updateTorSettings(useTorProxy: true, torProxyPort: 9051);

      expect(cubit.state.useTorProxy, isTrue);
      expect(cubit.state.torProxyPort, 9050);
      expect(cubit.state.connection, isA<TorReady>());
      expect(cubit.state.externalProxyAttempt, isA<TorUnavailable>());
      expect(
        (cubit.state.externalProxyAttempt! as TorUnavailable).failure,
        isA<TorStorageFailure>(),
      );
    },
  );

  test('keeps an active proxy when disabling cannot be persisted', () async {
    final getSettings = _MockGetSettingsUsecase();
    when(() => getSettings.execute()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        useTorProxy: true,
        torProxyPort: 9050,
      ),
    );
    final settingsRepository = _MockSettingsRepository();
    when(
      () => settingsRepository.setTorProxy(enabled: false, port: 9050),
    ).thenThrow(Exception('settings secret'));
    final externalPort = _FakeExternalTorPort();
    final watchTor = _MockWatchTorConnectionUsecase();
    when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: UpdateTorProxyUsecase(
        settingsRepository,
        VerifyExternalTorUsecase(externalPort),
      ),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
    );
    addTearDown(cubit.close);

    await cubit.init();
    final activeConnection = cubit.state.connection;
    await cubit.updateTorSettings(useTorProxy: false, torProxyPort: 9050);

    expect(cubit.state.useTorProxy, isTrue);
    expect(cubit.state.torProxyPort, 9050);
    expect(cubit.state.connection, same(activeConnection));
    expect(cubit.state.externalProxyAttempt, isA<TorUnavailable>());
    expect(
      (cubit.state.externalProxyAttempt! as TorUnavailable).failure,
      isA<TorStorageFailure>(),
    );
  });

  test('does not apply settings loaded before a newer action', () async {
    final getSettings = _MockGetSettingsUsecase();
    final settings = Completer<SettingsEntity>();
    when(() => getSettings.execute()).thenAnswer((_) => settings.future);
    final updateProxy = _MockUpdateTorProxyUsecase();
    when(
      () => updateProxy.execute(
        useTorProxy: false,
        torProxyPort: 9050,
        isCurrent: any(named: 'isCurrent'),
      ),
    ).thenAnswer((_) async => const TorStopped(TorSource.external));
    final watchTor = _MockWatchTorConnectionUsecase();
    when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: updateProxy,
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(
        _FakeExternalTorPort(),
      ),
    );
    addTearDown(cubit.close);

    final refresh = cubit.onAppResumed();
    await Future<void>.delayed(Duration.zero);
    await cubit.updateTorSettings(useTorProxy: false, torProxyPort: 9050);
    settings.complete(
      const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
        useTorProxy: true,
        torProxyPort: 9050,
      ),
    );
    await refresh;

    expect(cubit.state.useTorProxy, isFalse);
  });

  test(
    'clears a connecting attempt when resume reloads proxy disabled',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      var fetchCount = 0;
      when(() => getSettings.execute()).thenAnswer((_) async {
        fetchCount++;
        return const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: false,
          torProxyPort: 9050,
        );
      });
      final settingsRepository = _MockSettingsRepository();
      when(
        () => settingsRepository.setTorProxy(
          enabled: any(named: 'enabled'),
          port: any(named: 'port'),
        ),
      ).thenAnswer((_) async {});
      final externalPort = _BlockingExternalTorPort();
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final verifier = VerifyExternalTorUsecase(externalPort);
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: UpdateTorProxyUsecase(
          settingsRepository,
          verifier,
        ),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
      );
      addTearDown(cubit.close);

      await cubit.init();
      final activation = cubit.updateTorSettings(
        useTorProxy: true,
        torProxyPort: 9050,
      );
      await externalPort.verificationStarted.future;
      expect(fetchCount, 1);
      expect(cubit.state.externalProxyAttempt, isA<TorConnecting>());

      await cubit.onAppResumed();

      expect(cubit.state.useTorProxy, isFalse);
      expect(cubit.state.externalProxyAttempt, isNull);
      externalPort.releaseVerification.complete();
      await activation;
    },
  );

  test(
    'clears an unavailable attempt when resume reloads proxy disabled',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: false,
          torProxyPort: 9050,
        ),
      );
      final settingsRepository = _MockSettingsRepository();
      final externalPort = _FakeExternalTorPort()..available = false;
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final verifier = VerifyExternalTorUsecase(externalPort);
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: UpdateTorProxyUsecase(
          settingsRepository,
          verifier,
        ),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
      );
      addTearDown(cubit.close);

      await cubit.init();
      await cubit.updateTorSettings(useTorProxy: true, torProxyPort: 9050);
      expect(cubit.state.externalProxyAttempt, isA<TorUnavailable>());

      await cubit.onAppResumed();

      expect(cubit.state.externalProxyAttempt, isNull);
    },
  );

  test(
    'does not bootstrap embedded Tor when the external proxy is enabled',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: true,
          torProxyPort: 9050,
        ),
      );
      final externalPort = _SignalingExternalTorPort(available: true);
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
      checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
      );
      addTearDown(cubit.close);

      await cubit.init();

      expect(externalPort.verificationStarted.isCompleted, isTrue);
      expect(cubit.state.connection, isA<TorReady>());
    },
  );

  test(
    'does not fall back to embedded Tor when the external proxy is unavailable',
    () async {
      final getSettings = _MockGetSettingsUsecase();
      when(() => getSettings.execute()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: true,
          torProxyPort: 9050,
        ),
      );
      final externalPort = _SignalingExternalTorPort(available: false);
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        watchTorConnectionUsecase: watchTor,
        checkExternalTorConnectionUsecase: _resolverFromPort(externalPort),
      );
      addTearDown(cubit.close);

      await cubit.init();

      expect(externalPort.verificationStarted.isCompleted, isTrue);
      expect(cubit.state.connection, isA<TorUnavailable>());
    },
  );
}
