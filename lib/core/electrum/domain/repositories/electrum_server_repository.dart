import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

abstract class ElectrumServerRepository {
  Future<void> setElectrumServer(ElectrumServer server);

  Future<ElectrumServer> getElectrumServer({
    required ElectrumServerProvider provider,
    required Network network,
  });

  Future<List<ElectrumServer>> getElectrumServers({
    required Network network,
    bool checkStatus = false,
  });
}
