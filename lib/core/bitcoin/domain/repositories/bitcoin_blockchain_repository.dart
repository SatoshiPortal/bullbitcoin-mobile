import 'package:bb_mobile/core/electrum/domain/entity/electrum_server.dart';

abstract class BitcoinBlockchainRepository {
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumServer electrumServer,
  });
}
