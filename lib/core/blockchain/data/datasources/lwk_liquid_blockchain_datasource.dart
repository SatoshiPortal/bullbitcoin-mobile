import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_sdk/lwk.dart' as lwk;

class LwkLiquidBlockchainDatasource {
  const LwkLiquidBlockchainDatasource();

  Future<String> broadcastTransaction({
    required String signedPset,
    required Network network,
    required String electrumServerUrl,
  }) async {
    final txId = await lwk.Blockchain.broadcastSignedPset(
      network: switch (network) {
        Network.liquidMainnet => lwk.LiquidNetwork.mainnet,
        Network.liquidTestnet => lwk.LiquidNetwork.testnet,
        Network.liquidRegtest => lwk.LiquidNetwork.regtest,
        _ => throw const UnsupportedNetworkException(),
      },
      electrumUrl: electrumServerUrl,
      signedPset: signedPset,
    );
    return txId;
  }
}
