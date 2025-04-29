abstract class LiquidBlockchainRepository {
  Future<String> broadcastTransaction({
    required String signedPset,
    required bool isTestnet,
  });
}
