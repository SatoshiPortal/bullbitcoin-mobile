import 'package:bb_mobile/_model/transaction.dart';
import 'package:boltz_dart/boltz_dart.dart';

class WatchTxsEvent {}

class InitializeSwapWatcher extends WatchTxsEvent {}

class UpdateOrClaimSwap extends WatchTxsEvent {
  UpdateOrClaimSwap({required this.walletId, required this.swapTx});

  final SwapTx swapTx;
  final String walletId;
}

class RefundSwap extends WatchTxsEvent {}

class WatchSwapStatus extends WatchTxsEvent {
  WatchSwapStatus({
    required this.walletId,
    required this.swapTxs,
  });

  final String walletId;
  final List<SwapTx> swapTxs;
}

class WatchWalletTxs extends WatchTxsEvent {
  WatchWalletTxs({required this.walletId});

  final String walletId;
}

class SwapStatusUpdate extends WatchTxsEvent {
  SwapStatusUpdate(this.swapId, this.status, this.walletId);
  final String swapId;
  final SwapStatusResponse status;
  final String walletId;
}

class DeleteSensitiveSwapData extends WatchTxsEvent {
  DeleteSensitiveSwapData(this.swapId);

  final String swapId;
}
