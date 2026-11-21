import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

abstract interface class MempoolEnvironmentPort {
  @useResult
  Future<Result<BitcoinNetwork, MempoolFailure>> getEnvironment();
}
