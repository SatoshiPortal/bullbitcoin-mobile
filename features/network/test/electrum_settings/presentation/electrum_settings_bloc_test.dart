import 'dart:async';

import 'package:electrum/electrum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/src/electrum_settings/domain/add_electrum_server_usecase.dart';
import 'package:network/src/electrum_settings/domain/electrum_settings_failure.dart';
import 'package:network/src/electrum_settings/domain/load_electrum_settings_usecase.dart';
import 'package:network/src/electrum_settings/domain/prioritize_electrum_servers_usecase.dart';
import 'package:network/src/electrum_settings/domain/remove_electrum_server_usecase.dart';
import 'package:network/src/electrum_settings/domain/update_electrum_settings_usecase.dart';
import 'package:network/src/electrum_settings/presentation/electrum_server_view_model.dart';
import 'package:network/src/electrum_settings/presentation/electrum_settings_bloc.dart';
import 'package:primitives/primitives.dart';

class _MockServers extends Mock implements ElectrumServers {}

class _MockOptions extends Mock implements ElectrumServerOptions {}

const _bitcoin = ElectrumServerNetwork.bitcoinMainnet;
const _liquid = ElectrumServerNetwork.liquidMainnet;
const _onion = ElectrumEndpoint(
  url: 'ssl://hidden.onion:50002',
  network: _bitcoin,
  isCustom: true,
  priority: 0,
);

typedef _Refresh = Result<ElectrumServerChecks, ElectrumFailure>;

ElectrumServerChecks _checks(
  ElectrumEndpoint endpoint, [
  ElectrumServerStatus status = ElectrumServerStatus.unknown,
]) => ElectrumServerChecks(
  servers: [endpoint],
  serverStatuses: {endpoint.url: status},
  settings: ElectrumOptions(
    stopGap: 20,
    timeout: 10,
    retry: 3,
    validateDomain: true,
    network: endpoint.network,
  ),
);

void main() {
  late _MockServers servers;
  late ElectrumSettingsBloc bloc;

  setUp(() {
    servers = _MockServers();
    final options = _MockOptions();
    when(() => servers.activeNetwork(isLiquid: false))
        .thenAnswer((_) async => const Ok(_bitcoin));
    when(() => servers.activeNetwork(isLiquid: true))
        .thenAnswer((_) async => const Ok(_liquid));
    when(servers.hasActiveCustomBitcoinOnionServer)
        .thenAnswer((_) async => const Ok(false));
    final update = UpdateElectrumSettingsUsecase(options);
    bloc = ElectrumSettingsBloc(
      loadSettings: LoadElectrumSettingsUsecase(servers),
      addServer: AddElectrumServerUsecase(servers, update),
      prioritizeServers: PrioritizeElectrumServersUsecase(servers),
      removeServer: RemoveElectrumServerUsecase(servers, update),
      updateSettings: update,
    );
    addTearDown(bloc.close);
  });

  test('maps configured Tor failures to the server-list failure', () async {
    when(() => servers.watchChecks(network: _bitcoin))
        .thenAnswer((_) => Stream.value(Ok(_checks(_onion))));
    when(
      () => servers.store(
        'fallback.example:50002',
        network: _bitcoin,
        priority: 1,
        enableSsl: true,
      ),
    ).thenAnswer(
      (_) async => const Err(ElectrumExternalTorProxyUnavailableFailure()),
    );

    final loaded = bloc.stream.firstWhere(
      (state) => !state.isLoadingData && state.environment != null,
    );
    bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
    await loaded;

    final failed = bloc.stream.firstWhere(
      (state) => state.electrumServersError != null,
    );
    bloc.add(const ElectrumCustomServerAdded(url: 'fallback.example:50002'));
    expect(
      (await failed).electrumServersError,
      isA<ElectrumServersExternalTorProxyUnavailableFailure>(),
    );
  });

  test(
    'publishes servers before probes finish and then their final status',
    () async {
      final refresh = StreamController<_Refresh>();
      when(() => servers.watchChecks(network: _bitcoin))
          .thenAnswer((_) => refresh.stream);
      when(servers.hasActiveCustomBitcoinOnionServer)
          .thenAnswer((_) async => const Ok(true));

      final partial = bloc.stream.firstWhere(
        (state) => state.customServers.isNotEmpty,
      );
      bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
      refresh.add(Ok(_checks(_onion)));
      final probing = await partial;
      expect(probing.isLoadingData, isTrue);
      expect(probing.customServers.single.status, ElectrumServerStatus.unknown);

      final done = bloc.stream.firstWhere((state) => !state.isLoadingData);
      refresh.add(Ok(_checks(_onion, ElectrumServerStatus.online)));
      await refresh.close();
      final loaded = await done;
      expect(loaded.customServers.single.status, ElectrumServerStatus.online);
      expect(loaded.hasActiveCustomBitcoinOnionServer, isTrue);
    },
  );

  test('keeps a mutation made while loading over an old load update', () async {
    final refresh = StreamController<_Refresh>();
    when(() => servers.watchChecks(network: _bitcoin))
        .thenAnswer((_) => refresh.stream);
    when(() => servers.trash(_onion.url, network: _bitcoin))
        .thenAnswer((_) async => const Ok(null));

    final partial = bloc.stream.firstWhere(
      (state) => state.customServers.isNotEmpty,
    );
    bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
    refresh.add(Ok(_checks(_onion)));
    await partial;

    final refused = bloc.stream.firstWhere(
      (state) => state.electrumServersError is ElectrumServersDeleteFailure,
    );
    bloc.add(
      ElectrumCustomServerDeleted(
        server: ElectrumServerViewModel(
          url: _onion.url,
          network: ElectrumServerNetwork.bitcoinRegtest,
          status: ElectrumServerStatus.unknown,
          priority: 0,
        ),
      ),
    );
    await refused;
    verifyNever(() => servers.trash(_onion.url, network: _bitcoin));

    final deleted = bloc.stream.firstWhere(
      (state) => state.customServers.isEmpty,
    );
    bloc.add(
      ElectrumCustomServerDeleted(server: bloc.state.customServers.single),
    );
    await deleted;

    refresh.add(Ok(_checks(_onion, ElectrumServerStatus.online)));
    await refresh.close();
    expect(bloc.state.customServers, isEmpty);
  });

  test(
    'a failing Liquid tab never retains Bitcoin servers or options',
    () async {
      const defaultServer = ElectrumEndpoint(
        url: 'ssl://main.example:50002',
        network: _bitcoin,
        isCustom: false,
        priority: 0,
      );
      when(() => servers.watchChecks(network: _bitcoin))
          .thenAnswer((_) => Stream.value(Ok(_checks(defaultServer))));
      when(() => servers.watchChecks(network: _liquid))
          .thenAnswer((_) => Stream.value(const Err(ElectrumLoadFailure())));

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
