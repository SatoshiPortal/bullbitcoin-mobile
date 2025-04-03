import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

abstract class BitcoinBlockchainRepository {
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required Network network,
  });
}
