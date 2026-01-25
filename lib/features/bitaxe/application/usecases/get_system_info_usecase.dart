import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_remote_datasource_port.dart';
import 'package:bb_mobile/features/bitaxe/domain/entities/system_info.dart';

/// Use case for retrieving system information from device
class GetSystemInfoUsecase {
  final BitaxeRemoteDatasourcePort _remoteDatasource;

  GetSystemInfoUsecase({required BitaxeRemoteDatasourcePort remoteDatasource})
    : _remoteDatasource = remoteDatasource;

  Future<SystemInfo> execute(String ipAddress) async {
    return await _remoteDatasource.getSystemInfo(ipAddress);
  }
}
