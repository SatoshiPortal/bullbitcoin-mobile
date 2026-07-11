import 'dart:async';

import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/electrum_settings_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/delete_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/load_electrum_server_data_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/set_advanced_electrum_options_request.dart';
import 'package:bb_mobile/core/electrum/application/dtos/responses/load_electrum_server_data_response.dart';
import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/electrum_settings/interface_adapters/presenters/bloc/electrum_settings_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLoad extends Mock implements LoadElectrumServerDataUsecase {}

class _MockAdd extends Mock implements AddCustomServerUsecase {}

class _MockPrioritize extends Mock
    implements SetCustomServersPriorityUsecase {}

class _MockDelete extends Mock implements DeleteCustomServerUsecase {}

class _MockSetAdvanced extends Mock
    implements SetAdvancedElectrumOptionsUsecase {}

void main() {
  late _MockLoad load;
  late _MockAdd add;
  late _MockPrioritize prioritize;
  late _MockDelete delete;
  late _MockSetAdvanced setAdvanced;

  setUpAll(() {
    registerFallbackValue(LoadElectrumServerDataRequest(isLiquid: false));
    registerFallbackValue(
      AddCustomServerRequest(
        server: ElectrumServerDto(
          url: 'fallback:1',
          network: ElectrumServerNetwork.bitcoinMainnet,
          priority: 0,
          isCustom: true,
        ),
      ),
    );
    registerFallbackValue(DeleteCustomServerRequest(url: 'fallback:1'));
    registerFallbackValue(
      SetAdvancedElectrumOptionsRequest(
        options: ElectrumSettingsDto(
          stopGap: 20,
          timeout: 5,
          retry: 5,
          validateDomain: true,
          network: ElectrumServerNetwork.bitcoinMainnet,
        ),
      ),
    );
  });

  setUp(() {
    load = _MockLoad();
    add = _MockAdd();
    prioritize = _MockPrioritize();
    delete = _MockDelete();
    setAdvanced = _MockSetAdvanced();
  });

  ElectrumSettingsBloc buildBloc() => ElectrumSettingsBloc(
    loadElectrumServerDataUsecase: load,
    addCustomServerUsecase: add,
    setCustomServersPriorityUsecase: prioritize,
    deleteCustomServerUsecase: delete,
    setAdvancedElectrumOptionsUsecase: setAdvanced,
  );

  LoadElectrumServerDataResponse buildLoadResponse({
    required bool validateDomain,
  }) => LoadElectrumServerDataResponse(
    servers: const [],
    serverStatuses: const {},
    settings: ElectrumSettingsDto(
      stopGap: 20,
      timeout: 5,
      retry: 5,
      validateDomain: validateDomain,
      network: ElectrumServerNetwork.bitcoinMainnet,
    ),
    useTorProxy: false,
    torProxyPort: 9050,
  );

  Future<ElectrumSettingsBloc> loadedBloc({
    required bool validateDomain,
  }) async {
    when(() => load.execute(any())).thenAnswer(
      (_) async => Ok(buildLoadResponse(validateDomain: validateDomain)),
    );
    final bloc = buildBloc();
    bloc.add(const ElectrumSettingsLoaded(isLiquid: false));
    await pumpEventQueue();
    return bloc;
  }

  group('adding a custom server', () {
    test('turns validateDomain off when it was on', () async {
      final bloc = await loadedBloc(validateDomain: true);
      when(
        () => add.execute(any()),
      ).thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
      when(
        () => setAdvanced.execute(any()),
      ).thenAnswer((_) async => const Ok(null));

      bloc.add(const ElectrumCustomServerAdded(url: 'my-node.local:50002'));
      await pumpEventQueue();

      expect(bloc.state.advancedOptions?.validateDomain, isFalse);
      final captured =
          verify(() => setAdvanced.execute(captureAny())).captured.single
              as SetAdvancedElectrumOptionsRequest;
      expect(captured.validateDomain, isFalse);
      expect(captured.network, ElectrumServerNetwork.bitcoinMainnet);

      await bloc.close();
    });

    test('does not re-save when validateDomain is already off', () async {
      final bloc = await loadedBloc(validateDomain: false);
      when(
        () => add.execute(any()),
      ).thenAnswer((_) async => const Ok(ElectrumServerStatus.online));

      bloc.add(const ElectrumCustomServerAdded(url: 'my-node.local:50002'));
      await pumpEventQueue();

      expect(bloc.state.advancedOptions?.validateDomain, isFalse);
      verifyNever(() => setAdvanced.execute(any()));

      await bloc.close();
    });
  });

  group('deleting a custom server', () {
    test(
      'turns validateDomain back on when it was the last custom server',
      () async {
        final bloc = await loadedBloc(validateDomain: false);
        when(
          () => add.execute(any()),
        ).thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
        bloc.add(const ElectrumCustomServerAdded(url: 'my-node.local:50002'));
        await pumpEventQueue();
        final addedServer = bloc.state.customServers.single;

        when(
          () => delete.execute(any()),
        ).thenAnswer((_) async => const Ok(null));
        when(
          () => setAdvanced.execute(any()),
        ).thenAnswer((_) async => const Ok(null));

        bloc.add(ElectrumCustomServerDeleted(server: addedServer));
        await pumpEventQueue();

        expect(bloc.state.customServers, isEmpty);
        expect(bloc.state.advancedOptions?.validateDomain, isTrue);
        final captured =
            verify(() => setAdvanced.execute(captureAny())).captured.single
                as SetAdvancedElectrumOptionsRequest;
        expect(captured.validateDomain, isTrue);

        await bloc.close();
      },
    );

    test(
      'leaves validateDomain untouched when other custom servers remain',
      () async {
        final bloc = await loadedBloc(validateDomain: false);
        when(
          () => add.execute(any()),
        ).thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
        bloc.add(const ElectrumCustomServerAdded(url: 'node-a.local:50002'));
        await pumpEventQueue();
        bloc.add(const ElectrumCustomServerAdded(url: 'node-b.local:50002'));
        await pumpEventQueue();
        final firstServer = bloc.state.customServers.first;

        when(
          () => delete.execute(any()),
        ).thenAnswer((_) async => const Ok(null));

        bloc.add(ElectrumCustomServerDeleted(server: firstServer));
        await pumpEventQueue();

        expect(bloc.state.customServers, hasLength(1));
        expect(bloc.state.advancedOptions?.validateDomain, isFalse);
        verifyNever(() => setAdvanced.execute(any()));

        await bloc.close();
      },
    );

    test(
      'a server added while a delete is still in flight is not lost, and '
      'validateDomain is not wrongly re-enabled',
      () async {
        final bloc = await loadedBloc(validateDomain: false);
        when(
          () => add.execute(any()),
        ).thenAnswer((_) async => const Ok(ElectrumServerStatus.online));
        bloc.add(const ElectrumCustomServerAdded(url: 'server1.local:50002'));
        await pumpEventQueue();
        final server1 = bloc.state.customServers.single;

        // Hold the delete's result open so a concurrent add can land first.
        final deleteCompleter = Completer<Result<void, ElectrumFailure>>();
        when(
          () => delete.execute(any()),
        ).thenAnswer((_) => deleteCompleter.future);

        bloc.add(ElectrumCustomServerDeleted(server: server1));
        await pumpEventQueue(); // handler now suspended awaiting the delete

        bloc.add(const ElectrumCustomServerAdded(url: 'server2.local:50002'));
        await pumpEventQueue();
        expect(bloc.state.customServers, hasLength(2));

        deleteCompleter.complete(const Ok(null));
        await pumpEventQueue();

        // server2 must survive the delete's emit, and validateDomain must
        // not be re-enabled since a custom server is still active.
        expect(bloc.state.customServers, hasLength(1));
        expect(bloc.state.customServers.single.url, contains('server2.local'));
        expect(bloc.state.advancedOptions?.validateDomain, isFalse);
        verifyNever(() => setAdvanced.execute(any()));

        await bloc.close();
      },
    );
  });
}
