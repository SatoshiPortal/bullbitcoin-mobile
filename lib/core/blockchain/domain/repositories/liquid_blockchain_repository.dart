import 'package:bb_mobile/features/wallet/domain/wallet.dart';

abstract class LiquidBlockchainRepository {
  Future<String> broadcastTransaction({
    required String signedPset,
    required Network network,
  });
}
