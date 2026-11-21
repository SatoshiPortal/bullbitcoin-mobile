import 'package:mempool/src/domain/entities/mempool_server.dart';
import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:mempool/src/domain/value_objects/mempool_server_network.dart';
import 'package:primitives/primitives.dart';
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
