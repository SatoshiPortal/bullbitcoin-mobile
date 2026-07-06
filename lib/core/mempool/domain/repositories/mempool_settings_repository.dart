import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/errors/mempool_failure.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

abstract class MempoolSettingsRepository {
  @useResult
  Future<Result<void, MempoolFailure>> save(MempoolSettings settings);

  @useResult
  Future<Result<MempoolSettings, MempoolFailure>> fetchByNetwork(
    MempoolServerNetwork network,
  );
}
