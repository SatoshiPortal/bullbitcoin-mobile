import 'dart:async';

import 'package:mempool/mempool.dart';
import 'package:network/src/mempool_settings/domain/usecases/delete_custom_mempool_server_usecase.dart';
import 'package:network/src/mempool_settings/domain/usecases/load_mempool_server_data_usecase.dart';
import 'package:network/src/mempool_settings/domain/usecases/set_custom_mempool_server_usecase.dart';
import 'package:network/src/mempool_settings/domain/usecases/check_mempool_server_status_usecase.dart';
import 'package:network/src/mempool_settings/presentation/mempool_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network/src/mempool_settings/presentation/mempool_server_row.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _LoadData extends Mock implements LoadMempoolServerDataUsecase {}

class _SetCustom extends Mock implements SetCustomMempoolServerUsecase {}

class _DeleteCustom extends Mock implements DeleteCustomMempoolServerUsecase {}

/// Answers each probe only when the test completes the matching completer.
class _CheckStatus implements CheckMempoolServerStatusUsecase {
  final probes = <String, List<Completer<bool>>>{};

  @override
  Future<bool> execute(MempoolServer server) {
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

class _Server extends Fake implements MempoolServer {
  @override
  final String url;
  @override
  final Network network;
  @override
  final bool isCustom;

  _Server(this.url, this.network, {this.isCustom = false});
}

void main() {
  late _LoadData loadData;
  late _DeleteCustom deleteCustom;
  late _CheckStatus validator;
  late MempoolSettingsCubit cubit;

  setUp(() {
    loadData = _LoadData();
    deleteCustom = _DeleteCustom();
    validator = _CheckStatus();
    when(() => loadData.execute(isLiquid: any(named: 'isLiquid')))
        .thenAnswer((invocation) async {
          final isLiquid = invocation.namedArguments[#isLiquid] == true;
          return Ok(
            MempoolServerSelection(
              defaultServer: isLiquid
                  ? _Server('liquid.example', LiquidNetwork.mainnet)
                  : _Server('bitcoin.example', BitcoinNetwork.mainnet),
              customServer: isLiquid
                  ? null
                  : _Server(
                      'custom.example',
                      BitcoinNetwork.mainnet,
                      isCustom: true,
                    ),
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

    expect(cubit.state.defaultServer?.server.url, 'liquid.example');
    await cubit.close();
  });

  test('a late probe never brings a deleted custom server back', () async {
    when(() => deleteCustom.execute(isLiquid: any(named: 'isLiquid')))
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
