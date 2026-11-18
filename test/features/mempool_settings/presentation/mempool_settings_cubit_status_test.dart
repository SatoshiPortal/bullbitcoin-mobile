import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/load_mempool_server_data_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/responses/load_mempool_server_data_response.dart';
import 'package:bb_mobile/core/mempool/application/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/ports/mempool_server_validator_port.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_status.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _LoadData extends Mock implements LoadMempoolServerDataUsecase {}

class _SetCustom extends Mock implements SetCustomMempoolServerUsecase {}

class _DeleteCustom extends Mock implements DeleteCustomMempoolServerUsecase {}

class _Validator extends Mock implements MempoolServerValidatorPort {}

void main() {
  setUpAll(() {
    registerFallbackValue(LoadMempoolServerDataRequest(isLiquid: false));
    registerFallbackValue(MempoolServerNetwork.bitcoinMainnet);
  });

  test('opening the screen probes the default server status', () async {
    final loadData = _LoadData();
    final validator = _Validator();
    when(() => loadData.execute(any())).thenAnswer(
      (_) async => Ok(
        LoadMempoolServerDataResponse(
          defaultServer: MempoolServerDto(
            url: 'mempool.bullbitcoin.com',
            isCustom: false,
            isTestnet: false,
            isLiquid: false,
          ),
        ),
      ),
    );
    when(
      () => validator.validateServer(
        url: any(named: 'url'),
        network: any(named: 'network'),
        enableSsl: any(named: 'enableSsl'),
      ),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = MempoolSettingsCubit(
      loadDataUsecase: loadData,
      setCustomServerUsecase: _SetCustom(),
      deleteCustomServerUsecase: _DeleteCustom(),
      validator: validator,
    );

    await cubit.loadData();

    expect(cubit.state.defaultServer?.status, MempoolServerStatus.online);
    await cubit.close();
  });
}
