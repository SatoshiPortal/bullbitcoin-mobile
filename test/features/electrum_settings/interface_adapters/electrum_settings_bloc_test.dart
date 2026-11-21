import 'package:electrum/testing.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/view_models/electrum_server_view_model.dart';

import 'dart:async';

import 'package:electrum/electrum.dart';
import 'package:electrum/electrum.dart' as core;
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/electrum_settings/data/environment_adapter.dart';
import 'package:bb_mobile/features/settings/domain/settings_entity.dart';
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
    registerFallbackValue(ElectrumServerNetwork.bitcoinMainnet);
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
    registerFallbackValue(
      DeleteCustomServerRequest(
        url: 'old.example:50002',
        network: ElectrumServerNetwork.bitcoinMainnet,
      ),
    );
  });

  test('maps configured Tor failures to the server-list failure', () async {
    final add = _MockAddCustomServerUsecase();
    when(() => add.execute(any())).thenAnswer(
      (_) async => const Err<ElectrumServerStatus, core.ElectrumFailure>(
        core.ElectrumExternalTorProxyUnavailableFailure(),
      ),
    );
    final load = _MockLoadElectrumServerDataUsecase();
    final appSettings = _MockSettingsRepository();
    final servers = _MockElectrumServerRepository();
    when(() => appSettings.fetch()).thenAnswer(
      (_) async => const SettingsEntity(
        environment: Environment.mainnet,
        bitcoinUnit: BitcoinUnit.sats,
        currencyCode: 'USD',
      ),
    );
    when(
      () => servers.fetchActiveServers(
        network: ElectrumServerNetwork.bitcoinMainnet,
      ),
    ).thenAnswer((_) async => const Ok([]));
    when(() => load.execute(any(), onUpdate: any(named: 'onUpdate')))
        .thenAnswer(
          (_) async => Ok(
            LoadElectrumServerDataResponse(
              servers: [],
              serverStatuses: {},
              settings: ElectrumSettingsDto(
                stopGap: 20,
                timeout: 10,
                retry: 3,
                validateDomain: true,
                network: ElectrumServerNetwork.bitcoinMainnet,
              ),
            ),
          ),
        );
    final bloc = ElectrumSettingsBloc(
      loadElectrumServerDataUsecase: load,
      addCustomServerUsecase: add,
      setCustomServersPriorityUsecase: _MockSetCustomServersPriorityUsecase(),
      deleteCustomServerUsecase: _MockDeleteCustomServerUsecase(),
      setAdvancedElectrumOptionsUsecase:
          _MockSetAdvancedElectrumOptionsUsecase(),
      hasActiveCustomBitcoinOnionServerUsecase:
          HasActiveCustomBitcoinOnionServerUsecase(
            servers,
            EnvironmentAdapter(settingsRepository: () => appSettings),
          ),
    );
    addTearDown(bloc.close);

    final loaded = bloc.stream.firstWhere((state) => state.environment != null);
    bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
    await loaded;
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
      when(() => load.execute(any(), onUpdate: any(named: 'onUpdate')))
          .thenAnswer((invocation) async {
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
              EnvironmentAdapter(settingsRepository: () => settingsRepository),
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
    when(() => load.execute(any(), onUpdate: any(named: 'onUpdate')))
        .thenAnswer((invocation) {
          onUpdate =
              invocation.namedArguments[#onUpdate]
                  as void Function(LoadElectrumServerDataResponse);
          onUpdate(oldResponse);
          return loadResult.future;
        });
    when(() => delete.execute(any()))
        .thenAnswer((_) async => const Ok<void, core.ElectrumFailure>(null));
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
            EnvironmentAdapter(settingsRepository: () => settingsRepository),
          ),
    );
    addTearDown(bloc.close);

    bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
    await bloc.stream.firstWhere((state) => state.isLoadingData);
    // An event from another tab must not delete this network's same URL.
    final refused = bloc.stream.firstWhere(
      (state) => state.electrumServersError is ElectrumServersDeleteFailure,
    );
    bloc.add(
      ElectrumCustomServerDeleted(
        server: ElectrumServerViewModel(
          url: server.url,
          network: ElectrumServerNetwork.bitcoinRegtest,
          status: ElectrumServerStatus.unknown,
          priority: 0,
        ),
      ),
    );
    await refused;
    verifyNever(() => delete.execute(any()));
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
  test(
    'a failing Liquid tab never retains Bitcoin servers or options',
    () async {
      final load = _MockLoadElectrumServerDataUsecase();
      final settings = _MockSettingsRepository();
      final servers = _MockElectrumServerRepository();
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.regtest,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(() => servers.fetchActiveServers(network: any(named: 'network')))
          .thenAnswer((_) async => const Ok([]));
      when(() => load.execute(any(), onUpdate: any(named: 'onUpdate')))
          .thenAnswer((invocation) async {
            final request =
                invocation.positionalArguments.single
                    as LoadElectrumServerDataRequest;
            if (request.isLiquid) return const Err(core.ElectrumLoadFailure());
            return Ok(
              LoadElectrumServerDataResponse(
                servers: [
                  ElectrumServerDto(
                    url: 'tcp://127.0.0.1:50000',
                    network: ElectrumServerNetwork.bitcoinRegtest,
                    isCustom: false,
                    priority: 0,
                  ),
                ],
                serverStatuses: {},
                settings: ElectrumSettingsDto(
                  stopGap: 20,
                  timeout: 5,
                  retry: 5,
                  validateDomain: true,
                  network: ElectrumServerNetwork.bitcoinRegtest,
                ),
              ),
            );
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
              servers,
              EnvironmentAdapter(settingsRepository: () => settings),
            ),
      );
      addTearDown(bloc.close);
      final bitcoinLoaded = bloc.stream.firstWhere(
        (state) => !state.isLoadingData && state.defaultServers.isNotEmpty,
      );
      bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
      await bitcoinLoaded;
      final failed = bloc.stream.firstWhere(
        (state) => state.electrumServersError != null,
      );
      bloc.add(const ElectrumSettingsLoaded(isLiquid: true));
      final state = await failed;
      expect(state.isLiquid, isTrue);
      expect(state.defaultServers, isEmpty);
      expect(state.customServers, isEmpty);
      expect(state.advancedOptions, isNull);
      expect(state.environment, isNull);
    },
  );
}
