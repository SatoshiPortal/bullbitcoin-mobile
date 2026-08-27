import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

abstract class MempoolServerRepository {
  @useResult
  Future<Result<void, MempoolFailure>> save(MempoolServer server);

  @useResult
  Future<Result<MempoolServer?, MempoolFailure>> fetchCustomServer(
    MempoolServerNetwork network,
  );

  @useResult
  Future<Result<MempoolServer, MempoolFailure>> fetchDefaultServer(
    MempoolServerNetwork network,
  );

  @useResult
  Future<Result<void, MempoolFailure>> deleteCustomServer(
    MempoolServerNetwork network,
  );
}
