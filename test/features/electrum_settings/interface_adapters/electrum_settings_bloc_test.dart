import 'package:bb_mobile/core/electrum/application/dtos/electrum_server_dto.dart';
import 'package:bb_mobile/core/electrum/application/dtos/requests/add_custom_server_request.dart';
import 'package:bb_mobile/core/electrum/application/usecases/add_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/delete_custom_server_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/load_electrum_server_data_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_advanced_electrum_options_usecase.dart';
import 'package:bb_mobile/core/electrum/application/usecases/set_custom_servers_priority_usecase.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart'
    as core;
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_status.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_settings_failure.dart';
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
  });

  test('maps configured Tor failures to the server-list failure', () async {
    final add = _MockAddCustomServerUsecase();
    when(() => add.execute(any())).thenAnswer(
      (_) async => const Err<ElectrumServerStatus, core.ElectrumFailure>(
        core.ElectrumConfiguredExternalTorUnavailableFailure(),
      ),
    );
    final bloc = ElectrumSettingsBloc(
      loadElectrumServerDataUsecase: _MockLoadElectrumServerDataUsecase(),
      addCustomServerUsecase: add,
      setCustomServersPriorityUsecase: _MockSetCustomServersPriorityUsecase(),
      deleteCustomServerUsecase: _MockDeleteCustomServerUsecase(),
      setAdvancedElectrumOptionsUsecase:
          _MockSetAdvancedElectrumOptionsUsecase(),
    );
    addTearDown(bloc.close);

    final stateFuture = bloc.stream.firstWhere(
      (state) => state.electrumServersError != null,
    );
    bloc.add(const ElectrumCustomServerAdded(url: 'fallback.example:50002'));
    final state = await stateFuture;

    expect(
      state.electrumServersError,
      isA<ElectrumServersConfiguredExternalTorUnavailableFailure>(),
    );
  });
}
