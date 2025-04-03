abstract class BitcoinBlockchainRepository {
  Future<String> broadcastPsbt(
    String finalizedPsbt, {
    required bool isTestnet,
  });
}
