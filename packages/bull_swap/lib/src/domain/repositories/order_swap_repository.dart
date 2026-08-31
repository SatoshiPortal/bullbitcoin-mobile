import 'package:primitives/primitives.dart';
import 'package:bull_swap/src/domain/order_swap_network.dart';
import 'package:bull_swap/src/domain/order_swap_quote.dart';
import 'package:bull_swap/src/domain/order_swap_record.dart';
import 'package:bull_swap/src/domain/swap_failure.dart';
import 'package:meta/meta.dart';

abstract interface class OrderSwapRepository {
  bool get isSwapProviderUnavailable;

  Stream<bool> watchSwapProviderUnavailable();

  @useResult
  Future<Result<OrderSwapQuote, SwapFailure>> getQuote({
    required OrderSwapEnvironment environment,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
  });

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> createOrder({
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
    required OrderSwapPurpose purpose,
    required OrderSwapEnvironment environment,
    String? sourceWalletId,
    String? destinationWalletId,
    String? note,
    BigInt? quotedCounterpartAmountSat,
  });

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> refreshOrder(String localId);

  @useResult
  Future<Result<List<OrderSwapRecord>, SwapFailure>> getOrders({
    String? walletId,
  });

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> getOrder(String localId);

  @useResult
  Future<Result<List<OrderSwapRecord>, SwapFailure>> getPendingOrders();

  @useResult
  Future<Result<List<OrderSwapRecord>, SwapFailure>> getOrdersAwaitingLabels({
    required OrderSwapPurpose purpose,
  });

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> savePreparedPayin({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  });

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> replacePreparedPayin({
    required String localId,
    required String signedTransaction,
    required bool isPsbt,
  });

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> markBroadcastUnknown(
    String localId,
  );

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> markPayinBroadcast({
    required String localId,
    required String transactionId,
  });

  @useResult
  Future<Result<OrderSwapRecord, SwapFailure>> markLabelsApplied({
    required String localId,
    required DateTime appliedAt,
  });

  Stream<Result<OrderSwapRecord, SwapFailure>> watchOrder(String localId);
}
