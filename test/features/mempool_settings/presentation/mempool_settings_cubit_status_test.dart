import 'dart:async';

import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/delete_custom_mempool_server_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/requests/load_mempool_server_data_request.dart';
import 'package:bb_mobile/core/mempool/application/dtos/responses/load_mempool_server_data_response.dart';
import 'package:bb_mobile/core/mempool/application/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/core/mempool/application/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
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

/// Answers each probe only when the test completes the matching completer.
class _Validator implements MempoolServerValidatorPort {
  final probes = <String, List<Completer<Result<void, MempoolFailure>>>>{};

  @override
  Future<Result<void, MempoolFailure>> validateServer({
    required String url,
    required MempoolServerNetwork network,
    bool enableSsl = true,
  }) {
    final probe = Completer<Result<void, MempoolFailure>>();
    (probes[url] ??= []).add(probe);
    return probe.future;
  }

  /// Completes the [index]th probe of [url], the latest one by default.
  void answer(String url, {int? index, bool online = true}) {
    final sent = probes[url];
    if (sent == null || sent.isEmpty) return;
    sent[index ?? sent.length - 1].complete(
      online
          ? const Ok(null)
          : const Err(MempoolValidationConnectionErrorFailure()),
    );
  }
}

MempoolServerDto _server(
  String url, {
  bool liquid = false,
  bool custom = false,
}) => MempoolServerDto(
  url: url,
  isCustom: custom,
  isTestnet: false,
  isLiquid: liquid,
);

void main() {
  late _LoadData loadData;
  late _DeleteCustom deleteCustom;
  late _Validator validator;
  late MempoolSettingsCubit cubit;

  setUpAll(() {
    registerFallbackValue(LoadMempoolServerDataRequest(isLiquid: false));
    registerFallbackValue(DeleteCustomMempoolServerRequest(isLiquid: false));
  });

  setUp(() {
    loadData = _LoadData();
    deleteCustom = _DeleteCustom();
    validator = _Validator();
    when(() => loadData.execute(any())).thenAnswer((invocation) async {
      final request =
          invocation.positionalArguments.first as LoadMempoolServerDataRequest;
      return Ok(
        LoadMempoolServerDataResponse(
          defaultServer: request.isLiquid
              ? _server('liquid.example', liquid: true)
              : _server('bitcoin.example'),
          customServer: request.isLiquid
              ? null
              : _server('custom.example', custom: true),
        ),
      );
    });
    cubit = MempoolSettingsCubit(
      loadDataUsecase: loadData,
      setCustomServerUsecase: _SetCustom(),
      deleteCustomServerUsecase: deleteCustom,
      validator: validator,
    );
  });

  test('opening the screen probes the listed servers', () async {
    await cubit.loadData();
    validator.answer('bitcoin.example');
    await pumpEventQueue();

    expect(cubit.state.defaultServer?.status, MempoolServerStatus.online);
    await cubit.close();
  });

  test('a late probe never puts the other network back on screen', () async {
    await cubit.loadData();
    await cubit.loadData(isLiquid: true);
    validator.answer('bitcoin.example');
    await pumpEventQueue();

    expect(cubit.state.defaultServer?.url, 'liquid.example');
    await cubit.close();
  });

  test('a late probe never brings a deleted custom server back', () async {
    when(() => deleteCustom.execute(any()))
        .thenAnswer((_) async => const Ok(null));
    await cubit.loadData();
    await cubit.deleteCustomServer();
    validator.answer('custom.example');
    await pumpEventQueue();

    expect(cubit.state.customServer, isNull);
    await cubit.close();
  });

  test('an older probe never overwrites a newer answer', () async {
    await cubit.loadData();
    final refreshing = cubit.refresh();
    await pumpEventQueue();
    validator.answer('bitcoin.example');
    await pumpEventQueue();
    validator.answer('bitcoin.example', index: 0, online: false);
    validator.answer('custom.example');
    await refreshing;

    expect(cubit.state.defaultServer?.status, MempoolServerStatus.online);
    await cubit.close();
  });

  test('a probe answering after the screen closed is ignored', () async {
    await cubit.loadData();
    await cubit.close();
    validator.answer('bitcoin.example');
    await pumpEventQueue();

    expect(cubit.isClosed, isTrue);
  });
}
