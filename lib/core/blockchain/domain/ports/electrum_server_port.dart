import 'package:bb_mobile/core/blockchain/domain/electrum_server.dart';

abstract class ElectrumServerPort {
  Future<List<ElectrumServer>> getElectrumServers({
    required bool isTestnet,
    required bool isLiquid,
  });
}
