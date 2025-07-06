import 'dart:convert';

import 'package:bb_mobile/features/template/data/datasources/local_datasource.dart';
import 'package:bb_mobile/features/template/data/datasources/remote_datasource.dart';
import 'package:bb_mobile/features/template/data/ip_address_model.dart';
import 'package:bb_mobile/features/template/domain/ip_address_entity.dart';

class TemplateRepository {
  final LocalDatasource _localDatasource;
  final RemoteDatasource _remoteDatasource;

  TemplateRepository({
    required LocalDatasource localDatasource,
    required RemoteDatasource remoteDatasource,
  }) : _localDatasource = localDatasource,
       _remoteDatasource = remoteDatasource;

  Future<IpAddressEntity> getIpAddressAndWriteToFile() async {
    try {
      final ipAddress = await _remoteDatasource.fetchIpAddress();
      await _localDatasource.writeToFile(json.encode(ipAddress.toJson()));
      return ipAddress.toEntity();
    } catch (e) {
      throw 'Failed to get IP address: $e';
    }
  }

  Future<IpAddressEntity?> getCachedIpAddress() async {
    try {
      final file = await _localDatasource.readFile();
      if (file == null) return null;

      return IpAddressModel.fromJson(
        json.decode(file.readAsStringSync()) as Map<String, dynamic>,
      ).toEntity();
    } catch (e) {
      throw 'Failed to get cached IP address: $e';
    }
  }
}
