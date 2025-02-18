part of 'receive_bloc.dart';

sealed class ReceiveEvent {
  const ReceiveEvent();
}

// Todo: add event to receive to a specific wallet only (so disable the other wallets)
class ReceiveEventWalletSelected extends ReceiveEvent {
  final String walletId;

  ReceiveEventWalletSelected({required this.walletId});
}
