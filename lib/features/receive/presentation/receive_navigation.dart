import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';

enum ReceiveDetailsTargetKind { walletTransaction, swap, orderSwap, payjoin }

typedef ReceiveDetailsTarget = ({
  ReceiveDetailsTargetKind kind,
  String id,
  String? walletId,
});

bool canReuseConfirmedReceiveDetails(ReceiveState state) {
  final confirmedAmountSat = state.confirmedAmountSat;
  if (confirmedAmountSat == null ||
      state.inputAmountSat != confirmedAmountSat) {
    return false;
  }
  if (state.type != ReceiveType.lightning) return true;
  return state.orderSwap != null && !state.orderSwap!.localStatus.isTerminal;
}

ReceiveDetailsTarget? receiveDetailsTarget(ReceiveState state) {
  final transaction = state.transaction;
  final walletTransaction = transaction.walletTransaction;
  if (walletTransaction != null) {
    return (
      kind: ReceiveDetailsTargetKind.walletTransaction,
      id: walletTransaction.txId,
      walletId: walletTransaction.walletId,
    );
  }
  final orderSwap = transaction.orderSwap;
  if (orderSwap != null) {
    return (
      kind: ReceiveDetailsTargetKind.orderSwap,
      id: orderSwap.localId,
      walletId: orderSwap.canonicalWalletId,
    );
  }
  final swap = transaction.swap;
  if (swap != null) {
    return (
      kind: ReceiveDetailsTargetKind.swap,
      id: swap.id,
      walletId: swap.walletId,
    );
  }
  final payjoin = transaction.payjoin;
  if (payjoin != null) {
    return (
      kind: ReceiveDetailsTargetKind.payjoin,
      id: payjoin.id,
      walletId: null,
    );
  }
  return null;
}
