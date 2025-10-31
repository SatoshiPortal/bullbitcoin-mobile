import 'package:bb_mobile/core/tor/data/datasources/tor_datasource.dart';
import 'package:bb_mobile/core/tor/tor_status.dart';

class TorRepository {
  final TorDatasource _torDatasource;

  TorRepository(this._torDatasource);

  bool get isStarted => _torDatasource.isStarted;

  Future<void> start() async => await _torDatasource.start();

  void stop() => _torDatasource.disable();

  TorStatus get status => _torDatasource.status;
}
