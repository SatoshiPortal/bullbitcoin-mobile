part of 'wallet_bloc.dart';

sealed class WalletEvent {
  const WalletEvent();
}

class WalletStarted extends WalletEvent {
  const WalletStarted();
}

class WalletRefreshed extends WalletEvent {
  const WalletRefreshed();
}

class WalletSyncStarted extends WalletEvent {
  final Wallet wallet;

  const WalletSyncStarted(this.wallet);
}

class WalletSyncFinished extends WalletEvent {
  final Wallet wallet;

  const WalletSyncFinished(this.wallet);
}

class WalletDeleted extends WalletEvent {
  final String walletId;

  const WalletDeleted(this.walletId);
}

class StartTorInitialization extends WalletEvent {
  const StartTorInitialization();
}

class BlockAutoSwapUntilNextExecution extends WalletEvent {
  const BlockAutoSwapUntilNextExecution();
}

class ExecuteAutoSwap extends WalletEvent {
  const ExecuteAutoSwap();
}

class ExecuteAutoSwapFeeOverride extends WalletEvent {
  const ExecuteAutoSwapFeeOverride();
}

class RefreshArkWalletBalance extends WalletEvent {
  final int? amount;
  const RefreshArkWalletBalance({this.amount});
}

class ElectrumSyncResultChanged extends WalletEvent {
  final ElectrumSyncResult result;
  const ElectrumSyncResultChanged(this.result);
}

class DismissAutoSwapWarning extends WalletEvent {
  const DismissAutoSwapWarning();
}
