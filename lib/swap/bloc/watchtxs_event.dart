import 'package:bb_mobile/_model/transaction.dart';

class WatchTxsEvent {}

// class InitializeSwapWatcher extends WatchTxsEvent {
//   InitializeSwapWatcher();
// }

class WatchWallets extends WatchTxsEvent {
  WatchWallets({required this.isTestnet});

  final bool isTestnet;
}

class ClearAlerts extends WatchTxsEvent {}

class ProcessSwapTx extends WatchTxsEvent {
  ProcessSwapTx({required this.walletId, required this.swapTx});

  final SwapTx swapTx;
  final String walletId;
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
