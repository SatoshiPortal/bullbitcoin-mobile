import 'package:bb_mobile/core_deprecated/blockchain/domain/ports/electrum_server_port.dart';

abstract class LiquidBlockchainRepository {
  Future<String> broadcastTransaction({
    required String signedPset,
    required List<ElectrumServer> electrumServers,
  });
}
