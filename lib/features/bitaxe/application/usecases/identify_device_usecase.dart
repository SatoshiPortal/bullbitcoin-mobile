import 'package:bb_mobile/features/bitaxe/application/ports/bitaxe_remote_datasource_port.dart';

/// Use case for identifying a Bitaxe device
/// Makes the device say "Hi!" to help users identify it
class IdentifyDeviceUsecase {
  final BitaxeRemoteDatasourcePort _remoteDatasource;

  IdentifyDeviceUsecase({required BitaxeRemoteDatasourcePort remoteDatasource})
    : _remoteDatasource = remoteDatasource;

  /// Identify device by making it say "Hi!"
  ///
  /// [ipAddress]: The IP address of the device to identify
  ///
  /// Returns: Response message from device
  Future<String> execute(String ipAddress) async {
    return await _remoteDatasource.identifyDevice(ipAddress);
  }
}
