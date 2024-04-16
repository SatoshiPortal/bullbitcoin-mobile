import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:boltz_dart/boltz_dart.dart';

class WatchTxsEvent {}

class InitializeSwapWatcher extends WatchTxsEvent {}

class ProcessSwapTx extends WatchTxsEvent {
  ProcessSwapTx({required this.walletId, required this.swapTx});

  final SwapTx swapTx;
  final String walletId;
}

class WatchSwapStatus extends WatchTxsEvent {
  WatchSwapStatus({
    required this.walletId,
    required this.swapTxs,
  });

  final String walletId;
  final List<String> swapTxs;
}

class WatchWalletTxs extends WatchTxsEvent {
  WatchWalletTxs({required this.wallet});

  final Wallet wallet;
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
