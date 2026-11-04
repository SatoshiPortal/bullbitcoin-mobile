import '../wallet_network_key.dart';

class LookupLocalTransactionRequest {
  final WalletNetworkKey key;
  final String txid;
  const LookupLocalTransactionRequest(this.key, this.txid);
}
