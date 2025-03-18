import 'dart:io';
import 'package:bb_mobile/_core/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/_core/domain/repositories/tor_repository.dart';
import 'package:recoverbull/recoverbull.dart';

class TorRepositoryImpl implements TorRepository {
  final TorDatasource _torDatasource;

  TorRepositoryImpl(this._torDatasource);

  @override
  Future<bool> isTorReady() async {
    return await _torDatasource.isReady;
  }

  @override
  Future<SOCKSSocket> createSocket() async {
    // Make sure Tor is ready
    final isReady = await isTorReady();
    if (!isReady) {
      throw Exception('Tor is not ready');
    }

    // Get the Tor proxy port
    final proxyPort = _torDatasource.port;

    return await SOCKSSocket.create(
      proxyHost: InternetAddress.loopbackIPv4.address,
      proxyPort: proxyPort,
    );
  }
}
