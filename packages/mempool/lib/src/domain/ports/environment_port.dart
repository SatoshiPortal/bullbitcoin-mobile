import 'package:mempool/src/domain/mempool_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract interface class MempoolEnvironmentPort {
  @useResult
  Future<Result<BitcoinNetwork, MempoolFailure>> getEnvironment();
}
