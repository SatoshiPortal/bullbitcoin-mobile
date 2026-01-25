import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_local_storage_port.dart';
import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_remote_datasource_port.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/bitaxe_device.dart';

/// Use case for retrieving stored connection and optionally fetching fresh SystemInfo
class GetStoredConnectionUsecase {
  final BitaxeLocalStoragePort _localStorage;
  final BitaxeRemoteDatasourcePort _remoteDatasource;

  GetStoredConnectionUsecase({
    required BitaxeLocalStoragePort localStorage,
    required BitaxeRemoteDatasourcePort remoteDatasource,
  }) : _localStorage = localStorage,
       _remoteDatasource = remoteDatasource;

  /// Get stored connection
  ///
  /// [fetchSystemInfo]: If true, fetches fresh SystemInfo from device.
  /// If false, returns device with systemInfo: null.
  ///
  /// Returns: [BitaxeDevice] with systemInfo if fetchSystemInfo is true and fetch succeeds,
  ///          [BitaxeDevice] with systemInfo: null if fetchSystemInfo is false or fetch fails,
  ///          null if no stored connection exists.
  ///
  /// Note: If fetching SystemInfo fails, the device is still returned without SystemInfo.
  /// This allows the caller to display the stored connection even if the device is offline.
  Future<BitaxeDevice?> execute({bool fetchSystemInfo = false}) async {
    final stored = await _localStorage.getStoredConnection();
    if (stored == null) return null;

    // If SystemInfo is requested, fetch it fresh
    if (fetchSystemInfo) {
      try {
        final freshSystemInfo = await _remoteDatasource.getSystemInfo(
          stored.ipAddress,
        );
        return stored.copyWith(systemInfo: freshSystemInfo);
      } catch (e) {
        // If fetch fails, return device without SystemInfo
        // The caller can handle the error appropriately
        return stored;
      }
    }

    return stored;
  }
}
