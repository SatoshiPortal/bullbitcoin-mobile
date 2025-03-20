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
