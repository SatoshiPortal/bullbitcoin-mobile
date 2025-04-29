import 'package:lwk/lwk.dart' as lwk;

class LwkLiquidBlockchainDatasource {
  const LwkLiquidBlockchainDatasource();

  Future<String> broadcastTransaction({
    required String signedPset,
    required String electrumServerUrl,
  }) async {
    final txId = await lwk.Blockchain.broadcastSignedPset(
      electrumUrl: electrumServerUrl,
      signedPset: signedPset,
    );
    return txId;
  }
}
