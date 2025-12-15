abstract class BlockchainPort {
  Future<String> broadcastLiquidTransaction({
    required String signedPset,
    required bool isTestnet,
  });
}
