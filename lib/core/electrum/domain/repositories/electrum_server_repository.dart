import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

abstract class ElectrumServerRepository {
  Future<ElectrumServer> getElectrumServer({required Network network});
  Future<void> setElectrumServer(ElectrumServer server);
}
