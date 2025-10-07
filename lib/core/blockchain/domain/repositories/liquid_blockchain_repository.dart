import 'package:bb_mobile/core/blockchain/domain/electrum_server.dart';

abstract class LiquidBlockchainRepository {
  Future<String> broadcastTransaction({
    required String signedPset,
    required List<ElectrumServer> electrumServers,
  });
}
