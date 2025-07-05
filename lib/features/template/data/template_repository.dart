import 'package:bb_mobile/features/template/data/datasources/local_datasource.dart';
import 'package:bb_mobile/features/template/data/datasources/remote_datasource.dart';

class TemplateRepository {
  final LocalDatasource _localDatasource;
  final RemoteDatasource _remoteDatasource;

  TemplateRepository({
    required LocalDatasource localDatasource,
    required RemoteDatasource remoteDatasource,
  }) : _localDatasource = localDatasource,
       _remoteDatasource = remoteDatasource;

  Future<String> getIpAddressAndWriteToFile() async {
    try {
      final ipAddress = await _remoteDatasource.fetchIpAddress();
      await _localDatasource.writeToFile(ipAddress);
      return ipAddress;
    } catch (e) {
      throw 'Failed to get IP address: $e';
    }
  }

  Future<Map<String, dynamic>> getDetailedIPInfo() async {
    try {
      final data = await _localDatasource.readFromFile();
      return {
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'source': 'TemplateRepository',
      };
    } catch (e) {
      throw 'Failed to get detailed IP info: $e';
    }
  }
}
