import 'package:bb_mobile/core/blockchain/domain/ports/electrum_server_port.dart';

abstract class LiquidBlockchainRepository {
  Future<String> broadcastTransaction({
    required String signedPset,
    required List<ElectrumServer> electrumServers,
  });
}
