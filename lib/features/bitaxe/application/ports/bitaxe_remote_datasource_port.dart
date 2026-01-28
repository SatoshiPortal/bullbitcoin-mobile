import 'package:bb_mobile/features/bitaxe/domain/entities/system_info.dart';
import 'package:bb_mobile/features/bitaxe/frameworks/storage/models/pool_configuration_update_model.dart';

/// Port (interface) for remote Bitaxe API operations
abstract class BitaxeRemoteDatasourcePort {
  /// Get system information from device
  Future<SystemInfo> getSystemInfo(String ipAddress);

  /// Update pool configuration
  Future<void> updatePoolConfiguration(
    String ipAddress,
    PoolConfigurationUpdateModel config,
  );

  /// Restart the device
  Future<String> restartDevice(String ipAddress);

  /// Identify device (makes it say "Hi!")
  Future<String> identifyDevice(String ipAddress);
}
