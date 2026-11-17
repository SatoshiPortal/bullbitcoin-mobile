import 'package:primitives/primitives.dart';
import 'package:swaps/src/domain/entities/swap.dart';
import 'package:swaps/src/domain/entities/swap_failure.dart';

/// The swaps we hold, whichever provider runs them. Reads only: every
/// change to a swap is made by its provider's [SwapResolver] or create
/// methods.
abstract interface class SwapStore {
  Future<Result<Swap, SwapsFailure>> get(String swapId);

  /// The stored swap now and after every change.
  Stream<Swap> watch(String swapId);

  Future<Result<List<Swap>, SwapsFailure>> all({String? walletId});

  /// The swap whose lockup, claim or refund is [txId], if any.
  Future<Result<Swap?, SwapsFailure>> byTxId(String txId);

  /// Swaps still in flight, holding a lockup being confirmed, or holding
  /// funds that must be claimed or refunded.
  Future<Result<List<Swap>, SwapsFailure>> ongoing({String? walletId});
}
