import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/delete_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_advanced_electrum_options_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_custom_servers_priority_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/entities/electrum_settings.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_tor_session_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_environment.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _MockServerRepository extends Mock implements ElectrumServerRepository {}

class _MockSettingsRepository extends Mock
    implements ElectrumSettingsRepository {}

class _MockServerStatusPort extends Mock implements ServerStatusPort {}

class _MockEnvironmentPort extends Mock implements EnvironmentPort {}

class _MockTorSessionPort extends Mock implements ElectrumTorSessionPort {}

class _MockAppSettingsRepository extends Mock implements SettingsRepository {}

SettingsEntity _appSettings({bool useTorProxy = false, int port = 9050}) =>
    SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'USD',
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
    registerFallbackValue(
      TorProxyEndpoint(host: '127.0.0.1', port: 9050),
    );
    registerFallbackValue(
      ElectrumServer.existing(
        url: 'ssl://fallback.example:50002',
        network: _network,
        isCustom: false,
        priority: 0,
      ),
    );
  });

  group('DeleteCustomServerUsecase', () {
    test('propagates the sanitized failure from the repository', () async {
      final repo = _MockServerRepository();
      final usecase = DeleteCustomServerUsecase(electrumServerRepository: repo);
      when(() => repo.delete(url: any(named: 'url'))).thenAnswer(
        (_) async => const Err(ElectrumDeleteFailure('raw db error')),
      );

      final result = await usecase.execute(
        DeleteCustomServerRequest(url: 'ssl://a:50002'),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ElectrumDeleteFailure>());
    });
  });

  group('AddCustomServerUsecase', () {
    late _MockServerRepository serverRepo;
    late _MockSettingsRepository electrumSettingsRepo;
    late _MockServerStatusPort statusPort;
    late _MockTorSessionPort torSessionPort;
    late _MockAppSettingsRepository appSettingsRepository;
    late AddCustomServerUsecase usecase;

    AddCustomServerRequest request() => AddCustomServerRequest(
      server: ElectrumServerDto(
        url: 'a.example:50002',
        network: _network,
        isCustom: true,
        priority: 0,
      ),
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
        settingsRepository: appSettingsRepository,
      );
    });

    test('returns AlreadyExists failure when the server is present', () async {
      when(() => serverRepo.fetchByUrl(any())).thenAnswer(
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
        () => serverRepo.fetchByUrl(any()),
      ).thenAnswer((_) async => const Err(ElectrumLoadFailure('raw db error')));

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ElectrumLoadFailure>());
    });

    test(
      'returns Unreachable failure when the socket check is offline',
      () async {
        when(
          () => serverRepo.fetchByUrl(any()),
        ).thenAnswer((_) async => Ok(null));
        when(
          () => electrumSettingsRepo.fetchByNetwork(_network),
        ).thenAnswer((_) async => Ok(_settings()));
        when(
          () => statusPort.checkSocket(
            url: any(named: 'url'),
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

    test(
      'probes with the user validateDomain setting, not a fixed one',
      () async {
        when(
          () => serverRepo.fetchByUrl(any()),
        ).thenAnswer((_) async => Ok(null));
        when(
          () => statusPort.checkSocket(
            url: any(named: 'url'),
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        ).thenAnswer((_) async => ElectrumServerStatus.online);
        when(
          () => electrumSettingsRepo.fetchByNetwork(_network),
        ).thenAnswer((_) async => Ok(_settings(validateDomain: false)));
        when(
          () => statusPort.checkElectrum(
            url: any(named: 'url'),
            network: _network,
            validateDomain: any(named: 'validateDomain'),
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
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        ).called(1);
      },
    );

    test(
      'propagates the load failure when electrum settings are unreadable',
      () async {
        when(
          () => serverRepo.fetchByUrl(any()),
        ).thenAnswer((_) async => Ok(null));
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
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        );
      },
    );

    test('checks an onion server through a closed isolated route', () async {
      var routeClosed = false;
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41001);
      when(
        () => serverRepo.fetchByUrl(any()),
      ).thenAnswer((_) async => Ok(null));
      when(
        () => electrumSettingsRepo.fetchByNetwork(_network),
      ).thenAnswer((_) async => Ok(_settings()));
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
        () => statusPort.checkSocket(
          url: 'ssl://hidden.onion:50002',
          proxyEndpoint: endpoint,
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.offline);

      final result = await usecase.execute(
        AddCustomServerRequest(
          server: ElectrumServerDto(
            url: 'hidden.onion:50002',
            network: _network,
            isCustom: true,
            priority: 0,
          ),
        ),
      );

      expect(result, isA<Err>());
      expect(routeClosed, isTrue);
      verify(
        () => statusPort.checkSocket(
          url: 'ssl://hidden.onion:50002',
          proxyEndpoint: endpoint,
        ),
      ).called(1);
    });

    test('passes a ready external route to a Bitcoin probe', () async {
      final externalRoute = TorRoute(
        source: TorSource.external,
        endpoint: TorProxyEndpoint(host: '127.0.0.1', port: 41200),
        evidence: TorReadinessEvidence.externalSocksHandshake,
      );
      when(
        () => appSettingsRepository.fetch(),
      ).thenAnswer(
        (_) async => _appSettings(useTorProxy: true, port: externalRoute.endpoint.port),
      );
      when(
        () => serverRepo.fetchByUrl(any()),
      ).thenAnswer((_) async => Ok(null));
      when(
        () => electrumSettingsRepo.fetchByNetwork(_network),
      ).thenAnswer((_) async => Ok(_settings()));
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
          proxyEndpoint: externalRoute.endpoint,
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.online);
      when(
        () => statusPort.checkElectrum(
          url: any(named: 'url'),
          network: _network,
          validateDomain: true,
          proxyEndpoint: externalRoute.endpoint,
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.online);
      when(
        () => serverRepo.save(any()),
      ).thenAnswer((_) async => const Ok(null));

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
    });

    test('fails closed when external Tor is unavailable', () async {
      when(() => appSettingsRepository.fetch())
          .thenAnswer((_) async => _appSettings(useTorProxy: true));
      when(
        () => serverRepo.fetchByUrl(any()),
      ).thenAnswer((_) async => Ok(null));
      when(
        () => electrumSettingsRepo.fetchByNetwork(_network),
      ).thenAnswer((_) async => Ok(_settings()));
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
          proxyEndpoint: any(named: 'proxyEndpoint'),
        ),
      );
    });
  });

  group('SetAdvancedElectrumOptionsUsecase', () {
    late _MockSettingsRepository settingsRepo;
    late SetAdvancedElectrumOptionsUsecase usecase;

    SetAdvancedElectrumOptionsRequest request(int stopGap) =>
        SetAdvancedElectrumOptionsRequest(
          options: ElectrumSettingsDto(
            stopGap: stopGap,
            timeout: 5,
            retry: 1,
            validateDomain: true,
            network: _network,
          ),
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
        when(
          () => settingsRepo.fetchByNetwork(_network),
        ).thenAnswer((_) async => Ok(_settings()));

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
        final envPort = _MockEnvironmentPort();
        final statusPort = _MockServerStatusPort();
        final torSessionPort = _MockTorSessionPort();
        final appSettingsRepository = _MockAppSettingsRepository();
        final usecase = LoadElectrumServerDataUsecase(
          electrumServerRepository: serverRepo,
          electrumSettingsRepository: settingsRepo,
          environmentPort: envPort,
          serverStatusPort: statusPort,
          torSessionPort: torSessionPort,
          settingsRepository: appSettingsRepository,
        );
        // EnvironmentPort still throws; the use-case is the boundary that maps it.
        when(() => envPort.getEnvironment()).thenThrow(Exception('boom'));

        final result = await usecase.execute(
          LoadElectrumServerDataRequest(isLiquid: false),
        );

        expect(result, isA<Err>());
        expect((result as Err).failure, isA<ElectrumUnexpectedFailure>());
      },
    );

    test('checks an onion server through a closed isolated route', () async {
      final serverRepo = _MockServerRepository();
      final settingsRepo = _MockSettingsRepository();
      final envPort = _MockEnvironmentPort();
      final statusPort = _MockServerStatusPort();
      final torSessionPort = _MockTorSessionPort();
      final appSettingsRepository = _MockAppSettingsRepository();
      final endpoint = TorProxyEndpoint(host: '127.0.0.1', port: 41002);
      when(
        () => appSettingsRepository.fetch(),
      ).thenAnswer((_) async => _appSettings());
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
        environmentPort: envPort,
        serverStatusPort: statusPort,
        torSessionPort: torSessionPort,
        settingsRepository: appSettingsRepository,
      );
      when(
        () => envPort.getEnvironment(),
      ).thenAnswer((_) async => ElectrumEnvironment.mainnet);
      when(
        () => serverRepo.fetchAll(isTestnet: false, isLiquid: false),
      ).thenAnswer((_) async => Ok([server]));
      when(
        () => settingsRepo.fetchByNetwork(_network),
      ).thenAnswer((_) async => Ok(_settings()));
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
        () => statusPort.checkSocket(url: server.url, proxyEndpoint: endpoint),
      ).thenAnswer((_) async => ElectrumServerStatus.online);

      final result = await usecase.execute(
        LoadElectrumServerDataRequest(isLiquid: false),
      );

      expect(result, isA<Ok>());
      expect(routeClosed, isTrue);
      verify(
        () => statusPort.checkSocket(url: server.url, proxyEndpoint: endpoint),
      ).called(1);
    });

    test(
      'resolves external Tor once and reuses it for all Bitcoin servers',
      () async {
        final serverRepo = _MockServerRepository();
        final settingsRepo = _MockSettingsRepository();
        final envPort = _MockEnvironmentPort();
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
          () => envPort.getEnvironment(),
        ).thenAnswer((_) async => ElectrumEnvironment.mainnet);
        when(
          () => serverRepo.fetchAll(isTestnet: false, isLiquid: false),
        ).thenAnswer((_) async => Ok(servers));
        when(
          () => settingsRepo.fetchByNetwork(_network),
        ).thenAnswer((_) async => Ok(_settings()));
        when(() => appSettingsRepository.fetch())
            .thenAnswer((_) async => _appSettings(useTorProxy: true, port: externalRoute.endpoint.port));
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
            proxyEndpoint: externalRoute.endpoint,
          ),
        ).thenAnswer((_) async => ElectrumServerStatus.online);
        final usecase = LoadElectrumServerDataUsecase(
          electrumServerRepository: serverRepo,
          electrumSettingsRepository: settingsRepo,
          environmentPort: envPort,
          serverStatusPort: statusPort,
          torSessionPort: torSessionPort,
          settingsRepository: appSettingsRepository,
        );

        final result = await usecase.execute(
          LoadElectrumServerDataRequest(isLiquid: false),
        );

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

    test(
      'marks all Bitcoin probes offline without opening sockets when unavailable',
      () async {
        final serverRepo = _MockServerRepository();
        final settingsRepo = _MockSettingsRepository();
        final envPort = _MockEnvironmentPort();
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
          () => envPort.getEnvironment(),
        ).thenAnswer((_) async => ElectrumEnvironment.mainnet);
        when(
          () => serverRepo.fetchAll(isTestnet: false, isLiquid: false),
        ).thenAnswer((_) async => Ok([server]));
        when(
          () => settingsRepo.fetchByNetwork(_network),
        ).thenAnswer((_) async => Ok(_settings()));
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
          environmentPort: envPort,
          serverStatusPort: statusPort,
          torSessionPort: torSessionPort,
          settingsRepository: appSettingsRepository,
        );

        final result = await usecase.execute(
          LoadElectrumServerDataRequest(isLiquid: false),
        );

        expect(result, isA<Ok>());
        final response = (result as Ok).value;
        expect(
          response.serverStatuses[server.url],
          ElectrumServerStatus.offline,
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
            proxyEndpoint: any(named: 'proxyEndpoint'),
          ),
        );
      },
    );
  });

  group('SetCustomServersPriorityUsecase', () {
    setUpAll(() {
      registerFallbackValue(<ElectrumServer>[]);
    });

    test('propagates the save failure from batchSave — no raw leak', () async {
      final repo = _MockServerRepository();
      final usecase = SetCustomServersPriorityUsecase(
        electrumServerRepository: repo,
      );
      when(
        () => repo.batchSave(any()),
      ).thenAnswer((_) async => const Err(ElectrumSaveFailure('raw db error')));

      final result = await usecase.execute(
        SetCustomServersPriorityRequest(
          servers: [
            ElectrumServerDto(
              url: 'ssl://a:50002',
              network: _network,
              isCustom: true,
              priority: 0,
            ),
          ],
        ),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ElectrumSaveFailure>());
    });
  });
}
