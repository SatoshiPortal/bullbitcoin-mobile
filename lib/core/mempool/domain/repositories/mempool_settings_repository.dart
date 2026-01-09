import 'package:bb_mobile/core/mempool/domain/entities/mempool_settings.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';

abstract class MempoolSettingsRepository {
  Future<void> save(MempoolSettings settings);

  Future<MempoolSettings> fetchByNetwork(MempoolServerNetwork network);
}
