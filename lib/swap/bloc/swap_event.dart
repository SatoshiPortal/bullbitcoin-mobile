import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:boltz_dart/boltz_dart.dart';

class SwapEvent {}

class CreateBtcLightningSwap extends SwapEvent {
  CreateBtcLightningSwap({
    required this.walletBloc,
    required this.amount,
    this.label,
  });

  final WalletBloc walletBloc;
  final int amount;
  final String? label;
}

class SaveSwapInvoiceToWallet extends SwapEvent {
  SaveSwapInvoiceToWallet({required this.walletBloc, required this.swapTx, this.label});

  final SwapTx swapTx;
  final WalletBloc walletBloc;
  final String? label;
}

class ClaimSwap extends SwapEvent {
  ClaimSwap(this.walletBloc, this.swapTx);

  final SwapTx swapTx;
  final WalletBloc walletBloc;
}

class RefundSwap extends SwapEvent {}

class ResetToNewLnInvoice extends SwapEvent {}

class WatchInvoiceStatus extends SwapEvent {
  WatchInvoiceStatus({required this.walletBloc, required this.tx});

  final WalletBloc walletBloc;
  final Transaction tx;
}

class UpdateInvoiceStatus extends SwapEvent {
  UpdateInvoiceStatus(this.id, this.status, this.walletBloc);
  final String id;
  final SwapStatusResponse status;
  final WalletBloc walletBloc;
}

class DeleteSensitiveSwapTx extends SwapEvent {
  DeleteSensitiveSwapTx(this.swapId);

  final String swapId;
}
