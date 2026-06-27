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
import 'package:bb_mobile/core/electrum/domain/ports/environment_port.dart';
import 'package:bb_mobile/core/electrum/domain/ports/server_status_port.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_settings_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockServerRepository extends Mock implements ElectrumServerRepository {}

class _MockSettingsRepository extends Mock
    implements ElectrumSettingsRepository {}

class _MockServerStatusPort extends Mock implements ServerStatusPort {}

class _MockAppSettingsRepository extends Mock implements SettingsRepository {}

class _MockEnvironmentPort extends Mock implements EnvironmentPort {}

const _network = ElectrumServerNetwork.bitcoinMainnet;

ElectrumSettings _settings() => ElectrumSettings(
  stopGap: 20,
  timeout: 5,
  retry: 1,
  validateDomain: true,
  network: _network,
);

void main() {
  group('DeleteCustomServerUsecase', () {
    test('propagates the sanitized failure from the repository', () async {
      final repo = _MockServerRepository();
      final usecase = DeleteCustomServerUsecase(electrumServerRepository: repo);
      when(
        () => repo.delete(url: any(named: 'url')),
      ).thenAnswer((_) async => const Err(ElectrumDeleteFailure('raw db error')));

      final result = await usecase.execute(
        DeleteCustomServerRequest(url: 'ssl://a:50002'),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ElectrumDeleteFailure>());
    });
  });

  group('AddCustomServerUsecase', () {
    late _MockServerRepository serverRepo;
    late _MockServerStatusPort statusPort;
    late _MockAppSettingsRepository appSettingsRepo;
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
      statusPort = _MockServerStatusPort();
      appSettingsRepo = _MockAppSettingsRepository();
      usecase = AddCustomServerUsecase(
        electrumServerRepository: serverRepo,
        serverStatusPort: statusPort,
        settingsRepository: appSettingsRepo,
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

    test('returns Unreachable failure when the socket check is offline',
        () async {
      when(() => serverRepo.fetchByUrl(any())).thenAnswer((_) async => Ok(null));
      when(() => appSettingsRepo.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
          useTorProxy: false,
          torProxyPort: 9050,
        ),
      );
      when(
        () => statusPort.checkSocket(
          url: any(named: 'url'),
          useTorProxy: any(named: 'useTorProxy'),
          torProxyPort: any(named: 'torProxyPort'),
        ),
      ).thenAnswer((_) async => ElectrumServerStatus.offline);

      final result = await usecase.execute(request());

      expect(result, isA<Err>());
      expect(
        (result as Err).failure,
        isA<ElectrumServerUnreachableFailure>(),
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

    test('maps invalid stopGap to a sanitized failure carrying the value',
        () async {
      when(
        () => settingsRepo.fetchByNetwork(_network),
      ).thenAnswer((_) async => Ok(_settings()));

      final result = await usecase.execute(request(-1));

      expect(result, isA<Err>());
      final failure = (result as Err).failure;
      expect(failure, isA<ElectrumInvalidStopGapFailure>());
      expect((failure as ElectrumInvalidStopGapFailure).value, -1);
    });
  });

  group('LoadElectrumServerDataUsecase', () {
    test('maps a throwing dependency to a sanitized failure — no raw leak',
        () async {
      final serverRepo = _MockServerRepository();
      final settingsRepo = _MockSettingsRepository();
      final envPort = _MockEnvironmentPort();
      final statusPort = _MockServerStatusPort();
      final appSettingsRepo = _MockAppSettingsRepository();
      final usecase = LoadElectrumServerDataUsecase(
        electrumServerRepository: serverRepo,
        electrumSettingsRepository: settingsRepo,
        environmentPort: envPort,
        serverStatusPort: statusPort,
        settingsRepository: appSettingsRepo,
      );
      // EnvironmentPort still throws; the use-case is the boundary that maps it.
      when(() => envPort.getEnvironment()).thenThrow(Exception('boom'));

      final result = await usecase.execute(
        LoadElectrumServerDataRequest(isLiquid: false),
      );

      expect(result, isA<Err>());
      expect((result as Err).failure, isA<ElectrumUnexpectedFailure>());
    });
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
