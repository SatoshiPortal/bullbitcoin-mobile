import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart';

class WatchTxsEvent {}

class InitializeSwapWatcher extends WatchTxsEvent {}

class UpdateOrClaimSwap extends WatchTxsEvent {
  UpdateOrClaimSwap({required this.walletBloc, required this.swapTx});

  final SwapTx swapTx;
  final WalletBloc walletBloc;
}

class RefundSwap extends WatchTxsEvent {}

class WatchInvoiceStatus extends WatchTxsEvent {
  WatchInvoiceStatus({
    required this.walletBloc,
    required this.swapTx,
  });

  final WalletBloc walletBloc;
  final List<SwapTx> swapTx;
}

class WatchWalletTxs extends WatchTxsEvent {
  WatchWalletTxs({required this.walletBloc});

  final WalletBloc walletBloc;
}

class UpdateInvoiceStatus extends WatchTxsEvent {
  UpdateInvoiceStatus(this.id, this.status, this.walletBloc);
  final String id;
  final SwapStatusResponse status;
  final WalletBloc walletBloc;
}

class DeleteSensitiveSwapTx extends WatchTxsEvent {
  DeleteSensitiveSwapTx(this.swapId);

  final String swapId;
}
