import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'entities/order_swap_record.dart';
import 'order_swap_failure.dart';

/// Read access to persisted order swaps.
abstract interface class ReadOrderSwaps {
  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> getOrder(String localId);

  @useResult
  Future<Result<List<OrderSwapRecord>, SwapFailure>> getOrders({
    String? walletId,
  });

  Stream<Result<OrderSwapRecord, SwapFailure>> watchOrder(String localId);
}
