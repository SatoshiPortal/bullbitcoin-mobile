import 'package:preferences/preferences.dart';
import 'package:mempool/mempool.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../mempool_settings_network.dart';

class SetCustomMempoolServerUsecase {
  final Mempool _mempool;
  final ActiveEnvironmentReader _preferences;

  const SetCustomMempoolServerUsecase(this._mempool, this._preferences);

  @useResult
  Future<Result<void, MempoolFailure>> execute(
    String url, {
    required bool isLiquid,
    required bool enableSsl,
  }) async => withMempoolSettingsNetwork(
    await _preferences.readActiveEnvironment(),
    isLiquid: isLiquid,
    operation: (network) async {
      return switch (MempoolServer.tryCreateCustom(
        url: url,
        network: network,
        enableSsl: enableSsl,
      )) {
        Ok(:final value) => _mempool.servers.store(value),
        Err(:final failure) => Err(failure),
      };
    },
  );
}
