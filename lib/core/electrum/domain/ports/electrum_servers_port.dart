import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';

/// Port exposing the resolved list of electrum servers to use, in priority
/// order, for a given network. Lets consumers depend on an abstraction
/// instead of on the orchestration usecase that computes the list.
abstract class ElectrumServersPort {
  Future<List<ElectrumServer>> getServersToUse({
    required ElectrumServerNetwork network,
  });
}
