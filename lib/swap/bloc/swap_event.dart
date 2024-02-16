import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';

class SwapEvent {}

class CreateBtcLightningSwap extends SwapEvent {
  CreateBtcLightningSwap(this.walletBloc);

  final WalletBloc walletBloc;
}

class SaveSwapInvoiceToWallet extends SwapEvent {
  SaveSwapInvoiceToWallet(this.walletBloc);

  final WalletBloc walletBloc;
}

class WatchInvoiceStatus extends SwapEvent {}

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

class LoadAllSwapTxs extends SwapEvent {
  LoadAllSwapTxs(this.walletBloc);

  final WalletBloc walletBloc;
}
