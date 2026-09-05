import '../wallet_network_key.dart';

class ListLocalTransactionsRequest {
  final WalletNetworkKey key;
  final int pageSize;
  final String? cursor;
  const ListLocalTransactionsRequest(
    this.key, {
    this.pageSize = 50,
    this.cursor,
  });
}
