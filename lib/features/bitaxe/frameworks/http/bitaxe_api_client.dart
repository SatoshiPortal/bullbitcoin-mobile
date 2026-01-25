import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/bitaxe/domain/errors/bitaxe_domain_error.dart';
import 'package:bb_mobile/features/bitaxe/frameworks/storage/models/pool_configuration_update_model.dart';
import 'package:bb_mobile/features/bitaxe/frameworks/storage/models/system_info_model.dart';
import 'package:dio/dio.dart';

/// HTTP client for Bitaxe API
class BitaxeApiClient {
  final Dio _dio;

  BitaxeApiClient({required Dio dio}) : _dio = dio;

  /// Build base URL from IP address
  String _buildBaseUrl(String ipAddress) => 'http://$ipAddress';

  /// Get system info from device
  Future<SystemInfoModel> getSystemInfo(String ipAddress) async {
    log.info('Getting system info from device at $ipAddress');

    try {
      final baseUrl = _buildBaseUrl(ipAddress);
      final response = await _dio.get('$baseUrl/api/system/info');

      if (response.statusCode == 200) {
        final jsonData = response.data as Map<String, dynamic>;
        return SystemInfoModel.fromJson(jsonData);
      } else {
        throw InvalidDeviceError('Invalid response: ${response.statusCode}');
      }
    } on DioException catch (e) {
      log.severe('Error getting system info: $e');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw DeviceNotReachableError(ipAddress);
      }
      throw DeviceNotReachableError(ipAddress);
    } catch (e, stackTrace) {
      log.severe('Unexpected error getting system info: $e');
      log.severe('Stack trace: $stackTrace');
      throw InvalidDeviceError(e.toString());
    }
  }

  /// Update pool configuration
  Future<void> updatePoolConfiguration(
    String ipAddress,
    PoolConfigurationUpdateModel config,
  ) async {
    try {
      final baseUrl = _buildBaseUrl(ipAddress);
      final response = await _dio.patch(
        '$baseUrl/api/system',
        data: config.toJson(),
      );

      if (response.statusCode != 200) {
        throw PoolConfigurationError(
          'Failed to update: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      log.severe('Error updating pool config: $e');
      if (e.type == DioExceptionType.connectionTimeout) {
        throw DeviceNotReachableError(ipAddress);
      }
      throw PoolConfigurationError(e.message ?? 'Unknown error');
    } catch (e) {
      log.severe('Unexpected error updating pool config: $e');
      throw PoolConfigurationError(e.toString());
    }
  }

  /// Restart device
  Future<String> restartDevice(String ipAddress) async {
    try {
      final baseUrl = _buildBaseUrl(ipAddress);
      final response = await _dio.post('$baseUrl/api/system/restart', data: {});

      if (response.statusCode == 200) {
        return response.data as String;
      } else {
        throw DeviceNotReachableError(ipAddress);
      }
    } on DioException catch (e) {
      log.severe('Error restarting device: $e');
      throw DeviceNotReachableError(ipAddress);
    }
  }

  /// Identify device
  Future<String> identifyDevice(String ipAddress) async {
    try {
      final baseUrl = _buildBaseUrl(ipAddress);
      final response = await _dio.post(
        '$baseUrl/api/system/identify',
        data: {},
      );

      if (response.statusCode == 200) {
        return response.data as String;
      } else {
        throw DeviceNotReachableError(ipAddress);
      }
    } on DioException catch (e) {
      log.severe('Error identifying device: $e');
      throw DeviceNotReachableError(ipAddress);
    }
  }
}
