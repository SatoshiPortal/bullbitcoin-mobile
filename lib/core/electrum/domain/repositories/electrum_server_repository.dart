import 'package:bb_mobile/core/electrum/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/electrum/domain/errors/electrum_failure.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

abstract class ElectrumServerRepository {
  @useResult
  Future<Result<void, ElectrumFailure>> save(ElectrumServer server);
  @useResult
  Future<Result<void, ElectrumFailure>> batchSave(List<ElectrumServer> servers);
  @useResult
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchAll({
    bool? isTestnet,
    bool? isLiquid,
    bool? isCustom,
  });
  @useResult
  Future<Result<ElectrumServer?, ElectrumFailure>> fetchByUrl(String url);
  @useResult
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchCustomServers({
    required ElectrumServerNetwork network,
  });
  @useResult
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchDefaultServers({
    required ElectrumServerNetwork network,
  });

  /// Servers to actually connect to for [network], in priority order.
  /// Returns custom servers when any exist, otherwise the default set.
  @useResult
  Future<Result<List<ElectrumServer>, ElectrumFailure>> fetchActiveServers({
    required ElectrumServerNetwork network,
  });

  @useResult
  Future<Result<void, ElectrumFailure>> delete({required String url});
}
