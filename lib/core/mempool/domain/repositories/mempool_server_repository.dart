import 'package:bb_mobile/core/mempool/domain/entities/mempool_server.dart';
import 'package:bb_mobile/core/mempool/domain/value_objects/mempool_server_network.dart';

abstract class MempoolServerRepository {
  Future<void> save(MempoolServer server);

  Future<MempoolServer?> fetchCustomServer(MempoolServerNetwork network);

  Future<MempoolServer> fetchDefaultServer(MempoolServerNetwork network);

  Future<void> deleteCustomServer(MempoolServerNetwork network);
}
