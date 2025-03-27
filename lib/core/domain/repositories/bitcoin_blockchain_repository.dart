import 'package:bb_mobile/core/domain/entities/electrum_server.dart';

abstract class BitcoinBlockchainRepository {
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required ElectrumServer electrumServer,
  });
}
