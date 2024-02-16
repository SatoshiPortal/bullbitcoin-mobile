import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';

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
  SaveSwapInvoiceToWallet(this.walletBloc, {this.label});

  final WalletBloc walletBloc;
  final String? label;
}

class SwapTxSelected extends SwapEvent {
  SwapTxSelected(this.tx);
  final Transaction tx;
}

class ClaimSwap extends SwapEvent {
  ClaimSwap(this.walletBloc);

  final WalletBloc walletBloc;
}

class RefundSwap extends SwapEvent {}

class ResetToNewLnInvoice extends SwapEvent {}

class WatchInvoiceStatus extends SwapEvent {
  WatchInvoiceStatus({required this.walletBloc, required this.tx});

  final WalletBloc walletBloc;
  final Transaction tx;
}
