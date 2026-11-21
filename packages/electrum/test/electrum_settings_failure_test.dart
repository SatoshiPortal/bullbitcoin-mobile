import 'package:electrum/src/domain/electrum_server.dart';
import 'package:electrum/src/domain/entities/electrum_settings.dart';
import 'package:electrum/src/domain/ports/electrum_tor_session_port.dart';
import 'package:electrum/src/domain/ports/server_status_port.dart';
import 'package:electrum/src/domain/repositories/electrum_server_repository.dart';
import 'package:electrum/src/domain/repositories/electrum_settings_repository.dart';
import 'package:electrum/src/domain/usecases/add_custom_server_usecase.dart';
import 'package:electrum/src/domain/usecases/load_electrum_server_data_usecase.dart';
import 'package:electrum/src/domain/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:electrum/electrum.dart';
import 'package:electrum/setup.dart';
import 'package:primitives/primitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockServerRepository extends Mock implements ElectrumServerRepository {}

class _MockSettingsRepository extends Mock
    implements ElectrumSettingsRepository {}

class _MockServerStatusPort extends Mock implements ServerStatusPort {}

class _MockTorSessionPort extends Mock implements ElectrumTorSessionPort {}

abstract interface class _PreferencesReader {
  Future<ElectrumPreferences> fetch();
}

class _MockAppSettingsRepository extends Mock implements _PreferencesReader {}

ElectrumPreferences _appSettings({bool useTorProxy = false, int port = 9050}) =>
    (
      isSuperuser: null,
      isDevModeEnabled: null,
      useTorProxy: useTorProxy,
      torProxyPort: port,
    );

const _network = ElectrumServerNetwork.bitcoinMainnet;

ElectrumSettings _settings({bool validateDomain = true}) => ElectrumSettings(
  stopGap: 20,
  timeout: 5,
  retry: 1,
  validateDomain: validateDomain,
  network: _network,
);

void main() {
  setUpAll(() {
    registerFallbackValue(_network);
    registerFallbackValue(TorProxyEndpoint(host: '127.0.0.1', port: 9050));
    registerFallbackValue(
      ElectrumServer.existing(
        url: 'ssl://fallback.example:50002',
        network: _network,
        isCustom: false,
        priority: 0,
      ),
    );
  });

  group('AddCustomServerUsecase', () {
    late _MockServerRepository serverRepo;
    late _MockSettingsRepository electrumSettingsRepo;
    late _MockServerStatusPort statusPort;
    late _MockTorSessionPort torSessionPort;
    late _MockAppSettingsRepository appSettingsRepository;
    late AddCustomServerUsecase usecase;

    ElectrumServer request() => ElectrumServer.createCustom(
      host: 'a.example',
      port: 50002,
      network: _network,
      priority: 0,
    );

    setUp(() {
      serverRepo = _MockServerRepository();
      electrumSettingsRepo = _MockSettingsRepository();
      statusPort = _MockServerStatusPort();
      torSessionPort = _MockTorSessionPort();
      appSettingsRepository = _MockAppSettingsRepository();
      when(() => appSettingsRepository.fetch())
          .thenAnswer((_) async => _appSettings());
      when(
        () => torSessionPort.open(
          network: any(named: 'network'),
          serverUrl: any(named: 'serverUrl'),
          isCustom: any(named: 'isCustom'),
          externalProxyEnabled: any(named: 'externalProxyEnabled'),
          externalProxyPort: any(named: 'externalProxyPort'),
        ),
      ).thenAnswer((_) async => null);
      usecase = AddCustomServerUsecase(
        electrumServerRepository: serverRepo,
        electrumSettingsRepository: electrumSettingsRepo,
        serverStatusPort: statusPort,
        torSessionPort: torSessionPort,
        readPreferences: appSettingsRepository.fetch,
      );
    });

    test('returns AlreadyExists failure when the server is present', () async {
      when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
          .thenAnswer(
            (_) async => Ok(
              ElectrumServer.existing(
                url: 'a.example:50002',
                network: _network,
                isCustom: true,
                priority: 0,
              ),
            ),
          );

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect(
        (result as Err).failure,
        isA<ElectrumServerAlreadyExistsFailure>(),
      );
    });

    test('propagates the load failure from fetchByUrl — no raw leak', () async {
      when(
        () => serverRepo.fetchByUrl(any(), network: any(named: 'network')),
      ).thenAnswer((_) async => const Err(ElectrumLoadFailure('raw db error')));

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ElectrumLoadFailure>());
    });

    test(
      'returns Unreachable failure when the Bitcoin probe is offline',
      () async {
        when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
            .thenAnswer((_) async => Ok(null));
        when(() => electrumSettingsRepo.fetchByNetwork(_network))
            .thenAnswer((_) async => Ok(_settings()));
        when(
          () => statusPort.checkElectrum(
            url: any(named: 'url'),
            network: _network,
            validateDomain: true,
            timeout: any(named: 'timeout'),
            retry: 1,
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        ).thenAnswer((_) async => ElectrumServerStatus.offline);

        final result = await usecase.execute(request());

        expect(result, isA<Err>());
        expect(
          (result as Err).failure,
          isA<ElectrumServerUnreachableFailure>(),
        );
      },
    );

    test('keeps the preliminary socket check for Liquid', () async {
      const liquidNetwork = ElectrumServerNetwork.liquidMainnet;
      when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
          .thenAnswer((_) async => Ok(null));
      when(() => electrumSettingsRepo.fetchByNetwork(liquidNetwork)).thenAnswer(
        (_) async => Ok(
          ElectrumSettings(
            stopGap: 20,
            timeout: 5,
            retry: 1,
            validateDomain: true,
            network: liquidNetwork,
          ),
        ),
      );
      when(
        () => statusPort.checkSocket(
          url: any(named: 'url'),
          timeout: any(named: 'timeout'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.offline);

      final result = await usecase.execute(
        ElectrumServer.createCustom(
          host: 'liquid.example',
          port: 995,
          network: liquidNetwork,
          priority: 0,
        ),
      );

      expect(result, isA<Err>());
      verify(
        () => statusPort.checkSocket(
          url: any(named: 'url'),
          timeout: any(named: 'timeout'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      ).called(1);
      verifyNever(
        () => statusPort.checkElectrum(
          url: any(named: 'url'),
          network: liquidNetwork,
          validateDomain: any(named: 'validateDomain'),
          timeout: any(named: 'timeout'),
          retry: any(named: 'retry'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      );
    });

    test(
      'probes with the user validateDomain setting, not a fixed one',
      () async {
        when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
            .thenAnswer((_) async => Ok(null));
        when(
          () => statusPort.checkSocket(
            url: any(named: 'url'),
            timeout: any(named: 'timeout'),
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        ).thenAnswer((_) async => ElectrumServerStatus.online);
        when(() => electrumSettingsRepo.fetchByNetwork(_network))
            .thenAnswer((_) async => Ok(_settings(validateDomain: false)));
        when(
          () => statusPort.checkElectrum(
            url: any(named: 'url'),
            network: _network,
            validateDomain: any(named: 'validateDomain'),
            timeout: any(named: 'timeout'),
            retry: any(named: 'retry'),
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        ).thenAnswer((_) async => ElectrumServerStatus.offline);

        final result = await usecase.execute(request());

        expect(result, isA<Err>());
        verify(
          () => statusPort.checkElectrum(
            url: any(named: 'url'),
            network: _network,
            validateDomain: false,
            timeout: 5,
            retry: 1,
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        ).called(1);
      },
    );

    test(
      'propagates the load failure when electrum settings are unreadable',
      () async {
        when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
            .thenAnswer((_) async => Ok(null));
        when(
          () => statusPort.checkSocket(
            url: any(named: 'url'),
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        ).thenAnswer((_) async => ElectrumServerStatus.online);
        when(() => electrumSettingsRepo.fetchByNetwork(_network)).thenAnswer(
          (_) async => const Err(ElectrumLoadFailure('raw db error')),
        );

        final result = await usecase.execute(request());

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<ElectrumLoadFailure>());
        verifyNever(
          () => statusPort.checkElectrum(
            url: any(named: 'url'),
            network: _network,
            validateDomain: any(named: 'validateDomain'),
            timeout: any(named: 'timeout'),
            retry: any(named: 'retry'),
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        );
      },
    );

    test('checks an onion server through a closed isolated route', () async {
      var routeClosed = false;
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);
      when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
          .thenAnswer((_) async => Ok(null));
      when(() => electrumSettingsRepo.fetchByNetwork(_network))
          .thenAnswer((_) async => Ok(_settings()));
      when(
        () => torSessionPort.open(
          network: _network,
          serverUrl: 'ssl://hidden.onion:50002',
          isCustom: true,
          externalProxyEnabled: false,
          externalProxyPort: 9050,
        ),
      ).thenAnswer(
        (_) async => ElectrumTorRoute(endpoint, () async => routeClosed = true),
      );
      when(
        () => statusPort.checkElectrum(
          url: 'ssl://hidden.onion:50002',
          network: _network,
          validateDomain: true,
          timeout: ElectrumConnection.onionMinimumTimeout,
          retry: 1,
          proxyEndpoint: endpoint,
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.offline);

      final result = await usecase.execute(
        ElectrumServer.createCustom(
          host: 'hidden.onion',
          port: 50002,
          network: _network,
          priority: 0,
        ),
      );

      expect(result, isA<Err>());
      expect(routeClosed, isTrue);
      verify(
        () => statusPort.checkElectrum(
          url: 'ssl://hidden.onion:50002',
          network: _network,
          validateDomain: true,
          timeout: ElectrumConnection.onionMinimumTimeout,
          retry: 1,
          proxyEndpoint: endpoint,
        ),
      ).called(1);
      verifyNever(
        () => statusPort.checkSocket(
          url: any(named: 'url'),
          timeout: any(named: 'timeout'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      );
    });

    test('passes a ready external route to a Bitcoin probe', () async {
      final externalRoute = TorRoute(
        source: TorSource.external,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41200),
        evidence: TorReadinessEvidence.externalSocksHandshake,
      );
      when(() => appSettingsRepository.fetch()).thenAnswer(
        (_) async =>
            _appSettings(useTorProxy: true, port: externalRoute.endpoint.port),
      );
      when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
          .thenAnswer((_) async => Ok(null));
      when(() => electrumSettingsRepo.fetchByNetwork(_network))
          .thenAnswer((_) async => Ok(_settings()));
      when(
        () => torSessionPort.open(
          network: _network,
          serverUrl: any(named: 'serverUrl'),
          isCustom: true,
          externalProxyEnabled: true,
          externalProxyPort: externalRoute.endpoint.port,
        ),
      ).thenAnswer(
        (_) async => ElectrumTorRoute(externalRoute.endpoint, () async {}),
      );
      when(
        () => statusPort.checkSocket(
          url: any(named: 'url'),
          timeout: any(named: 'timeout'),
          proxyEndpoint: externalRoute.endpoint,
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.online);
      when(
        () => statusPort.checkElectrum(
          url: any(named: 'url'),
          network: _network,
          validateDomain: true,
          timeout: 5,
          retry: 1,
          proxyEndpoint: externalRoute.endpoint,
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.online);
      when(() => serverRepo.save(any()))
          .thenAnswer((_) async => const Ok(null));

      final result = await usecase.execute(request());

      expect(result, isA<Ok>());
      verify(() => appSettingsRepository.fetch()).called(greaterThan(0));
      verify(
        () => torSessionPort.open(
          network: _network,
          serverUrl: any(named: 'serverUrl'),
          isCustom: true,
          externalProxyEnabled: true,
          externalProxyPort: externalRoute.endpoint.port,
        ),
      ).called(1);
      verifyNever(
        () => statusPort.checkSocket(
          url: any(named: 'url'),
          timeout: any(named: 'timeout'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      );
      verify(
        () => statusPort.checkElectrum(
          url: any(named: 'url'),
          network: _network,
          validateDomain: true,
          timeout: 5,
          retry: 1,
          proxyEndpoint: externalRoute.endpoint,
        ),
      ).called(1);
    });

    test('fails closed when external Tor is unavailable', () async {
      when(() => appSettingsRepository.fetch())
          .thenAnswer((_) async => _appSettings(useTorProxy: true));
      when(() => serverRepo.fetchByUrl(any(), network: any(named: 'network')))
          .thenAnswer((_) async => Ok(null));
      when(() => electrumSettingsRepo.fetchByNetwork(_network))
          .thenAnswer((_) async => Ok(_settings()));
      when(
        () => torSessionPort.open(
          network: any(named: 'network'),
          serverUrl: any(named: 'serverUrl'),
          isCustom: any(named: 'isCustom'),
          externalProxyEnabled: any(named: 'externalProxyEnabled'),
          externalProxyPort: any(named: 'externalProxyPort'),
        ),
      ).thenThrow(OnionServerWithoutTorException('hidden.onion'));

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect(
        (result as Err).failure,
        isA<ElectrumExternalTorProxyUnavailableFailure>(),
      );
      verify(
        () => torSessionPort.open(
          network: any(named: 'network'),
          serverUrl: any(named: 'serverUrl'),
          isCustom: any(named: 'isCustom'),
          externalProxyEnabled: any(named: 'externalProxyEnabled'),
          externalProxyPort: any(named: 'externalProxyPort'),
        ),
      ).called(1);
      verifyNever(
        () => statusPort.checkSocket(
          url: any(named: 'url'),
          timeout: any(named: 'timeout'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      );
    });
  });

  group('SetAdvancedElectrumOptionsUsecase', () {
    late _MockSettingsRepository settingsRepo;
    late SetAdvancedElectrumOptionsUsecase usecase;

    ElectrumOptions request(int stopGap) => ElectrumOptions(
      stopGap: stopGap,
      timeout: 5,
      retry: 1,
      validateDomain: true,
      network: _network,
    );

    setUp(() {
      settingsRepo = _MockSettingsRepository();
      usecase = SetAdvancedElectrumOptionsUsecase(
        electrumSettingsRepository: settingsRepo,
      );
    });

    test('propagates the load failure from fetchByNetwork', () async {
      when(
        () => settingsRepo.fetchByNetwork(_network),
      ).thenAnswer((_) async => const Err(ElectrumLoadFailure('raw db error')));

      final result = await usecase.execute(request(20));

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ElectrumLoadFailure>());
    });

    test(
      'maps invalid stopGap to a sanitized failure carrying the value',
      () async {
        when(() => settingsRepo.fetchByNetwork(_network))
            .thenAnswer((_) async => Ok(_settings()));

        final result = await usecase.execute(request(-1));

        expect(result, isA<Err>());
        final failure = (result as Err).failure;
        expect(failure, isA<ElectrumInvalidStopGapFailure>());
        expect((failure as ElectrumInvalidStopGapFailure).value, -1);
      },
    );
  });

  group('LoadElectrumServerDataUsecase', () {
    test(
      'maps a throwing dependency to a sanitized failure — no raw leak',
      () async {
        final serverRepo = _MockServerRepository();
        final settingsRepo = _MockSettingsRepository();

        final statusPort = _MockServerStatusPort();
        final torSessionPort = _MockTorSessionPort();
        final appSettingsRepository = _MockAppSettingsRepository();
        final usecase = LoadElectrumServerDataUsecase(
          electrumServerRepository: serverRepo,
          electrumSettingsRepository: settingsRepo,

          serverStatusPort: statusPort,
          torSessionPort: torSessionPort,
          readPreferences: appSettingsRepository.fetch,
        );
        when(() => serverRepo.fetchAll(network: _network))
            .thenAnswer((_) async => const Ok([]));
        when(() => settingsRepo.fetchByNetwork(_network))
            .thenThrow(Exception('boom'));

        final result = await usecase.execute(network: _network);

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<ElectrumUnexpectedFailure>());
      },
    );

    test('checks an onion server through a closed isolated route', () async {
      final serverRepo = _MockServerRepository();
      final settingsRepo = _MockSettingsRepository();

      final statusPort = _MockServerStatusPort();
      final torSessionPort = _MockTorSessionPort();
      final appSettingsRepository = _MockAppSettingsRepository();
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41002);
      when(() => appSettingsRepository.fetch())
          .thenAnswer((_) async => _appSettings());
      var routeClosed = false;
      final server = ElectrumServer.existing(
        url: 'ssl://hidden.onion:50002',
        network: _network,
        isCustom: false,
        priority: 0,
      );
      final usecase = LoadElectrumServerDataUsecase(
        electrumServerRepository: serverRepo,
        electrumSettingsRepository: settingsRepo,

        serverStatusPort: statusPort,
        torSessionPort: torSessionPort,
        readPreferences: appSettingsRepository.fetch,
      );

      when(
        () =>
            serverRepo.fetchAll(network: ElectrumServerNetwork.bitcoinMainnet),
      ).thenAnswer((_) async => Ok([server]));
      when(() => settingsRepo.fetchByNetwork(_network))
          .thenAnswer((_) async => Ok(_settings()));
      when(
        () => torSessionPort.open(
          network: _network,
          serverUrl: server.url,
          isCustom: false,
          externalProxyEnabled: false,
          externalProxyPort: 9050,
        ),
      ).thenAnswer(
        (_) async => ElectrumTorRoute(endpoint, () async => routeClosed = true),
      );
      when(
        () => statusPort.checkElectrum(
          url: server.url,
          network: _network,
          validateDomain: true,
          timeout: ElectrumConnection.onionMinimumTimeout,
          retry: 1,
          proxyEndpoint: endpoint,
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.online);

      final updates = <ElectrumServerChecks>[];
      final result = await usecase.execute(
        network: _network,
        onUpdate: updates.add,
      );

      expect(result, isA<Ok>());
      expect(
        updates.first.serverStatuses[server.url],
        ElectrumServerStatus.unknown,
      );
      expect(
        updates.last.serverStatuses[server.url],
        ElectrumServerStatus.online,
      );
      expect(routeClosed, isTrue);
      verify(
        () => statusPort.checkElectrum(
          url: server.url,
          network: _network,
          validateDomain: true,
          timeout: ElectrumConnection.onionMinimumTimeout,
          retry: 1,
          proxyEndpoint: endpoint,
        ),
      ).called(1);
    });

    test(
      'resolves external Tor once and reuses it for all Bitcoin servers',
      () async {
        final serverRepo = _MockServerRepository();
        final settingsRepo = _MockSettingsRepository();

        final statusPort = _MockServerStatusPort();
        final torSessionPort = _MockTorSessionPort();
        final appSettingsRepository = _MockAppSettingsRepository();
        final externalRoute = TorRoute(
          source: TorSource.external,
          endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41201),
          evidence: TorReadinessEvidence.externalSocksHandshake,
        );
        final servers = [
          ElectrumServer.existing(
            url: 'ssl://a.onion:50002',
            network: _network,
            isCustom: true,
            priority: 0,
          ),
          ElectrumServer.existing(
            url: 'ssl://b.onion:50002',
            network: _network,
            isCustom: true,
            priority: 1,
          ),
        ];

        when(
          () => serverRepo.fetchAll(
            network: ElectrumServerNetwork.bitcoinMainnet,
          ),
        ).thenAnswer((_) async => Ok(servers));
        when(() => settingsRepo.fetchByNetwork(_network))
            .thenAnswer((_) async => Ok(_settings()));
        when(() => appSettingsRepository.fetch()).thenAnswer(
          (_) async => _appSettings(
            useTorProxy: true,
            port: externalRoute.endpoint.port,
          ),
        );
        when(
          () => torSessionPort.open(
            network: _network,
            serverUrl: any(named: 'serverUrl'),
            isCustom: true,
            externalProxyEnabled: true,
            externalProxyPort: externalRoute.endpoint.port,
          ),
        ).thenAnswer(
          (_) async => ElectrumTorRoute(externalRoute.endpoint, () async {}),
        );
        when(
          () => statusPort.checkElectrum(
            url: any(named: 'url'),
            network: _network,
            validateDomain: true,
            timeout: ElectrumConnection.onionMinimumTimeout,
            retry: 1,
            proxyEndpoint: externalRoute.endpoint,
          ),
        ).thenAnswer((_) async => ElectrumServerStatus.online);
        final usecase = LoadElectrumServerDataUsecase(
          electrumServerRepository: serverRepo,
          electrumSettingsRepository: settingsRepo,

          serverStatusPort: statusPort,
          torSessionPort: torSessionPort,
          readPreferences: appSettingsRepository.fetch,
        );

        final result = await usecase.execute(network: _network);

        expect(result, isA<Ok>());
        verify(
          () => torSessionPort.open(
            network: _network,
            serverUrl: any(named: 'serverUrl'),
            isCustom: true,
            externalProxyEnabled: true,
            externalProxyPort: externalRoute.endpoint.port,
          ),
        ).called(2);
      },
    );

    test('marks all Bitcoin probes offline without opening sockets when unavailable', () async {
      final serverRepo = _MockServerRepository();
      final settingsRepo = _MockSettingsRepository();

      final statusPort = _MockServerStatusPort();
      final torSessionPort = _MockTorSessionPort();
      final appSettingsRepository = _MockAppSettingsRepository();
      final server = ElectrumServer.existing(
        url: 'ssl://a.onion:50002',
        network: _network,
        isCustom: true,
        priority: 0,
      );

      when(
        () =>
            serverRepo.fetchAll(network: ElectrumServerNetwork.bitcoinMainnet),
      ).thenAnswer((_) async => Ok([server]));
      when(() => settingsRepo.fetchByNetwork(_network))
          .thenAnswer((_) async => Ok(_settings()));
      when(() => appSettingsRepository.fetch())
          .thenAnswer((_) async => _appSettings(useTorProxy: true));
      when(
        () => torSessionPort.open(
          network: any(named: 'network'),
          serverUrl: any(named: 'serverUrl'),
          isCustom: any(named: 'isCustom'),
          externalProxyEnabled: any(named: 'externalProxyEnabled'),
          externalProxyPort: any(named: 'externalProxyPort'),
        ),
      ).thenThrow(OnionServerWithoutTorException(server.url));
      final usecase = LoadElectrumServerDataUsecase(
        electrumServerRepository: serverRepo,
        electrumSettingsRepository: settingsRepo,

        serverStatusPort: statusPort,
        torSessionPort: torSessionPort,
        readPreferences: appSettingsRepository.fetch,
      );

      final result = await usecase.execute(network: _network);

      expect(result, isA<Ok>());
      final response = (result as Ok).value;
      expect(response.serverStatuses[server.url], ElectrumServerStatus.offline);
      verify(
        () => torSessionPort.open(
          network: any(named: 'network'),
          serverUrl: any(named: 'serverUrl'),
          isCustom: any(named: 'isCustom'),
          externalProxyEnabled: any(named: 'externalProxyEnabled'),
          externalProxyPort: any(named: 'externalProxyPort'),
        ),
      ).called(1);
      verifyNever(
        () => statusPort.checkElectrum(
          url: any(named: 'url'),
          network: any(named: 'network'),
          validateDomain: any(named: 'validateDomain'),
          timeout: any(named: 'timeout'),
          retry: any(named: 'retry'),
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      );
    });
  });
}
