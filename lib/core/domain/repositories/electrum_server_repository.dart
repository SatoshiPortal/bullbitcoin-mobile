import 'package:bb_mobile/core/domain/entities/electrum_server.dart';
import 'package:bb_mobile/core/domain/entities/wallet_metadata.dart';

abstract class ElectrumServerRepository {
  Future<ElectrumServer> getElectrumServer({required Network network});
  Future<void> setElectrumServer(ElectrumServer server);
}
