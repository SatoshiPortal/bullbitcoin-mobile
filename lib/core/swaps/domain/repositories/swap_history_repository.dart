import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';

abstract interface class SwapHistoryRepository {
  Future<List<Swap>> getAllSwaps({String? walletId});

  Future<Swap?> getSwapByTxId(String txId);
}
