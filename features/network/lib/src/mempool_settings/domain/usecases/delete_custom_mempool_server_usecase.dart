import 'package:mempool/mempool.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../mempool_settings_network.dart';

class DeleteCustomMempoolServerUsecase {
  final Mempool _mempool;
  final ReadMempoolEnvironment _readEnvironment;

  const DeleteCustomMempoolServerUsecase(this._mempool, this._readEnvironment);

  @useResult
  Future<Result<void, MempoolFailure>> execute({required bool isLiquid}) =>
      withMempoolSettingsNetwork(
        _readEnvironment,
        isLiquid: isLiquid,
        operation: (network) => _mempool.servers.trash(network: network),
      );
}
