part of 'receive_bloc.dart';

sealed class ReceiveEvent {
  const ReceiveEvent();
}

class ReceiveBitcoinStarted extends ReceiveEvent {
  const ReceiveBitcoinStarted();
}

class ReceiveLightningStarted extends ReceiveEvent {
  const ReceiveLightningStarted();
}

class ReceiveLiquidStarted extends ReceiveEvent {
  const ReceiveLiquidStarted();
}

// Todo: add event to receive to a specific wallet only (so disable the other wallets)
class ReceiveEventWalletPreselected extends ReceiveEvent {
  final String walletId;

  ReceiveEventWalletPreselected({required this.walletId});
}
