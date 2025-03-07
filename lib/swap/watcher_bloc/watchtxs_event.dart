import 'package:boltz/boltz.dart';

class WatchTxsEvent {}

// class InitializeSwapWatcher extends WatchTxsEvent {
//   InitializeSwapWatcher();
// }

class WatchWallets extends WatchTxsEvent {
  WatchWallets();
}

// class ClearAlerts extends WatchTxsEvent {}

class ProcessSwapTx extends WatchTxsEvent {
  ProcessSwapTx({
    required this.walletId,
    required this.swapTxId,
    this.status,
  });

  final String swapTxId;
  final String walletId;
  final SwapStreamStatus? status;
}

// class WatchSwapStatus extends WatchTxsEvent {
//   WatchSwapStatus({
//     required this.walletId,
//     required this.swapTxs,
//   });

//   final String walletId;
//   final List<String> swapTxs;
// }

// class SwapStatusUpdate extends WatchTxsEvent {
//   SwapStatusUpdate(this.swapId, this.status, this.walletId);
//   final String swapId;
//   final SwapStatusResponse status;
//   final String walletId;
// }

// class DeleteSensitiveSwapData extends WatchTxsEvent {
//   DeleteSensitiveSwapData(this.swapId);

//   final String swapId;
// }
