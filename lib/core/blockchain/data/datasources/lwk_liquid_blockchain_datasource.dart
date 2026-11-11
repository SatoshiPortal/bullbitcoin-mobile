import 'package:bull_sdk/lwk.dart' as lwk;

class LwkLiquidBlockchainDatasource {
  const LwkLiquidBlockchainDatasource();

  Future<String> broadcastTransaction({
    required String signedPset,
    required String electrumServerUrl,
    required bool isTestnet,
  }) async {
    final txId = await lwk.Blockchain.broadcastSignedPset(
      network: isTestnet
          ? lwk.LiquidNetwork.testnet
          : lwk.LiquidNetwork.mainnet,
      electrumUrl: electrumServerUrl,
      signedPset: signedPset,
    );
    return txId;
  }
}
