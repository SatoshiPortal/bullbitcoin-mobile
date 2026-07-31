import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/imu_sensor_source.dart';
import 'package:bb_mobile/core/utils/logger.dart';

/// Samples the IMU sensors for one window and mixes the readings into the
/// pool. Best-effort: devices without sensors simply contribute nothing.
class CollectSensorEntropyUsecase {
  const CollectSensorEntropyUsecase({
    required EntropyPool entropyPool,
    required ImuSensorSource imuSensorSource,
  }) : _entropyPool = entropyPool,
       _imuSensorSource = imuSensorSource;

  final EntropyPool _entropyPool;
  final ImuSensorSource _imuSensorSource;

  Future<void> execute() async {
    try {
      final data = await _imuSensorSource.collect();
      _entropyPool.mix(_imuSensorSource.name, data);
    } catch (e) {
      log.warning('IMU entropy collection skipped: $e');
    }
  }
}
