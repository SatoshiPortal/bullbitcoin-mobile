import 'package:swaps/swaps.dart';

abstract interface class SwapHistoryRepository {
  Future<List<Swap>> getAllSwaps({String? walletId});

  Future<Swap?> getSwapByTxId(String txId);
}
