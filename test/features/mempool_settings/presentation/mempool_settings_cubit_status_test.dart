import 'dart:async';

import 'package:mempool/mempool.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/load_mempool_server_data_usecase.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/set_custom_mempool_server_usecase.dart';
import 'package:bb_mobile/features/mempool_settings/domain/usecases/check_mempool_server_status_usecase.dart';
import 'package:bb_mobile/features/mempool_settings/presentation/bloc/mempool_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _LoadData extends Mock implements LoadMempoolServerDataUsecase {}

class _SetCustom extends Mock implements SetCustomMempoolServerUsecase {}

class _DeleteCustom extends Mock implements DeleteCustomMempoolServerUsecase {}

/// Answers each probe only when the test completes the matching completer.
class _CheckStatus implements CheckMempoolServerStatusUsecase {
  final probes = <String, List<Completer<bool>>>{};

  @override
  Future<bool> execute(MempoolServerDto server) {
    final probe = Completer<bool>();
    (probes[server.url] ??= []).add(probe);
    return probe.future;
  }

  /// Completes the [index]th probe of [url], the latest one by default.
  void answer(String url, {int? index, bool online = true}) {
    final sent = probes[url];
    if (sent == null || sent.isEmpty) return;
    sent[index ?? sent.length - 1].complete(online);
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
  late _CheckStatus validator;
  late MempoolSettingsCubit cubit;

  setUpAll(() {
    registerFallbackValue(LoadMempoolServerDataRequest(isLiquid: false));
    registerFallbackValue(DeleteCustomMempoolServerRequest(isLiquid: false));
  });

  setUp(() {
    loadData = _LoadData();
    deleteCustom = _DeleteCustom();
    validator = _CheckStatus();
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
      checkStatusUsecase: validator,
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
