import 'dart:typed_data';

import 'package:bb_mobile/core/wallet/domain/entity/wallet_metadata.dart';

abstract class LiquidBlockchainRepository {
  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required Network network,
  });
}
