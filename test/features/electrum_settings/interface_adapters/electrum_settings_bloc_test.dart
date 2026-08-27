import 'dart:async';

import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/delete_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart'
    as core;
import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/repositories/electrum_server_repository.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_settings_failure.dart';
import 'package:bb_mobile/features/electrum_settings/domain/usecases/has_active_custom_bitcoin_onion_server_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAddCustomServerUsecase extends Mock
    implements AddCustomServerUsecase {}

class _MockLoadElectrumServerDataUsecase extends Mock
    implements LoadElectrumServerDataUsecase {}

class _MockSetCustomServersPriorityUsecase extends Mock
    implements SetCustomServersPriorityUsecase {}

class _MockDeleteCustomServerUsecase extends Mock
    implements DeleteCustomServerUsecase {}

class _MockSetAdvancedElectrumOptionsUsecase extends Mock
    implements SetAdvancedElectrumOptionsUsecase {}

class _MockElectrumServerRepository extends Mock
    implements ElectrumServerRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      AddCustomServerRequest(
        server: ElectrumServerDto(
          url: 'fallback.example:50002',
          network: ElectrumServerNetwork.bitcoinMainnet,
          isCustom: true,
          priority: 0,
        ),
      ),
    );
    registerFallbackValue(LoadElectrumServerDataRequest(isLiquid: false));
    registerFallbackValue(DeleteCustomServerRequest(url: 'old.example:50002'));
  });

  test('maps configured Tor failures to the server-list failure', () async {
    final add = _MockAddCustomServerUsecase();
    when(() => add.execute(any())).thenAnswer(
      (_) async => const Err<ElectrumServerStatus, core.ElectrumFailure>(
        core.ElectrumExternalTorProxyUnavailableFailure(),
      ),
    );
    final bloc = ElectrumSettingsBloc(
      loadElectrumServerDataUsecase: _MockLoadElectrumServerDataUsecase(),
      addCustomServerUsecase: add,
      setCustomServersPriorityUsecase: _MockSetCustomServersPriorityUsecase(),
      deleteCustomServerUsecase: _MockDeleteCustomServerUsecase(),
      setAdvancedElectrumOptionsUsecase:
          _MockSetAdvancedElectrumOptionsUsecase(),
      hasActiveCustomBitcoinOnionServerUsecase:
          HasActiveCustomBitcoinOnionServerUsecase(
            _MockElectrumServerRepository(),
            _MockSettingsRepository(),
          ),
    );
    addTearDown(bloc.close);

    final stateFuture = bloc.stream.firstWhere(
      (state) => state.electrumServersError != null,
    );
    bloc.add(const ElectrumCustomServerAdded(url: 'fallback.example:50002'));
    final state = await stateFuture;

    expect(
      state.electrumServersError,
      isA<ElectrumServersExternalTorProxyUnavailableFailure>(),
    );
  });

  test(
    'publishes servers before probes finish and then their final status',
    () async {
      final load = _MockLoadElectrumServerDataUsecase();
      final serverRepository = _MockElectrumServerRepository();
      final settingsRepository = _MockSettingsRepository();
      final server = ElectrumServer.existing(
        url: 'ssl://hidden.onion:50002',
        network: ElectrumServerNetwork.bitcoinMainnet,
        isCustom: true,
        priority: 0,
      );
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(
        () => serverRepository.fetchActiveServers(
          network: ElectrumServerNetwork.bitcoinMainnet,
        ),
      ).thenAnswer((_) async => Ok([server]));
      final unknownResponse = LoadElectrumServerDataResponse(
        servers: [ElectrumServerDto.fromDomain(server)],
        serverStatuses: {server.url: ElectrumServerStatus.unknown},
        settings: ElectrumSettingsDto(
          stopGap: 20,
          timeout: 10,
          retry: 3,
          validateDomain: true,
          network: ElectrumServerNetwork.bitcoinMainnet,
        ),
      );
      final onlineResponse = LoadElectrumServerDataResponse(
        servers: [ElectrumServerDto.fromDomain(server)],
        serverStatuses: {server.url: ElectrumServerStatus.online},
        settings: unknownResponse.settings,
      );
      when(
        () => load.execute(any(), onUpdate: any(named: 'onUpdate')),
      ).thenAnswer((invocation) async {
        final onUpdate =
            invocation.namedArguments[#onUpdate]
                as void Function(LoadElectrumServerDataResponse)?;
        onUpdate?.call(unknownResponse);
        return Ok(onlineResponse);
      });
      final bloc = ElectrumSettingsBloc(
        loadElectrumServerDataUsecase: load,
        addCustomServerUsecase: _MockAddCustomServerUsecase(),
        setCustomServersPriorityUsecase: _MockSetCustomServersPriorityUsecase(),
        deleteCustomServerUsecase: _MockDeleteCustomServerUsecase(),
        setAdvancedElectrumOptionsUsecase:
            _MockSetAdvancedElectrumOptionsUsecase(),
        hasActiveCustomBitcoinOnionServerUsecase:
            HasActiveCustomBitcoinOnionServerUsecase(
              serverRepository,
              settingsRepository,
            ),
      );
      addTearDown(bloc.close);

      final statesFuture = bloc.stream
          .where((state) => state.customServers.isNotEmpty)
          .take(2)
          .toList();
      bloc.add(const ElectrumSettingsLoaded(isLiquid: false));

      final states = await statesFuture;
      expect(states.first.isLoadingData, isTrue);
      expect(
        states.first.customServers.single.status,
        ElectrumServerStatus.unknown,
      );
      expect(states.last.isLoadingData, isFalse);
      expect(
        states.last.customServers.single.status,
        ElectrumServerStatus.online,
      );
      expect(states.last.hasActiveCustomBitcoinOnionServer, isTrue);
    },
  );

  test('keeps a mutation made while loading over an old load update', () async {
    final load = _MockLoadElectrumServerDataUsecase();
    final delete = _MockDeleteCustomServerUsecase();
    final serverRepository = _MockElectrumServerRepository();
    final settingsRepository = _MockSettingsRepository();
    final server = ElectrumServer.existing(
      url: 'ssl://old.example:50002',
      network: ElectrumServerNetwork.bitcoinMainnet,
      isCustom: true,
      priority: 0,
    );
    final oldResponse = LoadElectrumServerDataResponse(
      servers: [ElectrumServerDto.fromDomain(server)],
      serverStatuses: {server.url: ElectrumServerStatus.unknown},
      settings: ElectrumSettingsDto(
        stopGap: 20,
        timeout: 10,
        retry: 3,
        validateDomain: true,
        network: ElectrumServerNetwork.bitcoinMainnet,
      ),
    );
    final loadResult =
        Completer<
          Result<LoadElectrumServerDataResponse, core.ElectrumFailure>
        >();
    late void Function(LoadElectrumServerDataResponse) onUpdate;
    when(
      () => load.execute(any(), onUpdate: any(named: 'onUpdate')),
    ).thenAnswer((invocation) {
      onUpdate =
          invocation.namedArguments[#onUpdate]
              as void Function(LoadElectrumServerDataResponse);
      onUpdate(oldResponse);
      return loadResult.future;
    });
    when(
      () => delete.execute(any()),
    ).thenAnswer((_) async => const Ok<void, core.ElectrumFailure>(null));
    when(() => settingsRepository.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => serverRepository.fetchActiveServers(
        network: ElectrumServerNetwork.bitcoinMainnet,
      ),
    ).thenAnswer((_) async => Ok([]));
    final bloc = ElectrumSettingsBloc(
      loadElectrumServerDataUsecase: load,
      addCustomServerUsecase: _MockAddCustomServerUsecase(),
      setCustomServersPriorityUsecase: _MockSetCustomServersPriorityUsecase(),
      deleteCustomServerUsecase: delete,
      setAdvancedElectrumOptionsUsecase:
          _MockSetAdvancedElectrumOptionsUsecase(),
      hasActiveCustomBitcoinOnionServerUsecase:
          HasActiveCustomBitcoinOnionServerUsecase(
            serverRepository,
            settingsRepository,
          ),
    );
    addTearDown(bloc.close);

    bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
    await bloc.stream.firstWhere((state) => state.isLoadingData);
    bloc.add(
      ElectrumCustomServerDeleted(server: bloc.state.customServers.single),
    );
    await bloc.stream.firstWhere((state) => state.isDeletingCustomServer);
    await bloc.stream.firstWhere((state) => state.customServers.isEmpty);

    onUpdate(oldResponse);
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.customServers, isEmpty);
    loadResult.complete(Ok(oldResponse));
  });
}
