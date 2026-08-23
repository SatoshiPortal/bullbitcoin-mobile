import 'dart:async';

import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_proxy_usecase.dart';
import 'package:bb_mobile/features/tor_settings/domain/update_tor_transport_mode_usecase.dart';
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

class _MockEnsureTorReadyUsecase extends Mock
    implements EnsureTorReadyUsecase {}

class _MockWatchTorConnectionUsecase extends Mock
    implements WatchTorConnectionUsecase {}

class _FakeExternalTorPort implements ExternalTorPort {
  bool available = true;

  @override
  Future<void> verify(TorProxyEndpoint endpoint) async {
    if (!available) throw StateError('proxy unavailable');
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
    if (!available) throw StateError('proxy unavailable');
  }
}

void main() {
  test('does not emit when settings finish loading after close', () async {
    final getSettings = _MockGetSettingsUsecase();
    final settings = Completer<SettingsEntity>();
    when(() => getSettings.execute()).thenAnswer((_) => settings.future);

    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      ensureTorReadyUsecase: _MockEnsureTorReadyUsecase(),
      watchTorConnectionUsecase: _MockWatchTorConnectionUsecase(),
      verifyExternalTorUsecase: VerifyExternalTorUsecase(
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
      final ensureTor = _MockEnsureTorReadyUsecase();
      when(
        () => ensureTor.execute(),
      ).thenAnswer((_) async => const TorUninitialized());

      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        ensureTorReadyUsecase: ensureTor,
        watchTorConnectionUsecase: watchTor,
        verifyExternalTorUsecase: VerifyExternalTorUsecase(
          _FakeExternalTorPort(),
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
      final ensureTor = _MockEnsureTorReadyUsecase();
      when(
        () => ensureTor.execute(),
      ).thenAnswer((_) async => const TorUninitialized());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: UpdateTorProxyUsecase(
          settingsRepository,
          VerifyExternalTorUsecase(externalPort),
        ),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        ensureTorReadyUsecase: ensureTor,
        watchTorConnectionUsecase: watchTor,
        verifyExternalTorUsecase: VerifyExternalTorUsecase(externalPort),
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
      verifyNever(() => settingsRepository.setUseTorProxy(any()));
      verifyNever(() => settingsRepository.setTorProxyPort(any()));
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
    final ensureTor = _MockEnsureTorReadyUsecase();
    when(
      () => ensureTor.execute(),
    ).thenAnswer((_) async => const TorUninitialized());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      ensureTorReadyUsecase: ensureTor,
      watchTorConnectionUsecase: watchTor,
      verifyExternalTorUsecase: VerifyExternalTorUsecase(externalPort),
    );
    addTearDown(cubit.close);

    await cubit.init();
    expect(cubit.state.connection, isA<TorReady>());
    externalPort.available = false;
    await cubit.onAppResumed();

    expect(cubit.state.connection, isA<TorUnavailable>());
  });

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
    final ensureTor = _MockEnsureTorReadyUsecase();
    when(
      () => ensureTor.execute(),
    ).thenAnswer((_) async => const TorUninitialized());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: UpdateTorProxyUsecase(
        settingsRepository,
        VerifyExternalTorUsecase(externalPort),
      ),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      ensureTorReadyUsecase: ensureTor,
      watchTorConnectionUsecase: watchTor,
      verifyExternalTorUsecase: VerifyExternalTorUsecase(externalPort),
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
    final ensureTor = _MockEnsureTorReadyUsecase();
    when(
      () => ensureTor.execute(),
    ).thenAnswer((_) async => const TorUninitialized());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: UpdateTorProxyUsecase(
        settingsRepository,
        verifier,
      ),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      ensureTorReadyUsecase: ensureTor,
      watchTorConnectionUsecase: watchTor,
      verifyExternalTorUsecase: verifier,
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
    externalPort.releaseVerification.complete();
    await replacement;
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
    final ensureTor = _MockEnsureTorReadyUsecase();
    when(
      () => ensureTor.execute(),
    ).thenAnswer((_) async => const TorUninitialized());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: UpdateTorProxyUsecase(
        settingsRepository,
        VerifyExternalTorUsecase(externalPort),
      ),
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      ensureTorReadyUsecase: ensureTor,
      watchTorConnectionUsecase: watchTor,
      verifyExternalTorUsecase: VerifyExternalTorUsecase(externalPort),
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
    final ensureTor = _MockEnsureTorReadyUsecase();
    when(
      () => ensureTor.execute(),
    ).thenAnswer((_) async => const TorUninitialized());
    final cubit = TorSettingsCubit(
      getSettingsUsecase: getSettings,
      updateTorProxyUsecase: updateProxy,
      updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
      ensureTorReadyUsecase: ensureTor,
      watchTorConnectionUsecase: watchTor,
      verifyExternalTorUsecase: VerifyExternalTorUsecase(
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
      final verifier = VerifyExternalTorUsecase(externalPort);
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final ensureTor = _MockEnsureTorReadyUsecase();
      when(
        () => ensureTor.execute(),
      ).thenAnswer((_) async => const TorUninitialized());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: UpdateTorProxyUsecase(
          settingsRepository,
          verifier,
        ),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        ensureTorReadyUsecase: ensureTor,
        watchTorConnectionUsecase: watchTor,
        verifyExternalTorUsecase: verifier,
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
      final verifier = VerifyExternalTorUsecase(externalPort);
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final ensureTor = _MockEnsureTorReadyUsecase();
      when(
        () => ensureTor.execute(),
      ).thenAnswer((_) async => const TorUninitialized());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: UpdateTorProxyUsecase(
          settingsRepository,
          verifier,
        ),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        ensureTorReadyUsecase: ensureTor,
        watchTorConnectionUsecase: watchTor,
        verifyExternalTorUsecase: verifier,
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
    'checks the external proxy before embedded bootstrap completes',
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
      final ensureStarted = Completer<void>();
      final releaseEnsure = Completer<TorConnectionState>();
      final ensureTor = _MockEnsureTorReadyUsecase();
      when(() => ensureTor.execute()).thenAnswer((_) async {
        ensureStarted.complete();
        return releaseEnsure.future;
      });
      final externalPort = _SignalingExternalTorPort(available: true);
      final verifier = VerifyExternalTorUsecase(externalPort);
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        ensureTorReadyUsecase: ensureTor,
        watchTorConnectionUsecase: watchTor,
        verifyExternalTorUsecase: verifier,
      );
      addTearDown(cubit.close);

      final initialization = cubit.init();
      await ensureStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(externalPort.verificationStarted.isCompleted, isTrue);
      expect(cubit.state.connection, isA<TorReady>());
      releaseEnsure.complete(const TorUninitialized());
      await initialization;
    },
  );

  test(
    'shows an external SOCKS failure before embedded bootstrap completes',
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
      final ensureStarted = Completer<void>();
      final releaseEnsure = Completer<TorConnectionState>();
      final ensureTor = _MockEnsureTorReadyUsecase();
      when(() => ensureTor.execute()).thenAnswer((_) async {
        ensureStarted.complete();
        return releaseEnsure.future;
      });
      final externalPort = _SignalingExternalTorPort(available: false);
      final verifier = VerifyExternalTorUsecase(externalPort);
      final watchTor = _MockWatchTorConnectionUsecase();
      when(() => watchTor.execute()).thenAnswer((_) => const Stream.empty());
      final cubit = TorSettingsCubit(
        getSettingsUsecase: getSettings,
        updateTorProxyUsecase: _MockUpdateTorProxyUsecase(),
        updateTorTransportModeUsecase: _MockUpdateTorTransportModeUsecase(),
        ensureTorReadyUsecase: ensureTor,
        watchTorConnectionUsecase: watchTor,
        verifyExternalTorUsecase: verifier,
      );
      addTearDown(cubit.close);

      final initialization = cubit.init();
      await ensureStarted.future;
      await Future<void>.delayed(Duration.zero);

      expect(externalPort.verificationStarted.isCompleted, isTrue);
      expect(cubit.state.connection, isA<TorUnavailable>());
      releaseEnsure.complete(const TorUninitialized());
      await initialization;
    },
  );
}
