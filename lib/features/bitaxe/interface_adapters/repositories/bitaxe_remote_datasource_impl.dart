import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_remote_datasource_port.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/system_info.dart';
import 'package:bb_mobile/features/bitaxe/frameworks/http/bitaxe_api_client.dart';
import 'package:bb_mobile/features/bitaxe/frameworks/storage/models/pool_configuration_update_model.dart';

/// Implementation of BitaxeRemoteDatasourcePort
/// This is a secondary adapter - implements the port
class BitaxeRemoteDatasourceImpl implements BitaxeRemoteDatasourcePort {
  final BitaxeApiClient _apiClient;

  BitaxeRemoteDatasourceImpl({required BitaxeApiClient apiClient})
    : _apiClient = apiClient;

  @override
  Future<SystemInfo> getSystemInfo(String ipAddress) async {
    final model = await _apiClient.getSystemInfo(ipAddress);
    return model.toEntity();
  }

  @override
  Future<void> updatePoolConfiguration(
    String ipAddress,
    PoolConfigurationUpdateModel config,
  ) async {
    await _apiClient.updatePoolConfiguration(ipAddress, config);
  }

  @override
  Future<String> restartDevice(String ipAddress) async {
    return await _apiClient.restartDevice(ipAddress);
  }

  @override
  Future<String> identifyDevice(String ipAddress) async {
    return await _apiClient.identifyDevice(ipAddress);
  }
}
