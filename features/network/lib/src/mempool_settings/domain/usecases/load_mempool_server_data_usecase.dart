import 'package:preferences/preferences.dart';
import 'package:mempool/mempool.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../mempool_settings_network.dart';

class LoadMempoolServerDataUsecase {
  final Mempool _mempool;
  final ActiveEnvironmentReader _preferences;

  const LoadMempoolServerDataUsecase(this._mempool, this._preferences);

  @useResult
  Future<Result<MempoolServerSelection, MempoolFailure>> execute({
    required bool isLiquid,
  }) async => withMempoolSettingsNetwork(
    await _preferences.readActiveEnvironment(),
    isLiquid: isLiquid,
    operation: (network) => _mempool.servers.fetch(network: network),
  );
}
