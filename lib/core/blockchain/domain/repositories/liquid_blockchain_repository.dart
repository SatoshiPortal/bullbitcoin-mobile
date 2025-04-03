import 'dart:typed_data';

abstract class LiquidBlockchainRepository {
  Future<String> broadcastTransaction(
    Uint8List transaction, {
    required bool isTestnet,
  });
}
