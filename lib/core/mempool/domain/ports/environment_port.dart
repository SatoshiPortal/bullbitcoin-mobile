import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

abstract class MempoolEnvironmentPort {
  @useResult
  Future<Result<Environment, MempoolFailure>> getEnvironment();
}
